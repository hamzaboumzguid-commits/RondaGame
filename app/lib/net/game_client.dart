import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/protocol.dart';

/// URL du serveur. Par défaut : serveur de production (VPS OVH, wss://) —
/// pour ne jamais risquer de builder une release qui pointe vers localhost
/// par oubli du flag. En dev local, surcharger explicitement avec
/// --dart-define=RONDA_SERVER=ws://localhost:2567 (10.0.2.2 sur émulateur
/// Android, localhost sur simulateur iOS / desktop).
const String kDefaultServerUrl = String.fromEnvironment(
  'RONDA_SERVER',
  defaultValue: 'wss://ronda.51-254-140-211.sslip.io',
);

enum ConnectionStatus { disconnected, connecting, connected }

/// Client de jeu : connexion WebSocket, état public répliqué, main privée,
/// et flux d'événements ponctuels (captures, révélations, fin de partie)
/// pour les animations.
class GameClient extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  ConnectionStatus status = ConnectionStatus.disconnected;
  String? playerId;
  String? roomCode;
  PublicState? state;
  List<GameCard> hand = [];
  String? lastError;
  List<PublicRoomSummary> publicRooms = [];

  final _events = StreamController<GameEvent>.broadcast();
  Stream<GameEvent> get events => _events.stream;

  bool get isMyTurn => state != null && playerId != null && state!.currentTurnPlayerId == playerId;
  PublicPlayer? get me => playerId == null ? null : state?.playerById(playerId!);
  bool get isHost => me?.isHost ?? false;

  /// Délai au-delà duquel on cesse d'attendre le handshake : sans lui,
  /// `channel.ready` peut rester en attente indéfiniment sur un réseau lent
  /// ou filtré (constaté depuis l'Asie du Sud), laissant l'UI bloquée.
  static const Duration kConnectTimeout = Duration(seconds: 10);

  /// Handshake en cours, s'il y en a un. Permet aux appelants concurrents
  /// (polling des salons publics ET tap Créer/Rejoindre) d'attendre le MÊME
  /// connect au lieu de retourner immédiatement : sans ça, le second appel
  /// voyait `status == connecting`, retournait tout de suite, `_send` était un
  /// no-op (channel encore null) et l'action utilisateur était perdue avec un
  /// faux "serveur ne répond pas".
  Future<void>? _connectFuture;

  /// Établit la connexion. **Ne relance jamais** : l'échec est signalé par
  /// `status == disconnected` + `lastError`. Un `rethrow` ici remontait en
  /// exception asynchrone non capturée depuis les appelants « fire and
  /// forget » (polling des salons publics au démarrage) et tuait l'app.
  ///
  /// Un connect déjà en vol est réutilisé (mémoïsation) : tous les appelants
  /// attendent le même handshake et voient donc un `status` définitif au retour.
  Future<void> connect({String url = kDefaultServerUrl}) {
    if (status == ConnectionStatus.connected) return Future.value();
    return _connectFuture ??=
        _doConnect(url).whenComplete(() => _connectFuture = null);
  }

  Future<void> _doConnect(String url) async {
    status = ConnectionStatus.connecting;
    lastError = null;
    notifyListeners();

    WebSocketChannel? channel;
    try {
      channel = WebSocketChannel.connect(Uri.parse(url));
      await channel.ready.timeout(kConnectTimeout);
      _channel = channel;
      _subscription = channel.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
      );
      status = ConnectionStatus.connected;
      notifyListeners();
    } catch (e) {
      // Ferme le canal orphelin : Future.timeout() n'annule pas le handshake
      // sous-jacent, donc sans ça un socket resterait ouvert côté serveur si le
      // réseau se rétablit après le timeout.
      channel?.sink.close().catchError((_) {});
      status = ConnectionStatus.disconnected;
      lastError = 'Impossible de joindre le serveur';
      notifyListeners();
    }
  }

  void _onDisconnected() {
    final wasInGame = state != null && state!.phase != 'lobby' && state!.phase != 'gameOver';
    _channel = null;
    _subscription = null;
    status = ConnectionStatus.disconnected;
    if (wasInGame) {
      _events.add(GameAbandonedEvent('Connexion au serveur perdue'));
    }
    notifyListeners();
  }

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (msg['type']) {
      case 'joined':
        playerId = msg['playerId'] as String;
        roomCode = msg['roomCode'] as String;
        state = PublicState.fromJson(msg['state'] as Map<String, dynamic>);
        notifyListeners();
      case 'state':
        state = PublicState.fromJson(msg['state'] as Map<String, dynamic>);
        notifyListeners();
      case 'yourHand':
        final newHand = (msg['cards'] as List)
            .map((c) => GameCard.fromJson(c as Map<String, dynamic>))
            .toList();
        // Une main qui GROSSIT = nouvelle tfri9a distribuée -> animation de
        // distribution. (Une main qui rétrécit n'est que la resync post-coup.)
        final isNewDeal = newHand.length > hand.length;
        hand = newHand;
        if (isNewDeal && state != null) {
          _events.add(NewDealEvent(
            dealerId: state!.leadPlayerId,
            cardsPerPlayer: newHand.length,
            dealIndex: state!.dealIndex,
            dealsPerRound: state!.dealsPerRound,
          ));
        }
        notifyListeners();
      case 'captureEvent':
        _events.add(CaptureEvent.fromJson(msg));
      case 'cardPlaced':
        // L'état synchronisé suffit pour l'affichage, rien à faire ici pour l'instant.
        break;
      case 'subRoundReveal':
        _events.add(SubRoundRevealEvent.fromJson(msg));
      case 'roundEnd':
        _events.add(RoundEndEvent.fromJson(msg));
      case 'gameOver':
        _events.add(GameOverEvent(msg['winningTeam'] as String));
      case 'gameAbandoned':
        _events.add(GameAbandonedEvent(msg['reason'] as String));
      case 'publicRooms':
        publicRooms = (msg['rooms'] as List)
            .map((r) => PublicRoomSummary.fromJson(r as Map<String, dynamic>))
            .toList();
        notifyListeners();
      case 'error':
        lastError = msg['message'] as String;
        _events.add(ErrorEvent(msg['code'] as String, msg['message'] as String));
        notifyListeners();
    }
  }

  void _send(Map<String, dynamic> msg) {
    _channel?.sink.add(jsonEncode(msg));
  }

  /// Efface une erreur résiduelle avant une nouvelle tentative de connexion :
  /// sans ça, _waitForJoinOrError verrait l'erreur d'un essai précédent et
  /// conclurait immédiatement au lieu d'attendre le vrai résultat de ce coup-ci.
  void clearError() {
    lastError = null;
  }

  Future<void> createRoom(String nickname, {String mode = '2v2', bool isPublic = false}) async {
    await connect();
    _send({'type': 'create', 'nickname': nickname, 'mode': mode, 'isPublic': isPublic});
  }

  Future<void> joinRoom(String code, String nickname) async {
    await connect();
    _send({'type': 'join', 'roomCode': code.toUpperCase(), 'nickname': nickname});
  }

  /// Demande la liste des salons publics rejoignables (lobby, pas plein).
  /// Appeler périodiquement depuis l'accueil tant qu'aucune room n'est rejointe.
  Future<void> requestPublicRooms() async {
    await connect();
    _send({'type': 'listPublicRooms'});
  }

  void joinTeam(String team) => _send({'type': 'joinTeam', 'team': team});

  void startGame() => _send({'type': 'start'});

  void playCard(String cardId) {
    // Retire la carte localement tout de suite pour une UI réactive ;
    // le serveur renverra la main complète à la prochaine donne.
    // La capture n'est pas un choix : le serveur capture d'office (GDD 2.6).
    hand.removeWhere((c) => c.id == cardId);
    _send({'type': 'playCard', 'cardId': cardId});
    notifyListeners();
  }

  void leaveRoom() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _subscription = null;
    status = ConnectionStatus.disconnected;
    playerId = null;
    roomCode = null;
    state = null;
    hand = [];
    lastError = null;
    publicRooms = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _events.close();
    super.dispose();
  }
}
