import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ronda_app/main.dart';

void main() {
  testWidgets("L'accueil affiche les actions principales", (tester) async {
    await tester.pumpWidget(const RondaApp());

    // Le logo RONDA fait partie de l'illustration de fond (asset généré),
    // on vérifie donc les actions et les champs, pas le titre.
    expect(find.text('CRÉER UNE PARTIE'), findsOneWidget);
    expect(find.text('REJOINDRE'), findsOneWidget);
    expect(find.text('TON PSEUDO'), findsOneWidget);

    // L'accueil déclenche une tentative de connexion WebSocket réelle dès le
    // premier frame (liste des salons publics) ; on laisse le socket échouer
    // proprement puis on démonte l'arbre pour annuler le Timer.periodic associé.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
