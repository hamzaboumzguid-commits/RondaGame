import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/protocol.dart';
import '../net/game_client.dart';
import '../theme.dart';
import '../widgets/event_overlays.dart';
import '../widgets/playing_card.dart';
import 'victory_screen.dart';

/// Durée du tour côté serveur (GDD 3.4) — utilisée pour calibrer les jauges.
const turnTimeoutMs = 10000;

/// Table de jeu : sièges autour du tapis, pile centrale éparpillée façon vraie
/// table, main en éventail en bas. Les événements serveur (Derba, Missa,
/// révélations, fins de manche) sont mis en file et joués un par un en overlay
/// bloquant (GDD 3.4).
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  StreamSubscription<GameEvent>? _eventSub;
  final Queue<GameEvent> _eventQueue = Queue();
  GameEvent? _currentEvent;
  // Une capture Derba+Missa joue les deux animations à la suite (cumul, GDD 2.8) :
  // ce flag indique que la phase Missa de l'événement courant est en cours.
  bool _inMissaPhase = false;
  String? _selectedCardId;
  bool _leftForVictory = false;

  @override
  void initState() {
    super.initState();
    _eventSub = context.read<GameClient>().events.listen(_enqueueEvent);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  // Erreurs de course bénignes : un clic ou l'auto-jeu du timer qui arrive juste
  // au changement de tour / à la distribution. Le serveur les a déjà ignorées ;
  // les afficher en rouge est alarmant pour rien (bug du flash pendant la TFRI9A).
  static const _silentErrorCodes = {'cardNotInHand', 'notYourTurn'};

  void _enqueueEvent(GameEvent event) {
    if (!mounted) return;
    if (event is ErrorEvent) {
      if (_silentErrorCodes.contains(event.code)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(event.message),
          backgroundColor: RondaColors.redDeep,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    // Une capture ordinaire (ni Derba ni Missa) ne bloque pas le jeu.
    if (event is CaptureEvent && !event.isDerba && !event.isMissa) return;

    _eventQueue.add(event);
    if (_currentEvent == null) _playNextEvent();
  }

  void _playNextEvent() {
    _inMissaPhase = false;
    if (_eventQueue.isEmpty) {
      setState(() => _currentEvent = null);
      return;
    }
    setState(() => _currentEvent = _eventQueue.removeFirst());
  }

  void _onEventDone() {
    final finished = _currentEvent;
    if (finished is GameAbandonedEvent) {
      _exitToHome(message: finished.reason);
      return;
    }
    if (finished is GameOverEvent && !_leftForVictory) {
      _leftForVictory = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => VictoryScreen(winningTeam: finished.winningTeam)),
      );
      return;
    }
    _playNextEvent();
  }

  void _exitToHome({String? message}) {
    context.read<GameClient>().leaveRoom();
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _playSelected() {
    final cardId = _selectedCardId;
    if (cardId == null) return;
    context.read<GameClient>().playCard(cardId);
    setState(() => _selectedCardId = null);
  }

  @override
  Widget build(BuildContext context) {
    final client = context.watch<GameClient>();
    final strings = context.watch<AppStrings>();
    final state = client.state;

    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final mySeat = client.me?.seat ?? 0;
    PublicPlayer? seatAt(int offset) {
      final seat = (mySeat + offset) % 4;
      for (final p in state.players) {
        if (p.seat == seat) return p;
      }
      return null;
    }

    final selectedCard = _selectedCardId == null
        ? null
        : client.hand.where((c) => c.id == _selectedCardId).firstOrNull;
    // Capture = jumelle sur la table, OU surenchère EXACTE sur la Derba en attente.
    // Attention (GDD 2.7) : jouer un rang qui n'est présent que DANS le paquet en
    // attente (ex. un 7 alors que la Derba est sur le 6 d'une suite 6-7-8) ne
    // capture pas — seule la valeur `pendingDerbaRank` reprend le paquet.
    final wouldCapture = selectedCard != null &&
        (state.tablePile.any((c) => c.rank == selectedCard.rank) ||
            (state.pendingDerbaRank != 0 &&
                selectedCard.rank == state.pendingDerbaRank));

    // En 1v1, l'adversaire unique est affiché en face ; pas de côtés.
    final is1v1 = state.mode == '1v1';
    final facingPlayer = is1v1
        ? state.players.where((p) => p.id != client.playerId).firstOrNull
        : seatAt(2);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final quit = await _confirmQuit();
        if (quit == true && mounted) _exitToHome();
      },
      child: Scaffold(
        body: IllustratedBackground(
          asset: 'assets/ui/game_bg.png',
          child: SafeArea(
            child: Stack(
              children: [
                IgnorePointer(
                  ignoring: _currentEvent != null,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Sur écran court/petit, on rétrécit proportionnellement la
                      // partie basse (main + indicateurs) pour ne jamais écraser la
                      // table centrale ni provoquer d'overflow. 720 dp de hauteur =
                      // taille de référence (téléphone moyen) -> facteur 1.0.
                      final scale =
                          (constraints.maxHeight / 720).clamp(0.72, 1.0).toDouble();
                      final gap2 = 2 * scale;
                      return Column(
                        children: [
                          _ScoreBar(state: state, strings: strings, onQuit: () async {
                            final quit = await _confirmQuit();
                            if (quit == true && mounted) _exitToHome();
                          }),
                          SizedBox(height: gap2),
                          _SeatBadge(player: facingPlayer, state: state),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _SeatBadge(
                                    player: is1v1 ? null : seatAt(3),
                                    state: state,
                                    compact: true),
                                Expanded(
                                  child: _FeltTable(
                                    cards: state.tablePile,
                                    pendingDerba: state.pendingDerba,
                                    strings: strings,
                                  ),
                                ),
                                _SeatBadge(
                                    player: is1v1 ? null : seatAt(1),
                                    state: state,
                                    compact: true),
                              ],
                            ),
                          ),
                          _TurnIndicator(
                              state: state, myId: client.playerId, strings: strings),
                          SizedBox(height: 4 * scale),
                          if (client.isMyTurn && state.turnEndsAt > 0)
                            _MyCountdownBar(
                              key: ValueKey('countdown-${state.turnEndsAt}'),
                              endsAt: state.turnEndsAt,
                            ),
                          if ((client.me?.announcementKind ?? '').isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: gap2),
                              child: AnnouncementPill(
                                kind: client.me!.announcementKind,
                                fontSize: 13,
                              ),
                            ),
                          SizedBox(height: gap2),
                          _PlayButton(
                            visible: selectedCard != null && client.isMyTurn,
                            capture: wouldCapture,
                            onPlay: _playSelected,
                            strings: strings,
                          ),
                          SizedBox(height: gap2),
                          _FanHand(
                            cards: client.hand,
                            selectedCardId: _selectedCardId,
                            enabled: client.isMyTurn,
                            scale: scale,
                            onSelect: (id) => setState(
                              () => _selectedCardId = _selectedCardId == id ? null : id,
                            ),
                            onPlaySelected: _playSelected,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (_currentEvent != null) _buildEventOverlay(client, state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventOverlay(GameClient client, PublicState state) {
    String nicknameOf(String id) => state.playerById(id)?.nickname ?? '?';

    final event = _currentEvent!;
    return switch (event) {
      CaptureEvent(:final isDerba) when isDerba && !_inMissaPhase => DerbaOverlay(
          key: ValueKey('derba-${event.playedCardId}'),
          tier: event.derbaTier,
          points: event.points,
          team: event.team,
          playerNickname: nicknameOf(event.playerId),
          onDone: () {
            // Derba + Missa simultanées : la Missa s'affiche après la Derba (cumul, GDD 2.8).
            if (event.isMissa) {
              setState(() => _inMissaPhase = true);
            } else {
              _onEventDone();
            }
          },
        ),
      CaptureEvent() => MissaOverlay(
          key: ValueKey('missa-${event.playedCardId}'),
          playerNickname: nicknameOf(event.playerId),
          onDone: _onEventDone,
          // Si on arrive ici via _inMissaPhase après une Derba, le DerbaOverlay
          // a déjà affiché le total (Derba + point de Missa cumulés, GDD 2.8).
          pointsAlreadyShown: event.isDerba,
        ),
      SubRoundRevealEvent() => RevealOverlay(
          event: event,
          nicknameOf: nicknameOf,
          onDone: _onEventDone,
        ),
      RoundEndEvent() => RoundEndOverlay(event: event, onDone: _onEventDone),
      NewDealEvent() => DealOverlay(
          key: ValueKey('deal-${event.dealIndex}-${event.cardsPerPlayer}'),
          dealerName: nicknameOf(event.dealerId),
          cardsPerPlayer: event.cardsPerPlayer,
          dealIndex: event.dealIndex,
          dealsPerRound: event.dealsPerRound,
          playerCount: state.players.length,
          onDone: _onEventDone,
        ),
      GameOverEvent() || GameAbandonedEvent() => _InstantDone(onDone: _onEventDone),
      _ => _InstantDone(onDone: _onEventDone),
    };
  }

  Future<bool?> _confirmQuit() {
    final strings = context.read<AppStrings>();
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RondaColors.wood,
        title: Text(strings.t('game.quitTitle'), style: const TextStyle(color: RondaColors.cream)),
        content: Text(
          strings.t('game.quitBody'),
          style: const TextStyle(color: RondaColors.creamDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.t('game.quitStay'), style: const TextStyle(color: RondaColors.gold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.t('game.quitConfirm'), style: const TextStyle(color: RondaColors.red)),
          ),
        ],
      ),
    );
  }
}

/// Overlay vide qui termine immédiatement (transitions gameOver/abandon).
class _InstantDone extends StatefulWidget {
  final VoidCallback onDone;
  const _InstantDone({required this.onDone});

  @override
  State<_InstantDone> createState() => _InstantDoneState();
}

class _InstantDoneState extends State<_InstantDone> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Barre de score : deux panneaux d'équipe avec progression vers 41.
class _ScoreBar extends StatelessWidget {
  final PublicState state;
  final AppStrings strings;
  final VoidCallback onQuit;

  const _ScoreBar({required this.state, required this.strings, required this.onQuit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        children: [
          Expanded(child: _TeamPanel(team: 'A', score: state.scores['A'] ?? 0, strings: strings)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: RondaColors.wood.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: RondaColors.gold.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        strings.t('game.roundBadge', {'n': state.roundNumber}),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: RondaColors.goldLight,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        strings.t('game.dealBadge', {
                          'n': state.dealIndex + 1,
                          'total': state.dealsPerRound,
                        }),
                        style: const TextStyle(fontSize: 10, color: RondaColors.creamDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: onQuit,
                  child: Icon(Icons.close_rounded,
                      color: RondaColors.creamDark.withValues(alpha: 0.7), size: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: _TeamPanel(
              team: 'B',
              score: state.scores['B'] ?? 0,
              mirrored: true,
              strings: strings,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamPanel extends StatelessWidget {
  final String team;
  final int score;
  final bool mirrored;
  final AppStrings strings;

  const _TeamPanel({
    required this.team,
    required this.score,
    required this.strings,
    this.mirrored = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = RondaColors.team(team);
    final light = RondaColors.teamLight(team);
    final progress = (score / 41).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: mirrored ? Alignment.centerRight : Alignment.centerLeft,
          end: mirrored ? Alignment.centerLeft : Alignment.centerRight,
          colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.55)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: light.withValues(alpha: 0.7), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: mirrored ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: mirrored ? TextDirection.rtl : TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${strings.t('lobby.teamHeader', {'letter': team})} ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: RondaColors.cream.withValues(alpha: 0.85),
                  letterSpacing: 1,
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score.toDouble()),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, value, child) =>Text(
                  '${value.round()}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: RondaColors.cream,
                    height: 1,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1))],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 5,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, value, child) =>LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation(RondaColors.goldLight),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge d'un adversaire/coéquipier : avatar rond à initiale, pseudo, cartes
/// restantes, badge d'annonce anonyme (GDD 2.5) et halo doré pulsant à son tour.
class _SeatBadge extends StatelessWidget {
  final PublicPlayer? player;
  final PublicState state;
  final bool compact;

  const _SeatBadge({required this.player, required this.state, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final p = player;
    if (p == null) return SizedBox(width: compact ? 62 : 0, height: compact ? 0 : 62);

    final isTheirTurn = state.currentTurnPlayerId == p.id;
    final isLead = state.leadPlayerId == p.id;
    final teamColor = RondaColors.team(p.team);

    final avatar = _PulsingRing(
      active: isTheirTurn,
      child: _CountdownRing(
        active: isTheirTurn && state.turnEndsAt > 0,
        endsAt: state.turnEndsAt,
        child: Container(
          width: 44,
          height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [RondaColors.teamLight(p.team), teamColor],
          ),
          border: Border.all(
            color: isTheirTurn ? RondaColors.goldLight : RondaColors.cream.withValues(alpha: 0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Center(
          child: Text(
            p.nickname.isEmpty ? '?' : p.nickname[0].toUpperCase(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: RondaColors.cream,
            ),
          ),
        ),
        ),
      ),
    );

    final badge = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Petit éventail de dos de cartes derrière l'avatar (façon Blazing 8),
            // qui reflète le nombre de cartes restantes en main.
            if (p.handCount > 0)
              Positioned(
                top: -14,
                child: SizedBox(
                  width: 70,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      for (var i = 0; i < p.handCount.clamp(0, 4); i++)
                        Transform.rotate(
                          angle: (i - (p.handCount.clamp(0, 4) - 1) / 2) * 0.28,
                          alignment: Alignment.bottomCenter,
                          child: const CardBackWidget(width: 22),
                        ),
                    ],
                  ),
                ),
              ),
            avatar,
            if (isLead) ...[
              const Positioned(
                top: -7,
                right: -3,
                child: Icon(Icons.workspace_premium, size: 16, color: RondaColors.goldLight),
              ),
              // Pile de cartes du donneur : tout le monde voit qui distribue.
              const Positioned(
                bottom: -2,
                right: -16,
                child: _DealerPile(),
              ),
            ],
            Positioned(
              bottom: -3,
              left: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: RondaColors.wood,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RondaColors.creamDark.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Text(
                  '${p.handCount}',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: RondaColors.cream),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 76),
          child: Text(
            p.nickname.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isTheirTurn ? FontWeight.w800 : FontWeight.w600,
              color: isTheirTurn ? RondaColors.goldLight : RondaColors.cream,
            ),
          ),
        ),
        if (p.announcementKind.isNotEmpty) ...[
          const SizedBox(height: 3),
          AnnouncementPill(kind: p.announcementKind),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 0, vertical: 2),
      child: badge,
    );
  }
}

/// Petite pile de cartes face cachée accolée au donneur (le Lead) : marqueur
/// permanent « c'est lui qui distribue » (le paquet vole depuis ici à la TFRI9A).
class _DealerPile extends StatelessWidget {
  const _DealerPile();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 34,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: i * 2.0,
              top: -i * 2.0,
              child: Container(
                width: 20,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF9B2C2C), Color(0xFF6E1717)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: RondaColors.cream.withValues(alpha: 0.85), width: 1),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 2, offset: const Offset(1, 1)),
                  ],
                ),
                child: Center(
                  child: Icon(Icons.style_rounded,
                      size: 9, color: RondaColors.goldLight.withValues(alpha: 0.8)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pastille d'annonce bien visible : révèle le TYPE (RONDA/TRINGA) mais
/// jamais la valeur (GDD 2.5, décision 2026-07-12). Pulse pour attirer l'œil.
class AnnouncementPill extends StatefulWidget {
  final String kind; // 'ronda' | 'tringa'
  final double fontSize;

  const AnnouncementPill({super.key, required this.kind, this.fontSize = 11});

  @override
  State<AnnouncementPill> createState() => _AnnouncementPillState();
}

class _AnnouncementPillState extends State<AnnouncementPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppStrings>();
    final isTringa = widget.kind == 'tringa';
    final colors = isTringa
        ? const [Color(0xFFB65CE8), Color(0xFF7B2FA8)] // violet royal : la Tringa est rare
        : const [Color(0xFFF2C94C), Color(0xFFE0902B)];
    return ScaleTransition(
      scale: Tween(begin: 0.95, end: 1.08).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: widget.fontSize * 0.8, vertical: widget.fontSize * 0.25),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF3A2417), width: 1.5),
          boxShadow: [
            BoxShadow(color: colors.first.withValues(alpha: 0.7), blurRadius: 10),
          ],
        ),
        child: Text(
          isTringa ? strings.t('game.announcementTringa') : strings.t('game.announcementRonda'),
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: isTringa ? Colors.white : const Color(0xFF3A2417),
          ),
        ),
      ),
    );
  }
}

