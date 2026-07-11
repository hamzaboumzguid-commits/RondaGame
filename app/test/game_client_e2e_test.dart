@Tags(['e2e'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_app/models/protocol.dart';
import 'package:ronda_app/net/game_client.dart';

/// E2E complet couche réseau Flutter <-> serveur réel.
/// Nécessite le serveur lancé : `cd server && npm run dev`.
/// Exécution : `flutter test --tags e2e test/game_client_e2e_test.dart`
void main() {
  const url = 'ws://localhost:2567';

  Future<bool> serverUp() async {
    try {
      final socket = await WebSocket.connect(url).timeout(const Duration(seconds: 2));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> waitUntil(bool Function() condition, {String? reason}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timeout: ${reason ?? "condition jamais remplie"}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  test('partie complète : 4 clients, création, lobby, jeu jusqu\'à la victoire', () async {
    if (!await serverUp()) {
      markTestSkipped('Serveur non disponible sur $url — lancer `npm run dev` dans server/.');
      return;
    }

    final host = GameClient();
    final guests = [GameClient(), GameClient(), GameClient()];
    final all = [host, ...guests];

    try {
      // --- Création et jonction ---
      await host.createRoom('Hôte');
      await waitUntil(() => host.roomCode != null, reason: 'code de room jamais reçu');
      final code = host.roomCode!;
      expect(code, matches(RegExp(r'^[A-Z2-9]{5}$')));

      for (final (i, guest) in guests.indexed) {
        await guest.joinRoom(code, 'Invité${i + 1}');
      }
      await waitUntil(
        () => all.every((c) => c.state?.players.length == 4),
        reason: 'les 4 joueurs ne sont pas tous dans le lobby',
      );

      // Équipes auto-assignées par siège : A/B alternées.
      final teams = host.state!.players.map((p) => p.team).toList();
      expect(teams.where((t) => t == 'A').length, 2);
      expect(teams.where((t) => t == 'B').length, 2);

      // --- Lancement ---
      expect(host.isHost, isTrue);
      host.startGame();
      await waitUntil(
        () => all.every((c) => c.state?.phase == 'playing' && c.hand.length == 4),
        reason: 'la partie n\'a pas démarré avec 4 cartes par joueur',
      );

      // --- Jeu automatique jusqu'à la fin ---
      final events = <GameEvent>[];
      for (final c in all) {
        c.events.listen(events.add);
      }

      var safety = 0;
      while (host.state?.phase != 'gameOver' && safety < 3000) {
        safety++;
        final current = all.where((c) => c.isMyTurn).firstOrNull;
        if (current == null || current.hand.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          continue;
        }
        final card = current.hand.first;
        final canCapture =
            current.state!.tablePile.any((c) => c.rank == card.rank);
        current.playCard(card.id, capture: canCapture);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(host.state?.phase, 'gameOver',
          reason: 'la partie devrait se terminer (safety=$safety)');
      final winner = host.state!.winningTeam;
      expect(winner == 'A' || winner == 'B', isTrue);
      expect(host.state!.scores[winner]!, greaterThanOrEqualTo(41));

      // Les événements de fin de manche ont bien circulé jusqu'aux clients.
      expect(events.whereType<SubRoundRevealEvent>(), isNotEmpty);
      expect(events.whereType<GameOverEvent>(), isNotEmpty);
    } finally {
      for (final c in all) {
        c.dispose();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
