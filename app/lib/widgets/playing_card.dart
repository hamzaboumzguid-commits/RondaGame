import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/protocol.dart';
import '../theme.dart';

/// Couleur emblématique de chaque enseigne espagnole.
Color suitColor(String suit) {
  switch (suit) {
    case 'oros':
      return const Color(0xFFC9971B); // or
    case 'copas':
      return const Color(0xFFB3262A); // rouge coupe
    case 'espadas':
      return const Color(0xFF2D5E93); // acier bleu
    case 'bastos':
      return const Color(0xFF3E7A34); // bois vert
    default:
      return Colors.grey;
  }
}

Color _suitDark(String suit) {
  switch (suit) {
    case 'oros':
      return const Color(0xFF8A6410);
    case 'copas':
      return const Color(0xFF7C181B);
    case 'espadas':
      return const Color(0xFF1C3D63);
    case 'bastos':
      return const Color(0xFF285222);
    default:
      return Colors.black54;
  }
}

/// Nombre de coupures de la « pinta » (les traits interrompus en haut et en bas
/// d'une vraie carte espagnole) : oros = 0, copas = 1, espadas = 2, bastos = 3.
int _pintaBreaks(String suit) {
  switch (suit) {
    case 'copas':
      return 1;
    case 'espadas':
      return 2;
    case 'bastos':
      return 3;
    default:
      return 0;
  }
}

/// Carte espagnole (baraja española) dessinée procéduralement : pinta,
/// indices en coin, symboles répétés selon la valeur, figures pour 10/11/12.
class PlayingCardWidget extends StatelessWidget {
  final GameCard card;
  final double width;
  final bool selected;
  final VoidCallback? onTap;
  /// Inclinaison en radians (cartes en éventail / éparpillées sur la table).
  final double angle;

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.width = 64,
    this.selected = false,
    this.onTap,
    this.angle = 0,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * 1.5;

    Widget face = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFDF4), Color(0xFFF3E9CF)],
        ),
        borderRadius: BorderRadius.circular(width * 0.11),
        border: Border.all(
          color: selected ? RondaColors.gold : const Color(0xFFC9BA97),
          width: selected ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? RondaColors.gold.withValues(alpha: 0.55)
                : Colors.black.withValues(alpha: 0.35),
            blurRadius: selected ? 14 : 5,
            offset: Offset(0, selected ? 4 : 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.10),
        child: CustomPaint(
          size: Size(width, height),
          painter: SpanishCardPainter(card),
        ),
      ),
    );

    if (angle != 0) {
      face = Transform.rotate(angle: angle, child: face);
    }

    if (onTap == null) return face;
    return GestureDetector(onTap: onTap, child: face);
  }
}

/// Peint l'intégralité de la face d'une carte espagnole.
class SpanishCardPainter extends CustomPainter {
  final GameCard card;

  SpanishCardPainter(this.card);

  @override
  void paint(Canvas canvas, Size size) {
    final color = suitColor(card.suit);
    final dark = _suitDark(card.suit);
    final w = size.width;
    final h = size.height;

    _drawPintaFrame(canvas, size, dark);
    _drawCornerIndex(canvas, size, color, dark, topLeft: true);
    _drawCornerIndex(canvas, size, color, dark, topLeft: false);

    // Zone centrale pour les symboles ou la figure.
    final content = Rect.fromLTRB(w * 0.20, h * 0.15, w * 0.80, h * 0.87);

    if (card.rank <= 7) {
      _drawPips(canvas, content, w);
    } else {
      _drawFigure(canvas, content, w, color, dark);
    }
  }

