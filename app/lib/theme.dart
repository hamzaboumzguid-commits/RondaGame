import 'package:flutter/material.dart';

/// Palette « café marocain » : rouge profond des tapis, vert zellige,
/// or des cuivres, brun des tables en bois (GDD 3.3).
abstract final class RondaColors {
  static const Color red = Color(0xFF9A2A2A);
  static const Color redDeep = Color(0xFF6E1C1C);
  static const Color green = Color(0xFF1F6E43);
  static const Color greenDeep = Color(0xFF14432B);
  static const Color gold = Color(0xFFD4A937);
  static const Color goldLight = Color(0xFFEBC96B);
  static const Color wood = Color(0xFF2B1A12);
  static const Color woodLight = Color(0xFF4A2E1D);
  static const Color cream = Color(0xFFF5EBD8);
  static const Color creamDark = Color(0xFFE3D4B8);

  /// Couleur d'équipe : A = rouge, B = vert.
  static Color team(String team) => team == 'A' ? red : green;
  static Color teamLight(String team) =>
      team == 'A' ? const Color(0xFFC75B5B) : const Color(0xFF4E9E73);
}

ThemeData buildRondaTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: RondaColors.red,
      brightness: Brightness.dark,
      primary: RondaColors.gold,
      secondary: RondaColors.green,
      surface: RondaColors.wood,
    ),
    scaffoldBackgroundColor: RondaColors.wood,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: RondaColors.cream,
      displayColor: RondaColors.cream,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: RondaColors.gold,
        foregroundColor: RondaColors.wood,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RondaColors.goldLight,
        side: const BorderSide(color: RondaColors.gold, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RondaColors.woodLight.withValues(alpha: 0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: RondaColors.gold),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: RondaColors.gold.withValues(alpha: 0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: RondaColors.gold, width: 2),
      ),
      labelStyle: const TextStyle(color: RondaColors.creamDark),
      hintStyle: TextStyle(color: RondaColors.creamDark.withValues(alpha: 0.5)),
    ),
  );
}

/// Fond zellige : étoiles à huit branches en quadrillage discret,
/// peint procéduralement (aucun asset nécessaire).
class ZelligeBackground extends StatelessWidget {
  final Widget child;
  final Color baseColor;
  final Color patternColor;

  const ZelligeBackground({
    super.key,
    required this.child,
    this.baseColor = RondaColors.wood,
    this.patternColor = RondaColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: baseColor),
      child: CustomPaint(
        painter: _ZelligePainter(patternColor),
        child: child,
      ),
    );
  }
}

class _ZelligePainter extends CustomPainter {
  final Color color;
  _ZelligePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const cell = 72.0;
    for (double x = 0; x < size.width + cell; x += cell) {
      for (double y = 0; y < size.height + cell; y += cell) {
        _drawStar(canvas, Offset(x, y), cell * 0.36, paint);
      }
    }
  }

  /// Étoile à huit branches (motif zellige classique) : deux carrés superposés
  /// tournés de 45 degrés.
  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    for (final angleOffset in [0.0, 0.785398]) {
      final path = Path();
      for (int i = 0; i < 4; i++) {
        final angle = angleOffset + i * 1.570796;
        final point = center + Offset.fromDirection(angle, radius);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ZelligePainter oldDelegate) => oldDelegate.color != color;
}
