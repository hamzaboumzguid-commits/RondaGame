import 'package:flutter/material.dart';

import '../models/protocol.dart';
import '../theme.dart';

/// Couleur emblématique de chaque enseigne espagnole.
Color suitColor(String suit) {
  switch (suit) {
    case 'oros':
      return const Color(0xFFB8860B); // or
    case 'copas':
      return const Color(0xFF9A2A2A); // rouge coupe
    case 'espadas':
      return const Color(0xFF2C5F8A); // acier bleu
    case 'bastos':
      return const Color(0xFF4E6B2E); // bois vert
    default:
      return Colors.grey;
  }
}

/// Carte espagnole stylisée, dessinée procéduralement (aucun asset image).
class PlayingCardWidget extends StatelessWidget {
  final GameCard card;
  final double width;
  final bool selected;
  final VoidCallback? onTap;

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.width = 64,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * 1.45;
    final color = suitColor(card.suit);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: width,
        height: height,
        transform: Matrix4.translationValues(0, selected ? -14 : 0, 0),
        decoration: BoxDecoration(
          color: RondaColors.cream,
          borderRadius: BorderRadius.circular(width * 0.12),
          border: Border.all(
            color: selected ? RondaColors.gold : RondaColors.creamDark,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.5 : 0.3),
              blurRadius: selected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _rankShort(card.rank),
              style: TextStyle(
                color: color,
                fontSize: width * 0.34,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            SizedBox(height: width * 0.08),
            CustomPaint(
              size: Size(width * 0.42, width * 0.42),
              painter: SuitPainter(card.suit, color),
            ),
          ],
        ),
      ),
    );
  }

  String _rankShort(int rank) {
    switch (rank) {
      case 1:
        return 'A';
      case 10:
        return 'V';
      case 11:
        return 'C';
      case 12:
        return 'R';
      default:
        return '$rank';
    }
  }
}

/// Dos de carte : motif zellige doré sur fond rouge profond.
class CardBackWidget extends StatelessWidget {
  final double width;

  const CardBackWidget({super.key, this.width = 64});

  @override
  Widget build(BuildContext context) {
    final height = width * 1.45;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: RondaColors.redDeep,
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(color: RondaColors.gold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(width * 0.5, width * 0.5),
          painter: _StarPainter(RondaColors.gold.withValues(alpha: 0.7)),
        ),
      ),
    );
  }
}

/// Symboles des quatre enseignes espagnoles, en vectoriel simple.
class SuitPainter extends CustomPainter {
  final String suit;
  final Color color;

  SuitPainter(this.suit, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    switch (suit) {
      case 'oros': // denier : pièce d'or cerclée
        canvas.drawCircle(center, w * 0.38, paint);
        canvas.drawCircle(
          center,
          w * 0.26,
          Paint()
            ..color = RondaColors.cream
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.06,
        );
      case 'copas': // coupe : calice
        final cup = Path()
          ..moveTo(w * 0.18, h * 0.12)
          ..quadraticBezierTo(w * 0.20, h * 0.55, w * 0.5, h * 0.58)
          ..quadraticBezierTo(w * 0.80, h * 0.55, w * 0.82, h * 0.12)
          ..close();
        canvas.drawPath(cup, paint);
        canvas.drawLine(Offset(w * 0.5, h * 0.58), Offset(w * 0.5, h * 0.82), stroke);
        canvas.drawLine(Offset(w * 0.3, h * 0.9), Offset(w * 0.7, h * 0.9), stroke);
      case 'espadas': // épée : lame et garde
        canvas.drawLine(Offset(w * 0.5, h * 0.05), Offset(w * 0.5, h * 0.75), stroke);
        canvas.drawLine(Offset(w * 0.28, h * 0.62), Offset(w * 0.72, h * 0.62), stroke);
        final blade = Path()
          ..moveTo(w * 0.5, h * 0.02)
          ..lineTo(w * 0.42, h * 0.18)
          ..lineTo(w * 0.58, h * 0.18)
          ..close();
        canvas.drawPath(blade, paint);
        canvas.drawCircle(Offset(w * 0.5, h * 0.88), w * 0.09, paint);
      case 'bastos': // bâton : gourdin
        final club = Path()
          ..moveTo(w * 0.40, h * 0.10)
          ..quadraticBezierTo(w * 0.28, h * 0.16, w * 0.36, h * 0.32)
          ..lineTo(w * 0.46, h * 0.88)
          ..quadraticBezierTo(w * 0.5, h * 0.95, w * 0.56, h * 0.88)
          ..lineTo(w * 0.62, h * 0.30)
          ..quadraticBezierTo(w * 0.68, h * 0.14, w * 0.56, h * 0.09)
          ..close();
        canvas.drawPath(club, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SuitPainter oldDelegate) =>
      oldDelegate.suit != suit || oldDelegate.color != color;
}

class _StarPainter extends CustomPainter {
  final Color color;
  _StarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.48;
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
  bool shouldRepaint(covariant _StarPainter oldDelegate) => oldDelegate.color != color;
}
