import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../theme.dart';
import '../widgets/chunky_button.dart';

/// Rappel des règles du jeu (GDD.md section 2), accessible depuis un bouton
/// dans les Paramètres.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppStrings>();

    return Scaffold(
      body: IllustratedBackground(
        asset: 'assets/ui/home_bg.png',
        dim: 0.35,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Text(
                      strings.t('settings.rules'),
                      style: const TextStyle(
                        color: RondaColors.cream,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 42),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView(
                    children: [
                      ChunkyPanel(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                        child: const _RulesBody(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Résumé des règles (GDD.md §2) — même contenu dans les deux langues :
/// c'est une référence de jeu, pas un texte d'ambiance, donc pas traduit.
class _RulesBody extends StatelessWidget {
  const _RulesBody();

  static const _sections = [
    (
      'Objectif',
      "4 joueurs, 2 équipes de 2. Jeu espagnol de 40 cartes (As à Roi, sans 8/9). "
          "Première équipe à atteindre 41 points gagne, même en plein milieu d'un TER7.",
    ),
    (
      'Distribution',
      "3 TFRI9A par TER7 (manche) : 4 cartes/joueur, puis 3, puis 3 — 40 cartes au total. "
          "Chaque TFRI9A a son propre cycle annonce → jeu → révélation.",
    ),
    (
      'Capturer',
      "Une carte capture sa jumelle sur la table — c'est obligatoire dès que possible. "
          "La capture emporte aussi toute la suite ascendante présente sur la table "
          "(ex: table 5-6-7, poser un 5 prend tout). Sans capture possible, la carte est "
          "simplement posée.",
    ),
    (
      'DERBA',
      "Capturer immédiatement la carte que l'adversaire vient de poser. Barème avec "
          "surenchère (seule la dernière compte) : DERBA = 1 pt, 7BIYEL = 5 pts, "
          "JOUJ 7BOULA = 10 pts max. Toute autre action rompt la chaîne.",
    ),
    (
      'MISSA',
      "Vider complètement la table lors d'une capture rapporte 1 point, cumulable "
          "avec une DERBA sur la même capture.",
    ),
    (
      'RONDA / TRINGA',
      "2 cartes de même valeur en main = RONDA, 3 cartes = TRINGA. Révélées en fin de "
          "TFRI9A. 1 RONDA seule = 1 pt. Plusieurs RONDA : la plus forte gagne (égalité "
          "= personne ne marque). 4 RONDA : la plus petite gagne. Une TRINGA bat toujours "
          "une RONDA (5 pts, +1 si elle bat une RONDA).",
    ),
    (
      'Butin final',
      "En fin de TER7, l'équipe qui a capturé plus de 20 cartes marque (cartes − 20) "
          "points. Les cartes restantes sur la table vont à la dernière équipe ayant capturé.",
    ),
    (
      'Dernière carte',
      "Si le tout dernier coup du TER7 capture avec un Roi → +5 pts. Avec un As → +5 pts "
          "pour l'équipe adverse (MAJEBTICH 9A3TEK si ce n'est pas le Lead qui conclut).",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (title, body) in _sections) ...[
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: Color(0xFF4A2E15),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF6B4A26),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
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
