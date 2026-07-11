import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/protocol.dart';
import '../net/game_client.dart';
import '../theme.dart';
import '../widgets/event_overlays.dart';
import '../widgets/playing_card.dart';
import 'victory_screen.dart';

/// Table de jeu : sièges autour du tapis, pile centrale, main en bas.
/// Les événements serveur (Derba, Missa, révélations, fins de manche)
/// sont mis en file et joués un par un en overlay bloquant (GDD 3.4).
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

  void _enqueueEvent(GameEvent event) {
    if (!mounted) return;
    if (event is ErrorEvent) {
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

  void _playSelected({required bool capture}) {
    final cardId = _selectedCardId;
    if (cardId == null) return;
    context.read<GameClient>().playCard(cardId, capture: capture);
    setState(() => _selectedCardId = null);
  }

  @override
  Widget build(BuildContext context) {
    final client = context.watch<GameClient>();
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
    final canCapture = selectedCard != null &&
        state.tablePile.any((c) => c.rank == selectedCard.rank);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final quit = await _confirmQuit();
        if (quit == true && mounted) _exitToHome();
      },
      child: Scaffold(
        body: ZelligeBackground(
          baseColor: RondaColors.greenDeep,
          patternColor: RondaColors.goldLight,
          child: SafeArea(
            child: Stack(
              children: [
                IgnorePointer(
                  ignoring: _currentEvent != null,
                  child: Column(
                    children: [
                      _ScoreBar(state: state, onQuit: () async {
                        final quit = await _confirmQuit();
                        if (quit == true && mounted) _exitToHome();
                      }),
                      const SizedBox(height: 4),
                      _SeatBadge(player: seatAt(2), state: state, alignment: Alignment.center),
                      Expanded(
                        child: Row(
                          children: [
                            _SeatBadge(player: seatAt(3), state: state, vertical: true),
                            Expanded(child: _TablePile(cards: state.tablePile)),
                            _SeatBadge(player: seatAt(1), state: state, vertical: true),
                          ],
                        ),
                      ),
                      _TurnIndicator(state: state, myId: client.playerId),
                      const SizedBox(height: 6),
                      _ActionBar(
                        visible: selectedCard != null && client.isMyTurn,
                        canCapture: canCapture,
                        onCapture: () => _playSelected(capture: true),
                        onPlace: () => _playSelected(capture: false),
                      ),
                      const SizedBox(height: 6),
                      _Hand(
                        cards: client.hand,
                        selectedCardId: _selectedCardId,
                        enabled: client.isMyTurn,
                        onSelect: (id) => setState(
                          () => _selectedCardId = _selectedCardId == id ? null : id,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
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
        ),
      SubRoundRevealEvent() => RevealOverlay(
          event: event,
          nicknameOf: nicknameOf,
          onDone: _onEventDone,
        ),
      RoundEndEvent() => RoundEndOverlay(event: event, onDone: _onEventDone),
      GameOverEvent() || GameAbandonedEvent() => _InstantDone(onDone: _onEventDone),
      _ => _InstantDone(onDone: _onEventDone),
    };
  }

  Future<bool?> _confirmQuit() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RondaColors.wood,
        title: const Text('Quitter la partie ?', style: TextStyle(color: RondaColors.cream)),
        content: const Text(
          'La partie sera annulée pour tous les joueurs.',
          style: TextStyle(color: RondaColors.creamDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Rester', style: TextStyle(color: RondaColors.gold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitter', style: TextStyle(color: RondaColors.red)),
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

class _ScoreBar extends StatelessWidget {
  final PublicState state;
  final VoidCallback onQuit;

  const _ScoreBar({required this.state, required this.onQuit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: RondaColors.wood.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RondaColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          _TeamScore(team: 'A', score: state.scores['A'] ?? 0),
          const Spacer(),
          Column(
            children: [
              Text(
                'Manche ${state.roundNumber}',
                style: const TextStyle(fontSize: 12, color: RondaColors.creamDark),
              ),
              Text(
                'Donne ${state.dealIndex + 1}/3',
                style: const TextStyle(fontSize: 11, color: RondaColors.creamDark),
              ),
            ],
          ),
          const Spacer(),
          _TeamScore(team: 'B', score: state.scores['B'] ?? 0),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onQuit,
            child: const Icon(Icons.close, color: RondaColors.creamDark, size: 20),
          ),
        ],
      ),
    );
  }
}

class _TeamScore extends StatelessWidget {
  final String team;
  final int score;

  const _TeamScore({required this.team, required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: RondaColors.team(team), shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$score',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: RondaColors.cream,
          ),
        ),
        Text(
          '/41',
          style: TextStyle(fontSize: 12, color: RondaColors.creamDark.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}

/// Badge d'un adversaire/coéquipier : pseudo, équipe, nombre de cartes,
/// badge d'annonce anonyme (GDD 2.5) et indicateur de tour.
class _SeatBadge extends StatelessWidget {
  final PublicPlayer? player;
  final PublicState state;
  final bool vertical;
  final Alignment alignment;

  const _SeatBadge({
    required this.player,
    required this.state,
    this.vertical = false,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final p = player;
    if (p == null) return const SizedBox(width: 60);

    final isTheirTurn = state.currentTurnPlayerId == p.id;
    final isLead = state.leadPlayerId == p.id;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: RondaColors.wood.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTheirTurn ? RondaColors.gold : RondaColors.team(p.team).withValues(alpha: 0.6),
          width: isTheirTurn ? 2 : 1,
        ),
        boxShadow: isTheirTurn
            ? [BoxShadow(color: RondaColors.gold.withValues(alpha: 0.4), blurRadius: 10)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: RondaColors.team(p.team), shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 80),
                child: Text(
                  p.nickname,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: RondaColors.cream,
                  ),
                ),
              ),
              if (isLead) ...[
                const SizedBox(width: 4),
                const Icon(Icons.workspace_premium, size: 13, color: RondaColors.gold),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.style, size: 12, color: RondaColors.creamDark),
              const SizedBox(width: 3),
              Text(
                '${p.handCount}',
                style: const TextStyle(fontSize: 12, color: RondaColors.creamDark),
              ),
              if (p.hasAnnouncement) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: RondaColors.gold.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: RondaColors.gold, width: 0.8),
                  ),
                  child: const Text(
                    '!',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: RondaColors.goldLight,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (vertical) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: badge);
    }
    return Align(alignment: alignment, child: badge);
  }
}

class _TablePile extends StatelessWidget {
  final List<GameCard> cards;

  const _TablePile({required this.cards});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Center(
        child: Container(
          width: 70,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: RondaColors.goldLight.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.filter_none,
            color: RondaColors.goldLight.withValues(alpha: 0.25),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 6,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final card in cards)
              PlayingCardWidget(key: ValueKey(card.id), card: card, width: 52),
          ],
        ),
      ),
    );
  }
}

