import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/protocol.dart';
import '../theme.dart';

/// Durées des animations bloquantes (GDD 3.5 : 1-2s max).
const kDerbaTier1Duration = Duration(milliseconds: 1100);
const kDerbaTier2Duration = Duration(milliseconds: 1500);
const kDerbaTier3Duration = Duration(milliseconds: 2000);
const kMissaDuration = Duration(milliseconds: 1100);
const kRevealDuration = Duration(milliseconds: 3000);
const kRoundEndDuration = Duration(milliseconds: 3000);
const kLastCaptureDuration = Duration(milliseconds: 1700);

// ---------------------------------------------------------------------------
// Langage visuel commun : tous les événements utilisent le même vocabulaire
// (texte arcade contour+dégradé, flare, onde de choc, confettis physiques) —
// seule l'INTENSITÉ change selon l'importance de l'événement.
// ---------------------------------------------------------------------------

/// Impact générique : flare + onde + confettis + texte, intensité 0..1.
class _ImpactLayer extends StatelessWidget {
  final double t;
  final double intensity; // 0.25 = Missa, 0.4 = Derba 1, 0.7 = Derba 2, 1.0 = Derba 3
  final Color accent;

  const _ImpactLayer({
    required this.t,
    required this.intensity,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ShockwavePainter(
              progress: t,
              color: accent,
              doubleWave: intensity >= 0.9,
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _FlarePainter(
              progress: t,
              color: RondaColors.goldLight,
              maxScale: 0.3 + 0.6 * intensity,
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _ConfettiBurstPainter(
              progress: t,
              count: (12 + 60 * intensity).round(),
              spread: 0.3 + 0.65 * intensity,
              seed: 7,
            ),
          ),
        ),
      ],
    );
  }
}

