import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/protocol.dart';
import '../net/game_client.dart';
import '../theme.dart';
import '../widgets/chunky_button.dart';
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
  // Référence sauvegardée : lire context.read() dans dispose() est interdit
  // (l'élément est déjà désactivé -> assertion « deactivated widget's ancestor »,
  // le carré rouge qui flashait au passage lobby -> jeu pendant la distribution).
  GameClient? _client;

  @override
  void initState() {
    super.initState();
    final client = context.read<GameClient>();
    _client = client;
    _eventSub = client.events.listen(_onEvent);
    client.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _client?.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    final client = _client;
    if (client == null) return;
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
    final strings = context.watch<AppStrings>();
    final state = client.state;

    if (state == null) {
      // Room quittée ou connexion perdue : retour à l'accueil.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final teamA = state.players.where((p) => p.team == 'A').toList();
    final teamB = state.players.where((p) => p.team == 'B').toList();
    final is1v1 = state.mode == '1v1';
    final maxPlayers = is1v1 ? 2 : 4;
    final isFull = state.players.length == maxPlayers;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: IllustratedBackground(
          asset: 'assets/ui/game_bg.png',
          dim: 0.12,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: _leave),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: RondaColors.gold.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          strings.t('lobby.headerBadge', {
                            'mode': is1v1 ? strings.t('home.mode1v1') : strings.t('home.mode2v2'),
                            'count': state.players.length,
                            'max': maxPlayers,
                          }),
                          style: const TextStyle(
                            color: RondaColors.cream,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Code de la room, tap pour copier — panneau bois clair.
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: state.roomCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(strings.t('lobby.codeCopied')),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: ChunkyPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      child: Column(
                        children: [
                          Text(
                            strings.t('lobby.codeLabel'),
                            style: const TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6B4A26),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                state.roomCode,
                                style: const TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 9,
                                  color: Color(0xFF4A2E15),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.copy_rounded, color: Color(0xFF8A6238), size: 22),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _TeamColumn(
                            team: 'A',
                            players: teamA,
                            myId: client.playerId,
                            slots: is1v1 ? 1 : 2,
                            onJoin: () => client.joinTeam('A'),
                            strings: strings,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _TeamColumn(
                            team: 'B',
                            players: teamB,
                            myId: client.playerId,
                            slots: is1v1 ? 1 : 2,
                            onJoin: () => client.joinTeam('B'),
                            strings: strings,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (client.isHost)
                    ChunkyButton.red(
                      label: isFull
                          ? strings.t('lobby.startGame')
                          : strings.t('lobby.waitingForPlayers'),
                      icon: isFull ? Icons.play_arrow_rounded : Icons.hourglass_top_rounded,
                      onPressed: isFull ? client.startGame : null,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        strings.t('lobby.waitingForHost'),
                        style: const TextStyle(color: RondaColors.creamDark, fontSize: 15),
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

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4E3BC), Color(0xFFDDC08A)],
          ),
          border: Border.all(color: const Color(0xFF3A2417), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF4A2E15), size: 22),
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final String team;
  final List<PublicPlayer> players;
  final String? myId;
  final int slots; // 2 en 2v2, 1 en 1v1
  final VoidCallback onJoin;
  final AppStrings strings;

  const _TeamColumn({
    required this.team,
    required this.players,
    required this.myId,
    required this.slots,
    required this.onJoin,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final color = RondaColors.team(team);
    final light = RondaColors.teamLight(team);
    final iAmInTeam = players.any((p) => p.id == myId);
    final isFull = players.length >= slots;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0.55)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3A2417), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            strings.t('lobby.teamHeader', {'letter': team}),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: RondaColors.cream,
              shadows: [Shadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1))],
            ),
          ),
          const SizedBox(height: 14),
          for (final player in players) ...[
            _PlayerChip(player: player, isMe: player.id == myId, strings: strings),
            const SizedBox(height: 8),
          ],
          for (int i = players.length; i < slots; i++) ...[
            _EmptySlot(strings: strings),
            const SizedBox(height: 8),
          ],
          const Spacer(),
          if (!iAmInTeam)
            ChunkyButton(
              label: strings.t('lobby.joinTeam'),
              height: 46,
              fontSize: 14,
              color: light,
              onPressed: isFull ? null : onJoin,
            ),
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final PublicPlayer player;
  final bool isMe;
  final AppStrings strings;

  const _PlayerChip({required this.player, required this.isMe, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? RondaColors.gold : const Color(0xFF3A2417),
          width: isMe ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFF4A2E15),
            child: Text(
              player.nickname.isEmpty ? '?' : player.nickname[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFF6E0),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMe
                  ? '${player.nickname.toUpperCase()} ${strings.t('lobby.youSuffix')}'
                  : player.nickname.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isMe ? FontWeight.w900 : FontWeight.w600,
                color: const Color(0xFF4A2E15),
              ),
            ),
          ),
          if (player.isHost) const Icon(Icons.star_rounded, color: Color(0xFFE0A32B), size: 18),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final AppStrings strings;

  const _EmptySlot({required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Row(
        children: [
          Icon(Icons.person_add_alt_rounded,
              size: 18, color: Colors.white.withValues(alpha: 0.55)),
          const SizedBox(width: 8),
          Text(
            strings.t('lobby.emptySlot'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
