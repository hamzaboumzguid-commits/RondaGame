import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'ads/consent_manager.dart';
import 'l10n/app_strings.dart';
import 'net/game_client.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Jeu pensé pour le portrait uniquement en v1.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  // Consentement RGPD/UMP puis initialisation des pubs. Volontairement non
  // attendu : le formulaire de consentement (EEE) et l'init AdMob ne doivent
  // jamais retarder l'affichage de l'accueil. catchError en filet de sécurité :
  // aucune erreur de ce flux ne doit remonter en exception non capturée.
  unawaited(ConsentManager.gatherConsentThenInitAds().catchError((_) {}));
  runApp(const RondaApp());
}

class RondaApp extends StatelessWidget {
  const RondaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameClient()),
        ChangeNotifierProvider(create: (_) => AppStrings()),
      ],
      child: MaterialApp(
        title: 'Ronda',
        debugShowCheckedModeBanner: false,
        theme: buildRondaTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
