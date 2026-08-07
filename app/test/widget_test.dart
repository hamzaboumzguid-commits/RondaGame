import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ronda_app/main.dart';
import 'package:ronda_app/net/game_client.dart';

void main() {
  testWidgets("L'accueil affiche les actions principales", (tester) async {
    await tester.pumpWidget(const RondaApp());

    // Le logo RONDA fait partie de l'illustration de fond (asset généré),
    // on vérifie donc les actions et les champs, pas le titre.
    expect(find.text('CRÉER UNE PARTIE'), findsOneWidget);
    expect(find.text('REJOINDRE'), findsOneWidget);
    expect(find.text('TON PSEUDO'), findsOneWidget);

    // L'accueil déclenche une tentative de connexion WebSocket réelle dès le
    // premier frame (liste des salons publics). On démonte l'arbre pour annuler
    // le Timer.periodic, puis on laisse s'écouler le timeout de connexion
    // (GameClient.kConnectTimeout) : sans ça son timer interne serait encore
    // pendant à la fin du test.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(GameClient.kConnectTimeout + const Duration(seconds: 1));
  });
}
