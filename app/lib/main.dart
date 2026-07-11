import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'net/game_client.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Jeu pensé pour le portrait uniquement en v1.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const RondaApp());
}

class RondaApp extends StatelessWidget {
  const RondaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameClient(),
      child: MaterialApp(
        title: 'Ronda',
        debugShowCheckedModeBanner: false,
        theme: buildRondaTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
