import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/protocol.dart';
import '../net/game_client.dart';
import '../theme.dart';
import 'game_screen.dart';

/// Lobby : code de room partageable, choix d'équipe explicite (GDD 3.1),
/// lancement par l'hôte quand la table est complète (2v2).
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  StreamSubscription<GameEvent>? _eventSub;
  bool _navigatedToGame = false;

  @override
  void initState() {
    super.initState();
    final client = context.read<GameClient>();
    _eventSub = client.events.listen(_onEvent);
    client.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    context.read<GameClient>().removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    final client = context.read<GameClient>();
    if (!_navigatedToGame && client.state?.phase == 'playing') {
      _navigatedToGame = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );
    }
  }

  void _onEvent(GameEvent event) {
    if (!mounted) return;
    if (event is ErrorEvent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(event.message),
          backgroundColor: RondaColors.redDeep,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _leave() {
    context.read<GameClient>().leaveRoom();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final client = context.watch<GameClient>();
    final state = client.state;

    if (state == null) {
      // Room quittée ou connexion perdue : retour à l'accueil.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final teamA = state.players.where((p) => p.team == 'A').toList();
    final teamB = state.players.where((p) => p.team == 'B').toList();
    final isFull = state.players.length == 4;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: ZelligeBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _leave,
                        icon: const Icon(Icons.arrow_back, color: RondaColors.creamDark),
                      ),
                      const Spacer(),
                      Text(
                        '${state.players.length}/4 joueurs',
                        style: const TextStyle(color: RondaColors.creamDark, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Code de la room, tap pour copier.
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: state.roomCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code copié !'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: RondaColors.woodLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: RondaColors.gold, width: 2),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'CODE DE LA PARTIE',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 2,
                              color: RondaColors.creamDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                state.roomCode,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 10,
                                  color: RondaColors.gold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.copy, color: RondaColors.creamDark, size: 20),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _TeamColumn(
                            team: 'A',
                            players: teamA,
                            myId: client.playerId,
                            onJoin: () => client.joinTeam('A'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _TeamColumn(
                            team: 'B',
                            players: teamB,
                            myId: client.playerId,
                            onJoin: () => client.joinTeam('B'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (client.isHost)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isFull ? client.startGame : null,
                        child: Text(isFull ? 'LANCER LA PARTIE' : 'EN ATTENTE DE JOUEURS...'),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        "En attente du lancement par l'hôte...",
                        style: TextStyle(color: RondaColors.creamDark),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final String team;
  final List<PublicPlayer> players;
  final String? myId;
  final VoidCallback onJoin;

  const _TeamColumn({
    required this.team,
    required this.players,
    required this.myId,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final color = RondaColors.team(team);
    final iAmInTeam = players.any((p) => p.id == myId);
    final isFull = players.length >= 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            'ÉQUIPE $team',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: RondaColors.teamLight(team),
            ),
          ),
          const SizedBox(height: 16),
          for (final player in players) ...[
            _PlayerChip(player: player, isMe: player.id == myId, color: color),
            const SizedBox(height: 8),
          ],
          for (int i = players.length; i < 2; i++) ...[
            const _EmptySlot(),
            const SizedBox(height: 8),
          ],
          const Spacer(),
          if (!iAmInTeam)
            OutlinedButton(
              onPressed: isFull ? null : onJoin,
              style: OutlinedButton.styleFrom(
                foregroundColor: RondaColors.teamLight(team),
                side: BorderSide(color: color),
              ),
              child: const Text('Rejoindre'),
            ),
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final PublicPlayer player;
  final bool isMe;
  final Color color;

  const _PlayerChip({required this.player, required this.isMe, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: RondaColors.wood.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: isMe ? Border.all(color: RondaColors.gold, width: 1.5) : null,
      ),
      child: Row(
        children: [
          if (player.isHost) ...[
            const Icon(Icons.star, color: RondaColors.gold, size: 16),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              isMe ? '${player.nickname} (toi)' : player.nickname,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                color: RondaColors.cream,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RondaColors.creamDark.withValues(alpha: 0.25)),
      ),
      child: Text(
        'Place libre',
        style: TextStyle(
          color: RondaColors.creamDark.withValues(alpha: 0.5),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