/// Anneau de compte à rebours du tour (10 s) : se vide autour de l'avatar,
/// passe à l'orange puis au rouge quand le temps file.
class _CountdownRing extends StatefulWidget {
  final bool active;
  final int endsAt; // epoch ms
  final Widget child;

  const _CountdownRing({required this.active, required this.endsAt, required this.child});

  @override
  State<_CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<_CountdownRing>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    if (widget.active) _ticker.start();
  }

  @override
  void didUpdateWidget(_CountdownRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ticker.isActive) _ticker.start();
    if (!widget.active && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    final remaining = (widget.endsAt - DateTime.now().millisecondsSinceEpoch)
        .clamp(0, turnTimeoutMs)
        .toDouble();
    final fraction = remaining / turnTimeoutMs;
    final color = fraction > 0.5
        ? RondaColors.goldLight
        : Color.lerp(const Color(0xFFE05A2B), RondaColors.goldLight, fraction * 2)!;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 54,
          height: 54,
          child: CircularProgressIndicator(
            value: fraction,
            strokeWidth: 4,
            strokeCap: StrokeCap.round,
            backgroundColor: Colors.black.withValues(alpha: 0.35),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Halo doré pulsant autour de l'avatar du joueur dont c'est le tour.
class _PulsingRing extends StatefulWidget {
  final bool active;
  final Widget child;
  const _PulsingRing({required this.active, required this.child});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(_PulsingRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) _controller.repeat();
    if (!widget.active && _controller.isAnimating) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: RondaColors.goldLight.withValues(alpha: 0.55 * (1 - t)),
                blurRadius: 6 + 14 * t,
                spreadRadius: 2 + 6 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Tapis central en feutre : cartes éparpillées avec rotations stables,
/// et paquet de Derba en attente de surenchère mis en scène au centre.
class _FeltTable extends StatelessWidget {
  final List<GameCard> cards;
  final List<GameCard> pendingDerba;
  final AppStrings strings;

  const _FeltTable({required this.cards, required this.pendingDerba, required this.strings});

  @override
  Widget build(BuildContext context) {
    final isEmpty = cards.isEmpty && pendingDerba.isEmpty;
    // Le fond illustré fournit déjà le tapis zellige encadré d'or :
    // on ne pose qu'un léger voile pour détacher les cartes.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(26),
      ),
      child: isEmpty
          ? Center(
              child: Opacity(
                opacity: 0.35,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.style_outlined, size: 34, color: RondaColors.goldLight),
                    const SizedBox(height: 4),
                    Text(
                      strings.t('game.emptyTable'),
                      style: const TextStyle(fontSize: 12, color: RondaColors.creamDark),
                    ),
                  ],
                ),
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pendingDerba.isNotEmpty) ...[
                      _PendingDerbaStack(cards: pendingDerba, strings: strings),
                      const SizedBox(height: 10),
                    ],
                    Wrap(
                      spacing: 4,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final card in cards) _TossedCard(key: ValueKey(card.id), card: card),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Paquet de Derba posé sur la table en attente de surenchère : cartes
/// empilées en éventail serré, halo doré pulsant — tout le monde voit
/// que ça peut encore se faire reprendre.
class _PendingDerbaStack extends StatefulWidget {
  final List<GameCard> cards;
  final AppStrings strings;

  const _PendingDerbaStack({required this.cards, required this.strings});

  @override
  State<_PendingDerbaStack> createState() => _PendingDerbaStackState();
}

class _PendingDerbaStackState extends State<_PendingDerbaStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: RondaColors.goldLight.withValues(alpha: 0.35 + 0.35 * _pulse.value),
              blurRadius: 16 + 10 * _pulse.value,
            ),
          ],
        ),
        child: child,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 84,
            width: 60.0 + 22.0 * (widget.cards.length - 1),
            child: Stack(
              children: [
                for (final (i, card) in widget.cards.indexed)
                  Positioned(
                    left: i * 22.0,
                    child: PlayingCardWidget(
                      card: card,
                      width: 54,
                      angle: (i - (widget.cards.length - 1) / 2) * 0.06,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: RondaColors.gold.withValues(alpha: 0.7)),
            ),
            child: Text(
              widget.strings.t('game.pendingDerba'),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: RondaColors.goldLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte posée sur la table : rotation pseudo-aléatoire stable + pop d'arrivée.
class _TossedCard extends StatelessWidget {
  final GameCard card;

  const _TossedCard({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    // Jitter déterministe par carte pour que la table soit stable entre rebuilds.
    final seed = card.id.hashCode;
    final angle = ((seed % 17) - 8) * 0.016; // environ -7° à +7°

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Transform.scale(scale: 0.5 + 0.5 * t, child: child),
      child: PlayingCardWidget(card: card, width: 54, angle: angle),
    );
  }
}

class _TurnIndicator extends StatelessWidget {
  final PublicState state;
  final String? myId;
  final AppStrings strings;

  const _TurnIndicator({required this.state, required this.myId, required this.strings});

  @override
  Widget build(BuildContext context) {
    final isMyTurn = state.currentTurnPlayerId == myId;
    final current = state.playerById(state.currentTurnPlayerId);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey('${state.currentTurnPlayerId}-$isMyTurn'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isMyTurn
              ? RondaColors.gold.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isMyTurn ? RondaColors.gold : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          isMyTurn
              ? strings.t('game.yourTurn')
              : strings.t('game.playerTurn', {
                  'nickname': (current?.nickname ?? '...').toUpperCase(),
                }),
          style: TextStyle(
            fontSize: isMyTurn ? 14 : 13,
            fontWeight: isMyTurn ? FontWeight.w900 : FontWeight.w500,
            letterSpacing: isMyTurn ? 1.2 : 0,
            color: isMyTurn ? RondaColors.goldLight : RondaColors.creamDark,
          ),
        ),
      ),
    );
  }
}

/// Jauge de temps du joueur local : barre qui se vide sous l'indicateur de
/// tour, vire au rouge sur les 3 dernières secondes.
class _MyCountdownBar extends StatefulWidget {
  final int endsAt;

  const _MyCountdownBar({super.key, required this.endsAt});

  @override
  State<_MyCountdownBar> createState() => _MyCountdownBarState();
}

class _MyCountdownBarState extends State<_MyCountdownBar> {
  // Timer.periodic plutôt qu'un Ticker : il tourne indépendamment du planificateur
  // de frames et n'est jamais mis en sourdine (TickerMode), donc la jauge du joueur
  // courant avance vraiment même quand aucun message serveur ne rafraîchit l'écran.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (widget.endsAt - DateTime.now().millisecondsSinceEpoch)
        .clamp(0, turnTimeoutMs)
        .toDouble();
    final fraction = remaining / turnTimeoutMs;
    final seconds = (remaining / 1000).ceil();
    final urgent = fraction < 0.3;
    final color = urgent ? const Color(0xFFE05A2B) : RondaColors.goldLight;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 190,
          height: 12,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFF3A2417), width: 1.5),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: urgent
                    ? [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 8)]
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Gros compteur : le joueur courant sait toujours où il en est.
        AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: urgent ? 1.2 : 1.0,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.55),
              border: Border.all(color: color, width: 2.5),
              boxShadow: urgent
                  ? [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 10)]
                  : null,
            ),
            child: Center(
              child: Text(
                '$seconds',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Gros bouton de jeu unique : le serveur capture d'office si c'est possible
/// (GDD 2.6) — le bouton annonce juste ce qui va se passer.
class _PlayButton extends StatefulWidget {
  final bool visible;
  final bool capture;
  final VoidCallback onPlay;
  final AppStrings strings;

  const _PlayButton({
    required this.visible,
    required this.capture,
    required this.onPlay,
    required this.strings,
  });

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = widget.capture
        ? const LinearGradient(colors: [Color(0xFFF2C94C), Color(0xFFE0902B)])
        : const LinearGradient(colors: [Color(0xFF2E8B57), Color(0xFF1F6E43)]);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      offset: widget.visible ? Offset.zero : const Offset(0, 1.5),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: widget.visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !widget.visible,
          child: ScaleTransition(
            scale: widget.capture
                ? Tween(begin: 1.0, end: 1.06)
                    .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut))
                : const AlwaysStoppedAnimation(1.0),
            child: GestureDetector(
              onTap: widget.onPlay,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 12),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.capture ? const Color(0xFFF2C94C) : const Color(0xFF2E8B57))
                          .withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.capture ? Icons.bolt_rounded : Icons.arrow_upward_rounded,
                      size: 20,
                      color: widget.capture ? RondaColors.wood : RondaColors.cream,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.capture
                          ? widget.strings.t('game.captureButton')
                          : widget.strings.t('game.playButton'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: widget.capture ? RondaColors.wood : RondaColors.cream,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Main en éventail : les cartes se chevauchent en arc comme tenues en main,
/// la carte sélectionnée se soulève ; re-taper la carte sélectionnée la joue.
class _FanHand extends StatelessWidget {
  final List<GameCard> cards;
  final String? selectedCardId;
  final bool enabled;
  final double scale;
  final ValueChanged<String> onSelect;
  final VoidCallback onPlaySelected;

  const _FanHand({
    required this.cards,
    required this.selectedCardId,
    required this.enabled,
    required this.onSelect,
    required this.onPlaySelected,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return SizedBox(height: 150 * scale);

    // Largeur de carte proportionnelle à la hauteur d'écran, et jamais plus
    // large que ce que l'écran peut afficher sans chevauchement excessif.
    final screenWidth = MediaQuery.of(context).size.width;
    final n = cards.length;
    final cardWidth = math.min(84.0 * scale, (screenWidth - 24) / 3.2);
    // Écartement horizontal : chevauchement d'autant plus fort qu'il y a de cartes.
    // Borné aussi pour que l'éventail complet tienne dans la largeur écran.
    final maxStepForWidth =
        n == 1 ? 0.0 : (screenWidth - 24 - cardWidth) / (n - 1);
    final step = n == 1
        ? 0.0
        : math.min(math.min(56.0 * scale, 250 * scale / (n - 1)), maxStepForWidth);
    final totalWidth = cardWidth + step * (n - 1);
    // Éventail : de -12° à +12° selon la position.
    final maxAngle = n == 1 ? 0.0 : math.min(0.21, 0.07 * (n - 1));

    // La carte sélectionnée est dessinée en dernier (au-dessus des autres).
    final order = List<int>.generate(n, (i) => i);
    final selIdx = cards.indexWhere((c) => c.id == selectedCardId);
    if (selIdx != -1) {
      order.remove(selIdx);
      order.add(selIdx);
    }

    return Opacity(
      opacity: enabled ? 1 : 0.75,
      child: SizedBox(
        height: 158 * scale,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            for (final i in order)
              _fanCard(context, i, n, step, totalWidth, cardWidth, maxAngle),
          ],
        ),
      ),
    );
  }

  Widget _fanCard(BuildContext context, int i, int n, double step, double totalWidth,
      double cardWidth, double maxAngle) {
    final card = cards[i];
    final selected = card.id == selectedCardId;
    final t = n == 1 ? 0.5 : i / (n - 1);
    final angle = (t - 0.5) * 2 * maxAngle;
    // L'arc : les cartes du bord descendent légèrement (mis à l'échelle).
    final arcDrop = (1 - math.cos(angle)) * 260 * scale;
    final lift = selected ? -30.0 * scale : 0.0;

    return Positioned(
      left: (MediaQuery.of(context).size.width - totalWidth) / 2 + i * step,
      bottom: 8.0 - arcDrop - lift,
      child: GestureDetector(
        onTap: !enabled
            ? null
            : () => selected ? onPlaySelected() : onSelect(card.id),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          scale: selected ? 1.10 : 1.0,
          child: PlayingCardWidget(
            card: card,
            width: cardWidth,
            selected: selected,
            angle: selected ? 0 : angle,
          ),
        ),
      ),
    );
  }
}