  /// Cadre intérieur avec la pinta : les segments horizontaux hauts et bas
  /// sont interrompus selon l'enseigne (0 à 3 coupures).
  void _drawPintaFrame(Canvas canvas, Size size, Color dark) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = dark.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.018);

    final left = w * 0.07;
    final right = w * 0.93;
    final top = h * 0.045;
    final bottom = h * 0.955;

    // Montants verticaux continus.
    canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);
    canvas.drawLine(Offset(right, top), Offset(right, bottom), paint);

    // Traverses horizontales avec coupures (la pinta).
    final breaks = _pintaBreaks(card.suit);
    for (final y in [top, bottom]) {
      final span = right - left;
      final segments = breaks + 1;
      final gap = w * 0.055;
      final segWidth = (span - breaks * gap) / segments;
      var x = left;
      for (var i = 0; i < segments; i++) {
        canvas.drawLine(Offset(x, y), Offset(x + segWidth, y), paint);
        x += segWidth + gap;
      }
    }
  }

  void _drawCornerIndex(Canvas canvas, Size size, Color color, Color dark,
      {required bool topLeft}) {
    final w = size.width;
    final h = size.height;

    canvas.save();
    if (!topLeft) {
      canvas.translate(w, h);
      canvas.rotate(math.pi);
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${card.rank}',
        style: TextStyle(
          // Chiffres noirs quelle que soit l'enseigne, comme sur le vrai jeu marocain.
          color: const Color(0xFF211C15),
          fontSize: w * 0.17,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(w * 0.095, h * 0.065));

    _drawSuitSymbol(
      canvas,
      Offset(w * 0.145 + (card.rank >= 10 ? w * 0.035 : 0), h * 0.065 + w * 0.17 + w * 0.075),
      w * 0.115,
      card.suit,
    );

    canvas.restore();
  }

  /// Dispositions traditionnelles des symboles selon la valeur (1 à 7).
  void _drawPips(Canvas canvas, Rect content, double cardWidth) {
    const layouts = <int, List<Offset>>{
      1: [Offset(0.5, 0.5)],
      2: [Offset(0.5, 0.26), Offset(0.5, 0.74)],
      3: [Offset(0.5, 0.18), Offset(0.5, 0.5), Offset(0.5, 0.82)],
      4: [Offset(0.3, 0.25), Offset(0.7, 0.25), Offset(0.3, 0.75), Offset(0.7, 0.75)],
      5: [
        Offset(0.28, 0.22),
        Offset(0.72, 0.22),
        Offset(0.5, 0.5),
        Offset(0.28, 0.78),
        Offset(0.72, 0.78),
      ],
      6: [
        Offset(0.3, 0.18),
        Offset(0.7, 0.18),
        Offset(0.3, 0.5),
        Offset(0.7, 0.5),
        Offset(0.3, 0.82),
        Offset(0.7, 0.82),
      ],
      7: [
        Offset(0.3, 0.16),
        Offset(0.7, 0.16),
        Offset(0.5, 0.37),
        Offset(0.3, 0.58),
        Offset(0.7, 0.58),
        Offset(0.3, 0.84),
        Offset(0.7, 0.84),
      ],
    };

    final positions = layouts[card.rank]!;
    // L'as est un grand symbole unique, façon « As de Oros ».
    final pipSize = card.rank == 1 ? cardWidth * 0.44 : cardWidth * 0.20;

    for (final (i, rel) in positions.indexed) {
      final center = Offset(
        content.left + rel.dx * content.width,
        content.top + rel.dy * content.height,
      );
      _drawSuitSymbol(canvas, center, pipSize, card.suit, variant: i);
    }
  }

  // ---- Symboles d'enseigne ----

  void _drawSuitSymbol(Canvas canvas, Offset center, double s, String suit, {int variant = 0}) {
    switch (suit) {
      case 'oros':
        _drawCoin(canvas, center, s);
      case 'copas':
        _drawCup(canvas, center, s);
      case 'espadas':
        _drawSword(canvas, center, s);
      case 'bastos':
        _drawClub(canvas, center, s, variant: variant);
    }
  }

  /// Denier façon jeu marocain : soleil-rosace jaune à pétales, cœur détaillé.
  void _drawCoin(Canvas canvas, Offset c, double s) {
    final r = s * 0.5;
    final outline = Paint()
      ..color = const Color(0xFF211C15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, s * 0.04);

    // Disque jaune.
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFF2C230));
    canvas.drawCircle(c, r, outline);

    // Couronne de pétales (rayons de soleil) autour du cœur.
    const petals = 12;
    for (var i = 0; i < petals; i++) {
      final angle = i * 2 * math.pi / petals;
      canvas.drawLine(
        c + Offset.fromDirection(angle, r * 0.55),
        c + Offset.fromDirection(angle, r * 0.88),
        outline,
      );
    }
    // Cœur de la rosace.
    canvas.drawCircle(c, r * 0.50, outline);
    canvas.drawCircle(c, r * 0.30, Paint()..color = const Color(0xFFD03A30));
    canvas.drawCircle(c, r * 0.30, outline);
  }

  /// Coupe façon jeu marocain (Litho Cartes) : pot jaune trapu à couvercle
  /// rouge festonné, bande bleue et pied rouge.
  void _drawCup(Canvas canvas, Offset c, double s) {
    final rect = Rect.fromCenter(center: c, width: s, height: s);
    final w = rect.width;
    final h = rect.height;
    final left = rect.left;
    final top = rect.top;

    final red = Paint()..color = const Color(0xFFD03A30);
    final yellow = Paint()..color = const Color(0xFFF2C230);
    final blue = Paint()..color = const Color(0xFF2D6FBF);
    final outline = Paint()
      ..color = const Color(0xFF211C15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, s * 0.035);

    // Couvercle rouge festonné (arcs en accolade).
    final lid = Path()..moveTo(left + w * 0.14, top + h * 0.30);
    const scallops = 3;
    for (var i = 0; i < scallops; i++) {
      final x0 = 0.14 + (0.72 / scallops) * i;
      final x1 = 0.14 + (0.72 / scallops) * (i + 1);
      lid.quadraticBezierTo(
        left + w * (x0 + x1) / 2,
        top + h * 0.02,
        left + w * x1,
        top + h * 0.30,
      );
    }
    lid.close();
    canvas.drawPath(lid, red);
    canvas.drawPath(lid, outline);

    // Corps jaune arrondi.
    final body = Path()
      ..moveTo(left + w * 0.18, top + h * 0.32)
      ..lineTo(left + w * 0.82, top + h * 0.32)
      ..quadraticBezierTo(left + w * 0.86, top + h * 0.62, left + w * 0.64, top + h * 0.72)
      ..lineTo(left + w * 0.36, top + h * 0.72)
      ..quadraticBezierTo(left + w * 0.14, top + h * 0.62, left + w * 0.18, top + h * 0.32)
      ..close();
    canvas.drawPath(body, yellow);
    canvas.drawPath(body, outline);
    // Bande bleue centrale.
    canvas.drawRect(Rect.fromLTWH(left + w * 0.20, top + h * 0.44, w * 0.60, h * 0.10), blue);

    // Pied rouge évasé.
    final foot = Path()
      ..moveTo(left + w * 0.38, top + h * 0.72)
      ..lineTo(left + w * 0.62, top + h * 0.72)
      ..lineTo(left + w * 0.72, top + h * 0.94)
      ..lineTo(left + w * 0.28, top + h * 0.94)
      ..close();
    canvas.drawPath(foot, red);
    canvas.drawPath(foot, outline);
  }

  /// Épée : lame effilée à arête centrale, garde dorée incurvée, poignée rouge.
  void _drawSword(Canvas canvas, Offset c, double s) {
    final rect = Rect.fromCenter(center: c, width: s, height: s);
    final w = rect.width;
    final h = rect.height;
    final left = rect.left;
    final top = rect.top;

    // Lame bleu vif à garde jaune et poignée rouge, comme le jeu marocain.
    final blade = Paint()..color = const Color(0xFF2D6FBF);
    final bladeEdge = Paint()
      ..color = const Color(0xFF211C15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, s * 0.035);
    final gold = Paint()
      ..color = const Color(0xFFF2C230)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.9, s * 0.09)
      ..strokeCap = StrokeCap.round;

    // Lame (pointe en haut).
    final bladePath = Path()
      ..moveTo(left + w * 0.5, top)
      ..lineTo(left + w * 0.58, top + h * 0.14)
      ..lineTo(left + w * 0.56, top + h * 0.62)
      ..lineTo(left + w * 0.44, top + h * 0.62)
      ..lineTo(left + w * 0.42, top + h * 0.14)
      ..close();
    canvas.drawPath(bladePath, blade);
    canvas.drawPath(bladePath, bladeEdge);
    // Arête centrale.
    canvas.drawLine(
      Offset(left + w * 0.5, top + h * 0.04),
      Offset(left + w * 0.5, top + h * 0.58),
      bladeEdge,
    );
    // Garde incurvée.
    final guard = Path()
      ..moveTo(left + w * 0.16, top + h * 0.56)
      ..quadraticBezierTo(left + w * 0.5, top + h * 0.72, left + w * 0.84, top + h * 0.56);
    canvas.drawPath(guard, gold);
    // Poignée et pommeau.
    canvas.drawLine(
      Offset(left + w * 0.5, top + h * 0.66),
      Offset(left + w * 0.5, top + h * 0.86),
      Paint()
        ..color = const Color(0xFF9A2A2A)
        ..strokeWidth = math.max(1.0, s * 0.11)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(left + w * 0.5, top + h * 0.92),
      s * 0.08,
      Paint()..color = const Color(0xFFF2C230),
    );
  }

  /// Bâton façon jeu marocain : gourdin rouge ou bleu (alterné) à nœuds jaunes.
  void _drawClub(Canvas canvas, Offset c, double s, {int variant = 0}) {
    final rect = Rect.fromCenter(center: c, width: s, height: s);
    final w = rect.width;
    final h = rect.height;
    final left = rect.left;
    final top = rect.top;

    final wood = Paint()
      ..color = variant.isEven ? const Color(0xFFD03A30) : const Color(0xFF2D6FBF);
    final woodDark = Paint()
      ..color = const Color(0xFF211C15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, s * 0.04);
    final knot = Paint()..color = const Color(0xFFF2C230);

    // Massue : tête large qui s'affine vers le bas.
    final club = Path()
      ..moveTo(left + w * 0.38, top + h * 0.06)
      ..quadraticBezierTo(left + w * 0.16, top + h * 0.14, left + w * 0.30, top + h * 0.34)
      ..quadraticBezierTo(left + w * 0.36, top + h * 0.44, left + w * 0.42, top + h * 0.60)
      ..lineTo(left + w * 0.46, top + h * 0.92)
      ..quadraticBezierTo(left + w * 0.5, top + h * 0.98, left + w * 0.56, top + h * 0.92)
      ..lineTo(left + w * 0.58, top + h * 0.58)
      ..quadraticBezierTo(left + w * 0.66, top + h * 0.36, left + w * 0.70, top + h * 0.26)
      ..quadraticBezierTo(left + w * 0.78, top + h * 0.08, left + w * 0.56, top + h * 0.04)
      ..quadraticBezierTo(left + w * 0.46, top + h * 0.02, left + w * 0.38, top + h * 0.06)
      ..close();
    canvas.drawPath(club, wood);
    canvas.drawPath(club, woodDark);
    // Nœuds jaunes cerclés, signature du jeu marocain.
    for (final knotPos in [Offset(0.42, 0.20), Offset(0.58, 0.38), Offset(0.50, 0.62)]) {
      final p = Offset(left + w * knotPos.dx, top + h * knotPos.dy);
      canvas.drawCircle(p, s * 0.055, knot);
      canvas.drawCircle(p, s * 0.055, woodDark);
    }
  }

  // ---- Figures (10 Sota, 11 Caballo, 12 Rey) ----

  void _drawFigure(Canvas canvas, Rect content, double cardWidth, Color color, Color dark) {
    // Cadre orné de la figure, comme sur les vraies cartes.
    final framePaint = Paint()
      ..color = dark.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, cardWidth * 0.015);
    final frame = RRect.fromRectAndRadius(
      content.inflate(cardWidth * 0.02),
      Radius.circular(cardWidth * 0.04),
    );
    canvas.drawRRect(frame, framePaint);

    switch (card.rank) {
      case 10:
        _drawSota(canvas, content, color, dark);
      case 11:
        _drawCaballo(canvas, content, color, dark);
      case 12:
        _drawRey(canvas, content, color, dark);
    }

    // Petit symbole d'enseigne en haut du cadre, comme sur la baraja.
    _drawSuitSymbol(
      canvas,
      Offset(content.center.dx, content.top + content.height * 0.08),
      cardWidth * 0.13,
      card.suit,
    );
  }

  /// Valet (Sota) : page debout tenant un bâton, tunique aux couleurs de l'enseigne.
  void _drawSota(Canvas canvas, Rect r, Color color, Color dark) {
    final w = r.width;
    final h = r.height;
    final left = r.left;
    final top = r.top;
    final outline = Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, w * 0.03);
    final skin = Paint()..color = const Color(0xFFE8C39E);
    final tunic = Paint()..color = color;
    final gold = Paint()..color = const Color(0xFFC9971B);

    // Jambes (collants).
    final legs = Paint()
      ..color = dark.withValues(alpha: 0.8)
      ..strokeWidth = math.max(1.5, w * 0.07)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left + w * 0.42, top + h * 0.68), Offset(left + w * 0.38, top + h * 0.92), legs);
    canvas.drawLine(Offset(left + w * 0.56, top + h * 0.68), Offset(left + w * 0.60, top + h * 0.92), legs);

    // Tunique évasée.
    final body = Path()
      ..moveTo(left + w * 0.36, top + h * 0.38)
      ..lineTo(left + w * 0.62, top + h * 0.38)
      ..lineTo(left + w * 0.68, top + h * 0.70)
      ..lineTo(left + w * 0.30, top + h * 0.70)
      ..close();
    canvas.drawPath(body, tunic);
    canvas.drawPath(body, outline);
    // Ceinture dorée.
    canvas.drawRect(Rect.fromLTWH(left + w * 0.32, top + h * 0.54, w * 0.34, h * 0.035), gold);

    // Tête avec toque à plume.
    canvas.drawCircle(Offset(left + w * 0.49, top + h * 0.28), w * 0.085, skin);
    canvas.drawCircle(Offset(left + w * 0.49, top + h * 0.28), w * 0.085, outline);
    final cap = Path()
      ..moveTo(left + w * 0.39, top + h * 0.24)
      ..quadraticBezierTo(left + w * 0.49, top + h * 0.14, left + w * 0.60, top + h * 0.23)
      ..quadraticBezierTo(left + w * 0.50, top + h * 0.20, left + w * 0.39, top + h * 0.24)
      ..close();
    canvas.drawPath(cap, tunic);
    canvas.drawPath(cap, outline);
    // Plume.
    canvas.drawLine(
      Offset(left + w * 0.58, top + h * 0.20),
      Offset(left + w * 0.68, top + h * 0.12),
      outline,
    );

    // Bâton tenu à main droite.
    canvas.drawLine(
      Offset(left + w * 0.76, top + h * 0.22),
      Offset(left + w * 0.76, top + h * 0.78),
      Paint()
        ..color = dark
        ..strokeWidth = math.max(1.2, w * 0.045)
        ..strokeCap = StrokeCap.round,
    );
    // Bras vers le bâton.
    canvas.drawLine(
      Offset(left + w * 0.60, top + h * 0.45),
      Offset(left + w * 0.76, top + h * 0.40),
      Paint()
        ..color = color
        ..strokeWidth = math.max(1.5, w * 0.06)
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Cavalier (Caballo) : cheval de profil avec cavalier.
  void _drawCaballo(Canvas canvas, Rect r, Color color, Color dark) {
    final w = r.width;
    final h = r.height;
    final left = r.left;
    final top = r.top;
    final outline = Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, w * 0.03);
    final horse = Paint()..color = const Color(0xFFB48A5A);
    final rider = Paint()..color = color;
    final skin = Paint()..color = const Color(0xFFE8C39E);

    // Corps du cheval.
    final body = Path()
      ..moveTo(left + w * 0.20, top + h * 0.58)
      ..quadraticBezierTo(left + w * 0.30, top + h * 0.48, left + w * 0.55, top + h * 0.50)
      ..quadraticBezierTo(left + w * 0.72, top + h * 0.52, left + w * 0.74, top + h * 0.62)
      ..quadraticBezierTo(left + w * 0.72, top + h * 0.72, left + w * 0.55, top + h * 0.72)
      ..quadraticBezierTo(left + w * 0.32, top + h * 0.74, left + w * 0.20, top + h * 0.58)
      ..close();
    canvas.drawPath(body, horse);
    canvas.drawPath(body, outline);

    // Encolure et tête.
    final neck = Path()
      ..moveTo(left + w * 0.62, top + h * 0.52)
      ..quadraticBezierTo(left + w * 0.74, top + h * 0.40, left + w * 0.76, top + h * 0.32)
      ..lineTo(left + w * 0.88, top + h * 0.38)
      ..quadraticBezierTo(left + w * 0.86, top + h * 0.46, left + w * 0.74, top + h * 0.56)
      ..close();
    canvas.drawPath(neck, horse);
    canvas.drawPath(neck, outline);
    // Oreille et œil.
    canvas.drawLine(Offset(left + w * 0.78, top + h * 0.30), Offset(left + w * 0.80, top + h * 0.24), outline);
    canvas.drawCircle(Offset(left + w * 0.80, top + h * 0.35), w * 0.015, Paint()..color = dark);

    // Pattes.
    final legPaint = Paint()
      ..color = const Color(0xFF8A6440)
      ..strokeWidth = math.max(1.2, w * 0.045)
      ..strokeCap = StrokeCap.round;
    for (final x in [0.28, 0.38, 0.58, 0.68]) {
      canvas.drawLine(
        Offset(left + w * x, top + h * 0.70),
        Offset(left + w * (x - 0.02), top + h * 0.92),
        legPaint,
      );
    }
    // Queue.
    canvas.drawLine(Offset(left + w * 0.20, top + h * 0.58), Offset(left + w * 0.10, top + h * 0.72), outline);

    // Cavalier : buste + tête au-dessus du dos.
    final torso = Path()
      ..moveTo(left + w * 0.38, top + h * 0.50)
      ..lineTo(left + w * 0.52, top + h * 0.50)
      ..lineTo(left + w * 0.50, top + h * 0.30)
      ..lineTo(left + w * 0.40, top + h * 0.30)
      ..close();
    canvas.drawPath(torso, rider);
    canvas.drawPath(torso, outline);
    canvas.drawCircle(Offset(left + w * 0.45, top + h * 0.23), w * 0.065, skin);
    canvas.drawCircle(Offset(left + w * 0.45, top + h * 0.23), w * 0.065, outline);
    // Lance du cavalier.
    canvas.drawLine(
      Offset(left + w * 0.30, top + h * 0.14),
      Offset(left + w * 0.52, top + h * 0.44),
      Paint()
        ..color = dark
        ..strokeWidth = math.max(1.0, w * 0.035)
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Roi (Rey) : buste couronné en robe, tenant le symbole de son enseigne.
  void _drawRey(Canvas canvas, Rect r, Color color, Color dark) {
    final w = r.width;
    final h = r.height;
    final left = r.left;
    final top = r.top;
    final outline = Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, w * 0.03);
    final robe = Paint()..color = color;
    final skin = Paint()..color = const Color(0xFFE8C39E);
    final gold = Paint()..color = const Color(0xFFC9971B);

    // Robe ample.
    final body = Path()
      ..moveTo(left + w * 0.34, top + h * 0.42)
      ..lineTo(left + w * 0.64, top + h * 0.42)
      ..lineTo(left + w * 0.76, top + h * 0.92)
      ..lineTo(left + w * 0.22, top + h * 0.92)
      ..close();
    canvas.drawPath(body, robe);
    canvas.drawPath(body, outline);
    // Liserés dorés de la robe.
    canvas.drawLine(Offset(left + w * 0.30, top + h * 0.66), Offset(left + w * 0.68, top + h * 0.66),
        Paint()..color = const Color(0xFFC9971B)..strokeWidth = math.max(1.0, w * 0.03));

    // Col d'hermine.
    canvas.drawRect(Rect.fromLTWH(left + w * 0.36, top + h * 0.40, w * 0.26, h * 0.045),
        Paint()..color = const Color(0xFFF5EBD8));

    // Tête barbue.
    canvas.drawCircle(Offset(left + w * 0.49, top + h * 0.30), w * 0.095, skin);
    canvas.drawCircle(Offset(left + w * 0.49, top + h * 0.30), w * 0.095, outline);
    // Barbe.
    final beard = Path()
      ..moveTo(left + w * 0.41, top + h * 0.32)
      ..quadraticBezierTo(left + w * 0.49, top + h * 0.44, left + w * 0.57, top + h * 0.32)
      ..close();
    canvas.drawPath(beard, Paint()..color = dark.withValues(alpha: 0.7));

    // Couronne à trois pointes.
    final crown = Path()
      ..moveTo(left + w * 0.38, top + h * 0.235)
      ..lineTo(left + w * 0.38, top + h * 0.15)
      ..lineTo(left + w * 0.435, top + h * 0.20)
      ..lineTo(left + w * 0.49, top + h * 0.13)
      ..lineTo(left + w * 0.545, top + h * 0.20)
      ..lineTo(left + w * 0.60, top + h * 0.15)
      ..lineTo(left + w * 0.60, top + h * 0.235)
      ..close();
    canvas.drawPath(crown, gold);
    canvas.drawPath(crown, outline);

    // Sceptre à main droite.
    canvas.drawLine(
      Offset(left + w * 0.72, top + h * 0.28),
      Offset(left + w * 0.72, top + h * 0.62),
      Paint()
        ..color = const Color(0xFFC9971B)
        ..strokeWidth = math.max(1.2, w * 0.04)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(left + w * 0.72, top + h * 0.25), w * 0.035, gold);
  }

  @override
  bool shouldRepaint(covariant SpanishCardPainter oldDelegate) =>
      oldDelegate.card.id != card.id;
}

