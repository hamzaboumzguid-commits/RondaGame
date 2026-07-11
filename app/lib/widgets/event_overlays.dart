import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/protocol.dart';
import '../theme.dart';

/// Durées des animations bloquantes (GDD 3.4 : 1-2s max).
const kDerbaTier1Duration = Duration(milliseconds: 1000);
const kDerbaTier2Duration = Duration(milliseconds: 1400);
const kDerbaTier3Duration = Duration(milliseconds: 1900);
const kMissaDuration = Duration(milliseconds: 950);
const kRevealDuration = Duration(milliseconds: 2600);
const kRoundEndDuration = Duration(milliseconds: 2600);

/// Escalade visuelle de la Derba (GDD 3.4) :
/// palier 1 = flash discret, palier 2 = éclat marqué, palier 3 = plein écran.
class DerbaOverlay extends StatefulWidget {
  final int tier; // 1, 2 ou 3
  final int points;
  final String team;
  final String playerNickname;
  final VoidCallback onDone;

  const DerbaOverlay({
    super.key,
    required this.tier,
    required this.points,
    required this.team,
    required this.playerNickname,
    required this.onDone,
  });

  @override
  State<DerbaOverlay> createState() => _DerbaOverlayState();
}

class _DerbaOverlayState extends State<DerbaOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration get _duration => switch (widget.tier) {
        1 => kDerbaTier1Duration,
        2 => kDerbaTier2Duration,
        _ => kDerbaTier3Duration,
      };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return switch (widget.tier) {
          1 => _buildTier1(t),
          2 => _buildTier2(t),
          _ => _buildTier3(t),
        };
      },
    );
  }

  /// Palier 1 : texte doré qui surgit et s'estompe, léger halo.
  Widget _buildTier1(double t) {
    final scale = Curves.elasticOut.transform(math.min(1, t * 2.2));
    final opacity = t < 0.75 ? 1.0 : 1 - (t - 0.75) / 0.25;
    return Center(
      child: Opacity(
        opacity: opacity.clamp(0, 1),
        child: Transform.scale(
          scale: scale,
          child: _DerbaText(
            label: 'Derba !',
            sub: '+${widget.points} · ${widget.playerNickname}',
            fontSize: 42,
            color: RondaColors.gold,
          ),
        ),
      ),
    );
  }

  /// Palier 2 : éclat radial + secousse + texte plus imposant.
  Widget _buildTier2(double t) {
    final scale = Curves.elasticOut.transform(math.min(1, t * 2.0));
    final opacity = t < 0.8 ? 1.0 : 1 - (t - 0.8) / 0.2;
    final shake = math.sin(t * math.pi * 14) * 6 * (1 - t);
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RadialBurstPainter(
              progress: t,
              color: RondaColors.teamLight(widget.team),
              rayCount: 12,
            ),
          ),
        ),
        Center(
          child: Transform.translate(
            offset: Offset(shake, 0),
            child: Opacity(
              opacity: opacity.clamp(0, 1),
              child: Transform.scale(
                scale: scale,
                child: _DerbaText(
                  label: 'DERBA ×2 !',
                  sub: '+${widget.points} · ${widget.playerNickname}',
                  fontSize: 54,
                  color: RondaColors.goldLight,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Palier 3 : voile sombre, explosion d'étoiles zellige, texte géant.
  Widget _buildTier3(double t) {
    final veil = t < 0.15 ? t / 0.15 : (t < 0.85 ? 1.0 : 1 - (t - 0.85) / 0.15);
    final scale = Curves.elasticOut.transform(math.min(1, t * 1.8)) * 1.1;
    final shake = math.sin(t * math.pi * 20) * 9 * (1 - t);
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: (veil * 0.75).clamp(0, 1),
            child: const ColoredBox(color: Colors.black),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _StarExplosionPainter(progress: t, color: RondaColors.gold),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _RadialBurstPainter(
              progress: t,
              color: RondaColors.teamLight(widget.team),
              rayCount: 20,
            ),
          ),
        ),
        Center(
          child: Transform.translate(
            offset: Offset(shake, shake / 2),
            child: Opacity(
              opacity: veil.clamp(0, 1),
              child: Transform.scale(
                scale: scale,
                child: _DerbaText(
                  label: 'DERBA\nROYALE !',
                  sub: '+${widget.points} · ${widget.playerNickname}',
                  fontSize: 64,
                  color: RondaColors.gold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DerbaText extends StatelessWidget {
  final String label;
  final String sub;
  final double fontSize;
  final Color color;

  const _DerbaText({
    required this.label,
    required this.sub,
    required this.fontSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1.05,
            color: color,
            letterSpacing: 2,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 12),
              Shadow(color: RondaColors.redDeep.withValues(alpha: 0.6), blurRadius: 24),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          sub,
          style: TextStyle(
            fontSize: fontSize * 0.32,
            fontWeight: FontWeight.w600,
            color: RondaColors.cream,
            shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
      ],
    );
  }
}

/// Missa : discret mais satisfaisant (GDD 3.4) — onde dorée + pastille "+1".
class MissaOverlay extends StatefulWidget {
  final String playerNickname;
  final VoidCallback onDone;

  const MissaOverlay({super.key, required this.playerNickname, required this.onDone});

  @override
  State<MissaOverlay> createState() => _MissaOverlayState();
}

class _MissaOverlayState extends State<MissaOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kMissaDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final opacity = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _RipplePainter(progress: t, color: RondaColors.gold)),
            ),
            Center(
              child: Opacity(
                opacity: opacity.clamp(0, 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: RondaColors.greenDeep.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: RondaColors.gold, width: 1.5),
                  ),
                  child: Text(
                    'Missa +1 · ${widget.playerNickname}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: RondaColors.goldLight,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Révélation des Rondas/Tringas en fin de petite manche.
class RevealOverlay extends StatefulWidget {
  final SubRoundRevealEvent event;
  final String Function(String playerId) nicknameOf;
  final VoidCallback onDone;

  const RevealOverlay({
    super.key,
    required this.event,
    required this.nicknameOf,
    required this.onDone,
  });

  @override
  State<RevealOverlay> createState() => _RevealOverlayState();
}

class _RevealOverlayState extends State<RevealOverlay> {
  @override
  void initState() {
    super.initState();
    Future.delayed(kRevealDuration, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final anns = widget.event.announcements;
    final points = widget.event.points;
    return _AnnouncementPanel(
      title: anns.isEmpty ? 'Fin de la donne' : 'Révélation !',
      children: [
        if (anns.isEmpty)
          const Text(
            'Aucune Ronda annoncée',
            style: TextStyle(color: RondaColors.creamDark, fontSize: 16),
          ),
        for (final a in anns)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${widget.nicknameOf(a.playerId)} — '
              '${a.kind == 'tringa' ? 'Tringa' : 'Ronda'} de ${rankLabel(a.rank)}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: RondaColors.teamLight(a.team),
              ),
            ),
          ),
        const SizedBox(height: 12),
        for (final entry in points.entries)
          Text(
            '+${entry.value} points pour l\'équipe ${entry.key}',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: RondaColors.gold,
            ),
          ),
        if (points.isEmpty && anns.isNotEmpty)
          const Text(
            'Égalité — aucun point',
            style: TextStyle(fontSize: 17, color: RondaColors.creamDark),
          ),
      ],
    );
  }
}

/// Bilan de fin de manche : butin + bonus de dernière capture.
class RoundEndOverlay extends StatefulWidget {
  final RoundEndEvent event;
  final VoidCallback onDone;

  const RoundEndOverlay({super.key, required this.event, required this.onDone});

  @override
  State<RoundEndOverlay> createState() => _RoundEndOverlayState();
}

class _RoundEndOverlayState extends State<RoundEndOverlay> {
  @override
  void initState() {
    super.initState();
    Future.delayed(kRoundEndDuration, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return _AnnouncementPanel(
      title: 'Fin de la manche',
      children: [
        Text(
          'Cartes : Équipe A ${e.cardCounts['A']} — ${e.cardCounts['B']} Équipe B',
          style: const TextStyle(fontSize: 17, color: RondaColors.cream),
        ),
        const SizedBox(height: 10),
        for (final entry in e.butinPoints.entries)
          Text(
            'Butin : +${entry.value} pour l\'équipe ${entry.key}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: RondaColors.gold,
            ),
          ),
        if (e.butinPoints.isEmpty)
          const Text(
            'Butin : égalité, aucun point',
            style: TextStyle(fontSize: 16, color: RondaColors.creamDark),
          ),
        for (final entry in e.bonusPoints.entries)
          Text(
            'Dernière capture : +${entry.value} pour l\'équipe ${entry.key}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: RondaColors.goldLight,
            ),
          ),
      ],
    );
  }
}

class _AnnouncementPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _AnnouncementPanel({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: RondaColors.wood,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: RondaColors.gold, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 24),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: RondaColors.gold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Peintres ----------

class _RadialBurstPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int rayCount;

  _RadialBurstPainter({required this.progress, required this.color, required this.rayCount});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.longestSide * 0.7;
    final radius = maxRadius * Curves.easeOut.transform(progress);
    final opacity = (1 - progress).clamp(0.0, 1.0) * 0.5;
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < rayCount; i++) {
      final angle = i * 2 * math.pi / rayCount;
      final from = center + Offset.fromDirection(angle, radius * 0.4);
      final to = center + Offset.fromDirection(angle, radius);
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadialBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _StarExplosionPainter extends CustomPainter {
  final double progress;
  final Color color;

  _StarExplosionPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rng = math.Random(7); // graine fixe : trajectoires stables sur toute l'animation
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withValues(alpha: opacity * 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 14; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final distance = size.shortestSide * (0.2 + rng.nextDouble() * 0.5) * progress;
      final position = center + Offset.fromDirection(angle, distance);
      final starSize = 8.0 + rng.nextDouble() * 10;
      _drawStar(canvas, position, starSize * (1 - progress * 0.3), paint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    for (final angleOffset in [0.0, math.pi / 4]) {
      final path = Path();
      for (int i = 0; i < 4; i++) {
        final angle = angleOffset + i * math.pi / 2;
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
  bool shouldRepaint(covariant _StarExplosionPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide * 0.6;
    for (final delay in [0.0, 0.2]) {
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final paint = Paint()
        ..color = color.withValues(alpha: (1 - t) * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, maxRadius * Curves.easeOut.transform(t), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) => oldDelegate.progress != progress;
}