class _TurnIndicator extends StatelessWidget {
  final PublicState state;
  final String? myId;

  const _TurnIndicator({required this.state, required this.myId});

  @override
  Widget build(BuildContext context) {
    final isMyTurn = state.currentTurnPlayerId == myId;
    final current = state.playerById(state.currentTurnPlayerId);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Text(
        key: ValueKey(state.currentTurnPlayerId),
        isMyTurn ? 'À toi de jouer !' : 'Au tour de ${current?.nickname ?? "..."}',
        style: TextStyle(
          fontSize: 15,
          fontWeight: isMyTurn ? FontWeight.w800 : FontWeight.w500,
          color: isMyTurn ? RondaColors.goldLight : RondaColors.creamDark,
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool visible;
  final bool canCapture;
  final VoidCallback onCapture;
  final VoidCallback onPlace;

  const _ActionBar({
    required this.visible,
    required this.canCapture,
    required this.onCapture,
    required this.onPlace,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (canCapture) ...[
              ElevatedButton.icon(
                onPressed: onCapture,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Capturer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RondaColors.green,
                  foregroundColor: RondaColors.cream,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
              const SizedBox(width: 12),
            ],
            OutlinedButton.icon(
              onPressed: onPlace,
              icon: const Icon(Icons.upload, size: 18),
              label: Text(canCapture ? 'Poser' : 'Jouer'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hand extends StatelessWidget {
  final List<GameCard> cards;
  final String? selectedCardId;
  final bool enabled;
  final ValueChanged<String> onSelect;

  const _Hand({
    required this.cards,
    required this.selectedCardId,
    required this.enabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: SizedBox(
        height: 120,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final card in cards)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: PlayingCardWidget(
                  key: ValueKey(card.id),
                  card: card,
                  width: 68,
                  selected: card.id == selectedCardId,
                  onTap: enabled ? () => onSelect(card.id) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
