import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

  @override
  void dispose() {
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
    await _perform(() => context.read<GameClient>().createRoom(_nicknameController.text.trim()));
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

  Future<void> _perform(Future<void> Function() action) async {
    setState(() => _busy = true);
    final client = context.read<GameClient>();
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
                    const SizedBox(height: 18),

                    ChunkyButton.red(
                      label: 'CRÉER UNE PARTIE',
                      icon: Icons.play_arrow_rounded,
                      onPressed: _busy ? null : _createRoom,
                    ),
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

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
