import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../net/game_client.dart';
import '../theme.dart';
import 'lobby_screen.dart';

/// Accueil : pseudo + créer une partie ou rejoindre avec un code,
/// façon Among Us — aucune inscription (GDD 3.1).
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
      body: ZelligeBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Titre
                  Text(
                    'RONDA',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                      color: RondaColors.gold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'الروندة المغربية',
                    style: TextStyle(fontSize: 18, color: RondaColors.creamDark),
                  ),
                  const SizedBox(height: 48),

                  TextField(
                    controller: _nicknameController,
                    maxLength: 20,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Ton pseudo',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _createRoom,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('CRÉER UNE PARTIE'),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(child: Divider(color: RondaColors.gold.withValues(alpha: 0.3))),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('ou', style: TextStyle(color: RondaColors.creamDark)),
                      ),
                      Expanded(child: Divider(color: RondaColors.gold.withValues(alpha: 0.3))),
                    ],
                  ),
                  const SizedBox(height: 32),

                  TextField(
                    controller: _codeController,
                    maxLength: 5,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      UpperCaseTextFormatter(),
                    ],
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Code de la partie',
                      counterText: '',
                      hintText: 'ABCDE',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _busy ? null : _joinRoom,
                      child: const Text('REJOINDRE'),
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

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
