import 'package:flutter_test/flutter_test.dart';

import 'package:ronda_app/main.dart';

void main() {
  testWidgets("L'accueil affiche le titre et les actions principales", (tester) async {
    await tester.pumpWidget(const RondaApp());

    expect(find.text('RONDA'), findsOneWidget);
    expect(find.text('CRÉER UNE PARTIE'), findsOneWidget);
    expect(find.text('REJOINDRE'), findsOneWidget);
  });
}
