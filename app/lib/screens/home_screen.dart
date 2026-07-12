import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/protocol.dart';
import '../net/game_client.dart';
import '../theme.dart';
import '../widgets/chunky_button.dart';
import 'lobby_screen.dart';

/// Accueil : pseudo + créer une partie ou rejoindre avec un code,
/// façon Among Us — aucune inscription (GDD 3.1).
/// Le logo RONDA fait partie de l'illustration de fond générée.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nicknameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _busy = false;
  String _mode = '2v2';
  bool _isPublic = false;
  Timer? _publicRoomsTimer;

  @override
  void initState() {
    super.initState();
    final client = context.read<GameClient>();
    // Rafraîchit la liste des salons publics tant qu'on est sur l'accueil,
    // le temps d'avoir assez d'utilisateurs pour un vrai matchmaking (2026-07-12).
    // connect() notifie ses listeners -> reporté après le premier frame pour ne
    // pas déclencher un rebuild du provider pendant que l'arbre se monte encore.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      client.requestPublicRooms();
    });
    _publicRoomsTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      // On cesse de solliciter le serveur dès qu'une room est rejointe : l'accueil
      // reste monté SOUS le lobby/jeu (Navigator.push, pas pushReplacement), donc
      // sans ce garde le polling continuerait toute la partie. `roomCode != null`
      // signale qu'on a reçu "joined" -> plus rien à lister depuis l'accueil.
      if (!_busy && client.roomCode == null) client.requestPublicRooms();
    });
  }

  @override
  void dispose() {
    _publicRoomsTimer?.cancel();
    _nicknameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? get _nicknameError {
    final nick = _nicknameController.text.trim();
    if (nick.isEmpty) return 'Choisis un pseudo';
    return null;
  }

  Future<void> _createRoom() async {
    if (_nicknameError != null) {
      _showError(_nicknameError!);
      return;
    }
    await _perform(
      () => context.read<GameClient>().createRoom(
            _nicknameController.text.trim(),
            mode: _mode,
            isPublic: _isPublic,
          ),
    );
  }

  Future<void> _joinRoom() async {
    if (_nicknameError != null) {
      _showError(_nicknameError!);
      return;
    }
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 5) {
      _showError('Le code doit faire 5 caractères');
      return;
    }
    await _perform(() => context.read<GameClient>().joinRoom(code, _nicknameController.text.trim()));
  }

  Future<void> _joinPublicRoom(String roomCode) async {
    if (_nicknameError != null) {
      _showError(_nicknameError!);
      return;
    }
    await _perform(() => context.read<GameClient>().joinRoom(roomCode, _nicknameController.text.trim()));
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() => _busy = true);
    final client = context.read<GameClient>();
    // Repart d'une ardoise propre : une erreur laissée par une tentative
    // précédente ne doit pas être prise pour le résultat de celle-ci.
    client.clearError();
    try {
      await action();
      // Attend la confirmation "joined" (playerId assigné) ou une erreur serveur.
      await _waitForJoinOrError(client);
      if (!mounted) return;
      if (client.playerId != null && client.state != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LobbyScreen()),
        );
      } else if (client.lastError != null) {
        _showError(client.lastError!);
        client.leaveRoom();
      }
    } catch (_) {
      if (mounted && client.lastError != null) _showError(client.lastError!);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _waitForJoinOrError(GameClient client) async {
    if (client.playerId != null || client.lastError != null) return;
    final completer = Completer<void>();
    void listener() {
      if (client.playerId != null || client.lastError != null) {
        if (!completer.isCompleted) completer.complete();
      }
    }

    client.addListener(listener);
    try {
      await completer.future.timeout(const Duration(seconds: 8), onTimeout: () {
        client.lastError ??= 'Le serveur ne répond pas';
      });
    } finally {
      client.removeListener(listener);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: RondaColors.redDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IllustratedBackground(
        asset: 'assets/ui/home_bg.png',
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                  maxWidth: 420,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Le tiers supérieur laisse respirer le logo peint dans le fond.
                    SizedBox(height: constraints.maxHeight * 0.34),

                    ChunkyPanel(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                      child: Column(
                        children: [
                          const Text(
                            'TON PSEUDO',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Color(0xFF6B4A26),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _ParchmentField(
                            controller: _nicknameController,
                            hint: 'EX. HAMZA',
                            maxLength: 20,
                            fontSize: 18,
                            icon: Icons.person_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Choix du mode de jeu avant la création.
                    Row(
                      children: [
                        Expanded(
                          child: _ModeChip(
                            label: '2 VS 2',
                            icon: Icons.groups_rounded,
                            selected: _mode == '2v2',
                            onTap: () => setState(() => _mode = '2v2'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ModeChip(
                            label: '1 VS 1',
                            icon: Icons.sports_kabaddi_rounded,
                            selected: _mode == '1v1',
                            onTap: () => setState(() => _mode = '1v1'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Partie publique = visible dans la liste ci-dessous, sans code
                    // à partager (utile tant que le matchmaking mondial n'existe pas).
                    GestureDetector(
                      onTap: () => setState(() => _isPublic = !_isPublic),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: _isPublic,
                            onChanged: (v) => setState(() => _isPublic = v ?? false),
                            activeColor: const Color(0xFF8FA83B),
                            side: const BorderSide(color: Color(0xFF3A2417), width: 2),
                          ),
                          const Text(
                            'PARTIE PUBLIQUE (visible par tous)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Color(0xFF4A2E15),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    ChunkyButton.red(
                      label: 'CRÉER UNE PARTIE',
                      icon: Icons.play_arrow_rounded,
                      onPressed: _busy ? null : _createRoom,
                    ),
                    const SizedBox(height: 22),

                    _PublicRoomsList(onJoin: _busy ? null : _joinPublicRoom),
                    const SizedBox(height: 22),

                    ChunkyPanel(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                      child: Column(
                        children: [
                          const Text(
                            'REJOINDRE AVEC UN CODE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Color(0xFF6B4A26),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _ParchmentField(
                            controller: _codeController,
                            hint: 'ABCDE',
                            maxLength: 5,
                            fontSize: 24,
                            letterSpacing: 8,
                            icon: Icons.vpn_key_rounded,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                              UpperCaseTextFormatter(),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ChunkyButton.green(
                            label: 'REJOINDRE',
                            icon: Icons.group_rounded,
                            height: 54,
                            fontSize: 18,
                            onPressed: _busy ? null : _joinRoom,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: CircularProgressIndicator(color: RondaColors.goldLight),
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

/// Champ de saisie « parchemin » : creusé dans la planche (double contour,
/// ombre interne), icône thématique à gauche, façon inventaire de jeu.
class _ParchmentField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final double fontSize;
  final double letterSpacing;
  final IconData? icon;
  final List<TextInputFormatter>? inputFormatters;

  const _ParchmentField({
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.fontSize,
    this.letterSpacing = 0.5,
    this.icon,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Contour extérieur sombre = bord du renfoncement.
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2417),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFE0BC), Color(0xFFFFF8E6)],
          ),
          borderRadius: BorderRadius.circular(13),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 5,
              offset: Offset(0, 3),
              blurStyle: BlurStyle.inner,
            ),
          ],
        ),
        child: Row(
          children: [
            if (icon != null)
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Icon(icon, color: const Color(0xFF8A6238), size: fontSize + 4),
              ),
            Expanded(
              child: TextField(
                controller: controller,
                maxLength: maxLength,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: inputFormatters,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: letterSpacing,
                  color: const Color(0xFF4A2E15),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: const Color(0xFF4A2E15).withValues(alpha: 0.3),
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
            if (icon != null) SizedBox(width: fontSize + 18), // équilibre le centrage
          ],
        ),
      ),
    );
  }
}

/// Puce de sélection de mode : planche claire, dorée quand sélectionnée.
class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: selected
                ? const [Color(0xFFF6D571), Color(0xFFE0A32B)]
                : const [Color(0xFFF4E3BC), Color(0xFFDCC393)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF3A2417),
            width: selected ? 3 : 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFF2C94C).withValues(alpha: 0.55),
                    blurRadius: 12,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF4A2E15)),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: const Color(0xFF4A2E15).withValues(alpha: selected ? 1 : 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste des salons publics rejoignables sans code (le temps d'avoir assez
/// d'utilisateurs pour un vrai matchmaking mondial, 2026-07-12). Se met à
/// jour via le polling démarré dans _HomeScreenState.initState.
class _PublicRoomsList extends StatelessWidget {
  final Future<void> Function(String roomCode)? onJoin;

  const _PublicRoomsList({required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final rooms = context.watch<GameClient>().publicRooms;

    return ChunkyPanel(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        children: [
          const Text(
            'PARTIES PUBLIQUES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Color(0xFF6B4A26),
            ),
          ),
          const SizedBox(height: 10),
          if (rooms.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Aucune partie publique ouverte pour le moment',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B4A26),
                ),
              ),
            )
          else
            Column(
              children: [
                for (final room in rooms) ...[
                  _PublicRoomRow(room: room, onJoin: onJoin),
                  if (room != rooms.last) const SizedBox(height: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _PublicRoomRow extends StatelessWidget {
  final PublicRoomSummary room;
  final Future<void> Function(String roomCode)? onJoin;

  const _PublicRoomRow({required this.room, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFE0BC), Color(0xFFFFF8E6)],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF3A2417), width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Salon de ${room.hostNickname}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4A2E15),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${room.mode == '1v1' ? '1 VS 1' : '2 VS 2'} · ${room.playerCount}/${room.maxPlayers} joueurs',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A6238),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ChunkyButton.green(
            label: 'REJOINDRE',
            height: 40,
            fontSize: 13,
            onPressed: onJoin == null ? null : () => onJoin!(room.roomCode),
          ),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
