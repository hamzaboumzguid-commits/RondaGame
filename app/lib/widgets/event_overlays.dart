import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/protocol.dart';
import '../theme.dart';

/// Durées des animations bloquantes (GDD 3.4 : 1-2s max).
const kDerbaTier1Duration = Duration(milliseconds: 1100);
const kDerbaTier2Duration = Duration(milliseconds: 1500);
const kDerbaTier3Duration = Duration(milliseconds: 2000);
const kMissaDuration = Duration(milliseconds: 1000);
const kRevealDuration = Duration(milliseconds: 2600);
const kRoundEndDuration = Duration(milliseconds: 2600);

/// Escalade visuelle de la Derba (GDD 3.4) :
/// palier 1 = impact doré + étincelles, palier 2 = onde de choc + confettis,
/// palier 3 = plein écran : voile, double onde, pluie de confettis, zoom punchy.
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

  /// Palier 1 : le mot claque avec un flare doré et quelques étincelles.
  Widget _buildTier1(double t) {
    final scale = Curves.elasticOut.transform(math.min(1, t * 2.2));
    final opacity = t < 0.75 ? 1.0 : 1 - (t - 0.75) / 0.25;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _FlarePainter(progress: t, color: RondaColors.goldLight, maxScale: 0.35),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _ConfettiBurstPainter(progress: t, count: 16, spread: 0.35, seed: 3),
          ),
        ),
        Center(
          child: Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.scale(
              scale: scale,
              child: _JuicyText(
                label: 'DERBA !',
                sub: '+${widget.points} · ${widget.playerNickname}',
                fontSize: 46,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Palier 2 : onde de choc, secousse, confettis, texte plus gros.
  Widget _buildTier2(double t) {
    final scale = Curves.elasticOut.transform(math.min(1, t * 2.0)) * 1.05;
    final opacity = t < 0.8 ? 1.0 : 1 - (t - 0.8) / 0.2;
    final shake = math.sin(t * math.pi * 16) * 7 * (1 - t);
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ShockwavePainter(progress: t, color: RondaColors.teamLight(widget.team)),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _FlarePainter(progress: t, color: RondaColors.gold, maxScale: 0.55),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _ConfettiBurstPainter(progress: t, count: 34, spread: 0.55, seed: 11),
          ),
        ),
        Center(
          child: Transform.translate(
            offset: Offset(shake, 0),
            child: Opacity(
              opacity: opacity.clamp(0, 1),
              child: Transform.scale(
                scale: scale,
                child: _JuicyText(
                  label: 'DERBA ×2 !',
                  sub: '+${widget.points} · ${widget.playerNickname}',
                  fontSize: 56,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Palier 3 : LE moment de la partie — voile, double onde de choc,
  /// pluie de confettis, zoom continu, grosse secousse.
  Widget _buildTier3(double t) {
    final veil = t < 0.12 ? t / 0.12 : (t < 0.85 ? 1.0 : 1 - (t - 0.85) / 0.15);
    final punch = Curves.elasticOut.transform(math.min(1, t * 1.8));
    final zoom = punch * (1.05 + t * 0.1); // continue de grossir doucement
    final shake = math.sin(t * math.pi * 22) * 10 * (1 - t);
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: (veil * 0.78).clamp(0, 1),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xE6300808), Color(0xF20D0202)],
                  radius: 1.0,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _ShockwavePainter(progress: t, color: RondaColors.gold, doubleWave: true),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _FlarePainter(progress: t, color: RondaColors.goldLight, maxScale: 0.9),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _ConfettiBurstPainter(progress: t, count: 70, spread: 0.95, seed: 7),
          ),
        ),
        Center(
          child: Transform.translate(
            offset: Offset(shake, shake / 2),
            child: Opacity(
              opacity: veil.clamp(0, 1),
              child: Transform.scale(
                scale: zoom,
                child: _JuicyText(
                  label: 'DERBA\nROYALE !',
                  sub: '+${widget.points} · ${widget.playerNickname}',
                  fontSize: 66,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Typographie de jeu : contour épais sombre + remplissage dégradé or,
/// façon titre d'arcade — lisible et punchy sur n'importe quel fond.
class _JuicyText extends StatelessWidget {
  final String label;
  final String sub;
  final double fontSize;

  const _JuicyText({required this.label, required this.sub, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1.02,
      letterSpacing: 2,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            // Contour épais.
            Text(
              label,
              textAlign: TextAlign.center,
              style: base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = fontSize * 0.14
                  ..strokeJoin = StrokeJoin.round
                  ..color = const Color(0xFF3A1204),
              ),
            ),
            // Remplissage dégradé or → orange.
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF3C4), Color(0xFFF2C94C), Color(0xFFE0902B)],
                stops: [0.0, 0.55, 1.0],
              ).createShader(bounds),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: base.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RondaColors.gold.withValues(alpha: 0.6)),
          ),
          child: Text(
            sub,
            style: TextStyle(
              fontSize: math.max(14, fontSize * 0.30),
              fontWeight: FontWeight.w700,
              color: RondaColors.cream,
            ),
          ),
        ),
      ],
    );
  }
}

/// Missa : la table se vide — onde dorée qui balaie + pastille satisfaisante.
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
        final scale = Curves.easeOutBack.transform(math.min(1, t * 2.5));
        final opacity = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _RipplePainter(progress: t, color: RondaColors.gold)),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _ConfettiBurstPainter(progress: t, count: 12, spread: 0.28, seed: 5),
              ),
            ),
            Center(
              child: Opacity(
                opacity: opacity.clamp(0, 1),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E8B57), Color(0xFF1F6E43)],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: RondaColors.goldLight, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: RondaColors.gold.withValues(alpha: 0.5),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cleaning_services_rounded,
                            color: RondaColors.goldLight, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'MISSA +1 · ${widget.playerNickname}',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: RondaColors.cream,
                          ),
                        ),
                      ],
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
      title: anns.isEmpty ? 'FIN DE LA DONNE' : 'RÉVÉLATION !',
      icon: anns.isEmpty ? Icons.style_rounded : Icons.celebration_rounded,
      children: [
        if (anns.isEmpty)
          const Text(
            'Aucune Ronda annoncée',
            style: TextStyle(color: RondaColors.creamDark, fontSize: 16),
          ),
        for (final a in anns)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: RondaColors.team(a.team),
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  '${widget.nicknameOf(a.playerId)} — '
                  '${a.kind == 'tringa' ? 'Tringa' : 'Ronda'} de ${rankLabel(a.rank)}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: RondaColors.teamLight(a.team),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        for (final entry in points.entries)
          Text(
            '+${entry.value} points pour l\'équipe ${entry.key}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
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
      title: 'FIN DE LA MANCHE',
      icon: Icons.emoji_events_rounded,
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
              fontWeight: FontWeight.w800,
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
              fontWeight: FontWeight.w800,
              color: RondaColors.goldLight,
            ),
          ),
      ],
    );
  }
}