/// Dos de carte : treillis zellige doré sur rouge profond, double cadre.
class CardBackWidget extends StatelessWidget {
  final double width;
  final double angle;

  const CardBackWidget({super.key, this.width = 64, this.angle = 0});

  @override
  Widget build(BuildContext context) {
    final height = width * 1.5;
    Widget back = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8A2323), Color(0xFF5C1414)],
        ),
        borderRadius: BorderRadius.circular(width * 0.11),
        border: Border.all(color: RondaColors.gold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.10),
        child: CustomPaint(
          size: Size(width, height),
          painter: _CardBackPainter(),
        ),
      ),
    );
    if (angle != 0) back = Transform.rotate(angle: angle, child: back);
    return back;
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = RondaColors.gold.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final cell = size.width / 3.2;
    for (double x = cell / 2; x < size.width; x += cell) {
      for (double y = cell / 2; y < size.height; y += cell) {
        _drawStar(canvas, Offset(x, y), cell * 0.42, paint);
      }
    }

    // Cadre intérieur.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(size.width * 0.09, size.height * 0.06, size.width * 0.91, size.height * 0.94),
        Radius.circular(size.width * 0.06),
      ),
      Paint()
        ..color = RondaColors.gold.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    for (final angleOffset in [0.0, math.pi / 4]) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final angle = angleOffset + i * math.pi / 2;
        final p = center + Offset.fromDirection(angle, radius);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CardBackPainter oldDelegate) => false;
}