/// Escalade visuelle de la Derba (GDD 3.5) : trois paliers du même langage,
/// de plus en plus intenses.
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
        final tier = widget.tier;
        final intensity = tier == 1 ? 0.4 : (tier == 2 ? 0.7 : 1.0);
        final scale = Curves.elasticOut.transform(math.min(1, t * 2.0)) * (tier == 3 ? 1.05 + t * 0.1 : 1.0);
        final shakeAmp = tier == 1 ? 0.0 : (tier == 2 ? 7.0 : 10.0);
        final shake = math.sin(t * math.pi * 18) * shakeAmp * (1 - t);
        final fade = t < 0.8 ? 1.0 : 1 - (t - 0.8) / 0.2;
        final veil = tier == 3
            ? (t < 0.12 ? t / 0.12 : (t < 0.85 ? 1.0 : 1 - (t - 0.85) / 0.15))
            : 0.0;

        return Stack(
          children: [
            if (tier == 3)
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
            _ImpactLayer(
              t: t,
              intensity: intensity,
              accent: RondaColors.teamLight(widget.team),
            ),
            Center(
              child: Transform.translate(
                offset: Offset(shake, shake / 2),
                child: Opacity(
                  opacity: fade.clamp(0, 1),
                  child: Transform.scale(
                    scale: scale,
                    child: _JuicyText(
                      label: switch (tier) { 1 => 'DERBA !', 2 => 'DERBA ×2 !', _ => 'DERBA\nROYALE !' },
                      sub: '+${widget.points} PTS · ${widget.playerNickname.toUpperCase()}',
                      fontSize: switch (tier) { 1 => 46, 2 => 56, _ => 66 },
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

/// Missa : même langage que la Derba, en plus doux (GDD 3.5 : discret
/// mais satisfaisant) — vert « table nettoyée » au lieu de l'or.
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
        final scale = Curves.elasticOut.transform(math.min(1, t * 2.0));
        final fade = t < 0.8 ? 1.0 : 1 - (t - 0.8) / 0.2;
        return Stack(
          children: [
            _ImpactLayer(
              t: t,
              intensity: 0.25,
              accent: const Color(0xFF4E9E73),
            ),
            Center(
              child: Opacity(
                opacity: fade.clamp(0, 1),
                child: Transform.scale(
                  scale: scale,
                  child: _JuicyText(
                    label: 'MISSA !',
                    sub: '+1 PT · ${widget.playerNickname.toUpperCase()}',
                    fontSize: 42,
                    gradient: const [Color(0xFFC8F5D8), Color(0xFF5BC98A), Color(0xFF2E8B57)],
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

/// Typographie de jeu : contour épais sombre + remplissage dégradé,
/// façon titre d'arcade — lisible et punchy sur n'importe quel fond.
class _JuicyText extends StatelessWidget {
  final String label;
  final String sub;
  final double fontSize;
  final List<Color> gradient;

  const _JuicyText({
    required this.label,
    required this.sub,
    required this.fontSize,
    this.gradient = const [Color(0xFFFFF3C4), Color(0xFFF2C94C), Color(0xFFE0902B)],
  });

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
            // Remplissage dégradé.
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradient,
                stops: const [0.0, 0.55, 1.0],
              ).createShader(bounds),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: base.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: RondaColors.gold.withValues(alpha: 0.7)),
            ),
            child: Text(
              sub,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: math.max(15, fontSize * 0.30),
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: RondaColors.cream,
              ),
            ),
          ),
        ],
      ],
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
          const _PanelRow(
            icon: Icons.visibility_off_rounded,
            label: 'AUCUNE ANNONCE',
            value: '',
          ),
        for (final a in anns)
          _PanelRow(
            icon: a.kind == 'tringa' ? Icons.auto_awesome_rounded : Icons.stars_rounded,
            iconColor: a.kind == 'tringa' ? const Color(0xFFB65CE8) : RondaColors.goldLight,
            label: '${widget.nicknameOf(a.playerId).toUpperCase()} — '
                '${a.kind == 'tringa' ? 'TRINGA' : 'RONDA'} DE ${rankLabel(a.rank).toUpperCase()}',
            value: '',
            labelColor: RondaColors.teamLight(a.team),
          ),
        const SizedBox(height: 8),
        for (final entry in points.entries)
          _PanelRow(
            icon: Icons.add_circle_rounded,
            iconColor: RondaColors.teamLight(entry.key),
            label: 'ÉQUIPE ${entry.key}',
            value: '+${entry.value} PTS',
          ),
        if (points.isEmpty && anns.isNotEmpty)
          const _PanelRow(
            icon: Icons.balance_rounded,
            label: 'ÉGALITÉ — AUCUN POINT',
            value: '',
          ),
      ],
    );
  }
}

/// Bilan de fin de manche, précédé si besoin de l'animation de dernière
/// capture : célébration si c'est un Roi (+5), déception si c'est un As
/// (5 pts offerts à l'adversaire).
class RoundEndOverlay extends StatefulWidget {
  final RoundEndEvent event;
  final VoidCallback onDone;

  const RoundEndOverlay({super.key, required this.event, required this.onDone});

  @override
  State<RoundEndOverlay> createState() => _RoundEndOverlayState();
}

class _RoundEndOverlayState extends State<RoundEndOverlay> {
  late bool _showingLastCapture;

  bool get _hasSpecialCapture =>
      widget.event.lastCaptureRank == 12 || widget.event.lastCaptureRank == 1;

  @override
  void initState() {
    super.initState();
    _showingLastCapture = _hasSpecialCapture;
    _scheduleNext();
  }

  void _scheduleNext() {
    if (_showingLastCapture) {
      Future.delayed(kLastCaptureDuration, () {
        if (!mounted) return;
        setState(() => _showingLastCapture = false);
        _scheduleNext();
      });
    } else {
      Future.delayed(kRoundEndDuration, () {
        if (mounted) widget.onDone();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showingLastCapture) {
      return _LastCaptureOverlay(
        isKing: widget.event.lastCaptureRank == 12,
        team: widget.event.lastCaptureTeam ?? 'A',
      );
    }

    final e = widget.event;
    return _AnnouncementPanel(
      title: 'FIN DE LA MANCHE',
      icon: Icons.emoji_events_rounded,
      children: [
        _PanelRow(
          icon: Icons.style_rounded,
          label: 'CARTES RAMASSÉES',
          value: 'A ${e.cardCounts['A']} — ${e.cardCounts['B']} B',
        ),
        const SizedBox(height: 8),
        for (final entry in e.butinPoints.entries)
          _PanelRow(
            icon: Icons.savings_rounded,
            iconColor: RondaColors.teamLight(entry.key),
            label: 'BUTIN ÉQUIPE ${entry.key}',
            value: '+${entry.value} PTS',
          ),
        if (e.butinPoints.isEmpty)
          const _PanelRow(
            icon: Icons.balance_rounded,
            label: 'BUTIN : ÉGALITÉ',
            value: '0 PT',
          ),
        for (final entry in e.bonusPoints.entries)
          _PanelRow(
            icon: e.lastCaptureRank == 12 ? Icons.workspace_premium_rounded : Icons.warning_rounded,
            iconColor: e.lastCaptureRank == 12 ? RondaColors.goldLight : const Color(0xFFE05A2B),
            label: e.lastCaptureRank == 12
                ? 'DERNIÈRE PRISE AU ROI'
                : 'AS EN DERNIÈRE PRISE',
            value: '+${entry.value} PTS ÉQ. ${entry.key}',
          ),
      ],
    );
  }
}

/// Animation dédiée à la dernière capture : Roi = triomphe doré,
/// As = douche froide bleutée.
class _LastCaptureOverlay extends StatefulWidget {
  final bool isKing;
  final String team;

  const _LastCaptureOverlay({required this.isKing, required this.team});

  @override
  State<_LastCaptureOverlay> createState() => _LastCaptureOverlayState();
}

class _LastCaptureOverlayState extends State<_LastCaptureOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kLastCaptureDuration,
  )..forward();

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
        final veil = t < 0.15 ? t / 0.15 : (t < 0.85 ? 1.0 : 1 - (t - 0.85) / 0.15);
        final scale = Curves.elasticOut.transform(math.min(1, t * 1.8));

        if (widget.isKing) {
          // Triomphe : voile chaud, double onde, confettis dorés, couronne.
          return Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: (veil * 0.6).clamp(0, 1),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0xCC4A3200), Color(0xE61A0F00)],
                        radius: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              _ImpactLayer(
                t: t,
                intensity: 0.85,
                accent: RondaColors.goldLight,
              ),
              Center(
                child: Opacity(
                  opacity: veil.clamp(0, 1),
                  child: Transform.scale(
                    scale: scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          size: 84,
                          color: RondaColors.goldLight,
                          shadows: const [Shadow(color: Colors.black87, blurRadius: 16)],
                        ),
                        _JuicyText(
                          label: 'PRISE ROYALE !',
                          sub: 'LE ROI CONCLUT · +5 PTS ÉQUIPE ${widget.team}',
                          fontSize: 48,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Déception : voile bleu froid, pluie de confettis gris qui tombent.
        final droop = Curves.easeIn.transform(t) * 26;
        return Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: (veil * 0.65).clamp(0, 1),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0xCC1A2A40), Color(0xE6080E18)],
                      radius: 1.0,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _SadRainPainter(progress: t),
              ),
            ),
            Center(
              child: Opacity(
                opacity: veil.clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(0, droop),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.rotate(
                        angle: 0.15 * t,
                        child: const Icon(
                          Icons.heart_broken_rounded,
                          size: 74,
                          color: Color(0xFF9FB4CC),
                          shadows: [Shadow(color: Colors.black87, blurRadius: 14)],
                        ),
                      ),
                      _JuicyText(
                        label: 'AÏE... L\'AS !',
                        sub: 'DERNIÈRE PRISE À L\'AS · +5 PTS POUR L\'ADVERSAIRE',
                        fontSize: 44,
                        gradient: const [Color(0xFFD4E2F4), Color(0xFF8FA9C8), Color(0xFF5A7396)],
                      ),
                    ],
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

/// Panneau central : entrée élastique, fort contraste, rangées lisibles.
class _AnnouncementPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _AnnouncementPanel({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (_, t, child) =>
              Transform.scale(scale: 0.7 + 0.3 * t, child: Opacity(opacity: t.clamp(0, 1), child: child)),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF43301D), Color(0xFF241407)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: RondaColors.gold, width: 3),
              boxShadow: [
                BoxShadow(color: RondaColors.gold.withValues(alpha: 0.3), blurRadius: 34),
                BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 24),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: RondaColors.goldLight, size: 34),
                const SizedBox(height: 6),
                _JuicyText(label: title, sub: '', fontSize: 26),
                Container(
                  margin: const EdgeInsets.only(top: 2, bottom: 14),
                  height: 2,
                  width: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      RondaColors.gold.withValues(alpha: 0.9),
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

/// Rangée de panneau à fort contraste : icône ronde, libellé, valeur en or.
class _PanelRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color labelColor;

  const _PanelRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = RondaColors.goldLight,
    this.labelColor = RondaColors.cream,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: labelColor,
              ),
            ),
          ),
          if (value.isNotEmpty)
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: RondaColors.goldLight,
                shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
              ),
            ),
        ],
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
    final radius =
        size.shortestSide * maxScale * Curves.easeOut.transform(math.min(1, progress * 1.6));
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

  static const _defaultPalette = [
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
    const colors = _defaultPalette;
    final center = Offset(size.width / 2, size.height / 2);
    final rng = math.Random(seed); // graine fixe : trajectoires stables
    final gravity = size.height * 0.55;

    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = size.shortestSide * spread * (0.5 + rng.nextDouble());
      final spin = (rng.nextDouble() - 0.5) * 14;
      final confettiSize = 4.0 + rng.nextDouble() * 7;
      final color = colors[i % colors.length];
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

/// Pluie froide et lente pour la déception de l'As en dernière prise.
class _SadRainPainter extends CustomPainter {
  final double progress;

  _SadRainPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(13);
    for (var i = 0; i < 26; i++) {
      final x = rng.nextDouble() * size.width;
      final phase = rng.nextDouble();
      final speed = 0.5 + rng.nextDouble() * 0.5;
      final y = ((progress * speed + phase) % 1.0) * (size.height + 30) - 15;
      final opacity = (1 - progress * 0.4).clamp(0.0, 1.0) * 0.5;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 2, y + 14),
        Paint()
          ..color = const Color(0xFF9FB4CC).withValues(alpha: opacity)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SadRainPainter oldDelegate) => oldDelegate.progress != progress;
}
