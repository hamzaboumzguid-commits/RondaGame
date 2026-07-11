import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/protocol.dart';

/// URL du serveur. En développement : émulateur Android = 10.0.2.2,
/// simulateur iOS / desktop = localhost. À terme : URL de production.
const String kDefaultServerUrl = String.fromEnvironment(
  'RONDA_SERVER',
  defaultValue: 'ws://localhost:2567',
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

  final _events = StreamController<GameEvent>.broadcast();
  Stream<GameEvent> get events => _events.stream;

  bool get isMyTurn => state != null && playerId != null && state!.currentTurnPlayerId == playerId;
  PublicPlayer? get me => playerId == null ? null : state?.playerById(playerId!);
  bool get isHost => me?.isHost ?? false;

  Future<void> connect({String url = kDefaultServerUrl}) async {
    if (status != ConnectionStatus.disconnected) return;
    status = ConnectionStatus.connecting;
    lastError = null;
    notifyListeners();

    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      await channel.ready;
      _channel = channel;
      _subscription = channel.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
      );
      status = ConnectionStatus.connected;
      notifyListeners();
    } catch (e) {
      status = ConnectionStatus.disconnected;
      lastError = 'Impossible de joindre le serveur';
      notifyListeners();
      rethrow;
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
        hand = (msg['cards'] as List)
            .map((c) => GameCard.fromJson(c as Map<String, dynamic>))
            .toList();
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
      case 'error':
        lastError = msg['message'] as String;
        _events.add(ErrorEvent(msg['code'] as String, msg['message'] as String));
        notifyListeners();
    }
  }

  void _send(Map<String, dynamic> msg) {
    _channel?.sink.add(jsonEncode(msg));
  }

  Future<void> createRoom(String nickname) async {
    await connect();
    _send({'type': 'create', 'nickname': nickname});
  }

  Future<void> joinRoom(String code, String nickname) async {
    await connect();
    _send({'type': 'join', 'roomCode': code.toUpperCase(), 'nickname': nickname});
  }

  void joinTeam(String team) => _send({'type': 'joinTeam', 'team': team});

  void startGame() => _send({'type': 'start'});

  void playCard(String cardId, {required bool capture}) {
    // Retire la carte localement tout de suite pour une UI réactive ;
    // le serveur renverra la main complète à la prochaine donne.
    hand.removeWhere((c) => c.id == cardId);
    _send({'type': 'playCard', 'cardId': cardId, 'capture': capture});
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