/// Panneau central avec entrée élastique, dégradé bois et cadre doré.
class _AnnouncementPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _AnnouncementPanel({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (_, t, child) => Transform.scale(scale: 0.7 + 0.3 * t, child: Opacity(opacity: t.clamp(0, 1), child: child)),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF3D2718), Color(0xFF221208)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: RondaColors.gold, width: 2),
              boxShadow: [
                BoxShadow(color: RondaColors.gold.withValues(alpha: 0.25), blurRadius: 30),
                BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 24),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: RondaColors.goldLight, size: 30),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: RondaColors.gold,
                    letterSpacing: 2,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  height: 1.5,
                  width: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      RondaColors.gold.withValues(alpha: 0.8),
                      Colors.transparent,
                    ]),
                  ),
                ),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Peintres ----------

/// Halo lumineux central qui gonfle puis s'estompe.
class _FlarePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double maxScale;

  _FlarePainter({required this.progress, required this.color, required this.maxScale});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * maxScale * Curves.easeOut.transform(math.min(1, progress * 1.6));
    final opacity = progress < 0.5 ? 1.0 : (1 - (progress - 0.5) / 0.5);
    if (radius <= 0) return;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.55 * opacity.clamp(0, 1)),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _FlarePainter oldDelegate) => oldDelegate.progress != progress;
}

/// Anneau d'onde de choc qui traverse l'écran.
class _ShockwavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool doubleWave;

  _ShockwavePainter({required this.progress, required this.color, this.doubleWave = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.longestSide * 0.75;
    final delays = doubleWave ? [0.0, 0.18] : [0.0];
    for (final delay in delays) {
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final radius = maxRadius * Curves.easeOutCubic.transform(t);
      final opacity = (1 - t).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10 * (1 - t) + 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShockwavePainter oldDelegate) => oldDelegate.progress != progress;
}

/// Confettis physiques : projetés du centre, retombent avec gravité et tournent.
class _ConfettiBurstPainter extends CustomPainter {
  final double progress;
  final int count;
  final double spread; // fraction de l'écran couverte
  final int seed;

  static const _palette = [
    Color(0xFFF2C94C),
    Color(0xFFE0902B),
    Color(0xFFC75B5B),
    Color(0xFF4E9E73),
    Color(0xFFF5EBD8),
  ];

  _ConfettiBurstPainter({
    required this.progress,
    required this.count,
    required this.spread,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rng = math.Random(seed); // graine fixe : trajectoires stables
    final gravity = size.height * 0.55;

    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = size.shortestSide * spread * (0.5 + rng.nextDouble());
      final spin = (rng.nextDouble() - 0.5) * 14;
      final confettiSize = 4.0 + rng.nextDouble() * 7;
      final color = _palette[i % _palette.length];
      final isRect = rng.nextBool();

      final t = progress;
      final pos = center +
          Offset.fromDirection(angle, speed * Curves.easeOut.transform(t)) +
          Offset(0, gravity * t * t * 0.5);
      final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);

      final paint = Paint()..color = color.withValues(alpha: opacity.clamp(0, 1));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(spin * t);
      if (isRect) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: confettiSize, height: confettiSize * 0.6),
            const Radius.circular(1.5),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, confettiSize / 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Ondes concentriques discrètes (Missa).
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
        ..color = color.withValues(alpha: (1 - t) * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, maxRadius * Curves.easeOut.transform(t), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) => oldDelegate.progress != progress;
}
