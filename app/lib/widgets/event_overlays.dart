import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/protocol.dart';
import '../theme.dart';
import 'playing_card.dart';

/// Durées des animations bloquantes (GDD 3.5 : 1-2s max).
const kDerbaTier1Duration = Duration(milliseconds: 1100);
const kDerbaTier2Duration = Duration(milliseconds: 1500);
const kDerbaTier3Duration = Duration(milliseconds: 2000);
const kMissaDuration = Duration(milliseconds: 1100);
const kRevealDuration = Duration(milliseconds: 3000);
const kRoundEndDuration = Duration(milliseconds: 3000);
const kLastCaptureDuration = Duration(milliseconds: 1700);
const kDealDuration = Duration(milliseconds: 1800);
const kCardTallyDuration = Duration(milliseconds: 2400);

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
    final strings = context.watch<AppStrings>();
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
                      // Surenchères en darija : 7BIYEL puis JOUJ 7BOULA (GDD 2.7).
                      label: switch (tier) {
                        1 => strings.t('overlay.derbaTier1'),
                        2 => strings.t('overlay.derbaTier2'),
                        _ => strings.t('overlay.derbaTier3').replaceAll(' ', '\n'),
                      },
                      sub: strings.t('overlay.pointsEarned', {
                        'n': widget.points,
                        'nickname': widget.playerNickname.toUpperCase(),
                      }),
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
  // Derba+Missa simultanées (GDD 2.8) : le point de Missa est déjà inclus
  // dans le total affiché par le DerbaOverlay précédent — ne pas le recompter.
  final bool pointsAlreadyShown;

  const MissaOverlay({
    super.key,
    required this.playerNickname,
    required this.onDone,
    this.pointsAlreadyShown = false,
  });

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
    final strings = context.watch<AppStrings>();
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
                    label: strings.t('overlay.missa'),
                    sub: widget.pointsAlreadyShown
                        ? widget.playerNickname.toUpperCase()
                        : strings.t('overlay.pointsEarned', {
                            'n': 1,
                            'nickname': widget.playerNickname.toUpperCase(),
                          }),
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
    final strings = context.watch<AppStrings>();
    final anns = widget.event.announcements;
    final points = widget.event.points;
    return _AnnouncementPanel(
      title: anns.isEmpty
          ? strings.t('overlay.revealNoAnnouncement')
          : strings.t('overlay.revealAskAnnouncement'),
      icon: anns.isEmpty ? Icons.style_rounded : Icons.celebration_rounded,
      children: [
        if (anns.isEmpty)
          _PanelRow(
            icon: Icons.visibility_off_rounded,
            label: strings.t('overlay.noAnnouncement'),
            value: '',
          ),
        for (final a in anns)
          _PanelRow(
            icon: a.kind == 'tringa' ? Icons.auto_awesome_rounded : Icons.stars_rounded,
            iconColor: a.kind == 'tringa' ? const Color(0xFFB65CE8) : RondaColors.goldLight,
            label: strings.t('overlay.announcementRow', {
              'nickname': widget.nicknameOf(a.playerId).toUpperCase(),
              'kind': a.kind == 'tringa'
                  ? strings.t('game.announcementTringa').replaceAll(' !', '').replaceAll('!', '')
                  : strings.t('game.announcementRonda').replaceAll(' !', '').replaceAll('!', ''),
              'rank': rankLabel(a.rank, strings.t).toUpperCase(),
            }),
            value: '',
            labelColor: RondaColors.teamLight(a.team),
          ),
        const SizedBox(height: 8),
        for (final entry in points.entries)
          _PanelRow(
            icon: Icons.add_circle_rounded,
            iconColor: RondaColors.teamLight(entry.key),
            label: strings.t('overlay.teamHeader', {'letter': entry.key}),
            value: strings.t('overlay.pointsRow', {'n': entry.value}),
          ),
        if (points.isEmpty && anns.isNotEmpty)
          _PanelRow(
            icon: Icons.balance_rounded,
            label: strings.t('overlay.tieNoPoints'),
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

/// Phases enchaînées de la fin de ter7, dans l'ordre : animation de dernière
/// prise (Roi/As/MAJEBTICH) → décompte des cartes ramassées → bilan chiffré.
enum _RoundEndPhase { lastCapture, tally, summary }

class _RoundEndOverlayState extends State<RoundEndOverlay> {
  late _RoundEndPhase _phase;

  /// Les trois cas sont mutuellement exclusifs : dernière prise au Roi,
  /// dernière prise à l'As, ou le Lead qui n'a pas conclu (MAJEBTICH).
  _LastCaptureKind? get _specialKind {
    if (widget.event.lastCaptureRank == 12) return _LastCaptureKind.king;
    if (widget.event.lastCaptureRank == 1) return _LastCaptureKind.ace;
    if (widget.event.leadMissedLastCapture) return _LastCaptureKind.leadMissed;
    return null;
  }

  @override
  void initState() {
    super.initState();
    // On démarre par la dernière prise (Roi/As/MAJEBTICH) si applicable,
    // sinon on saute directement au décompte des cartes.
    _phase = _specialKind != null ? _RoundEndPhase.lastCapture : _RoundEndPhase.tally;
    _scheduleNext();
  }

  /// Fait avancer la machine d'états : dernière prise → décompte → bilan.
  void _scheduleNext() {
    final duration = switch (_phase) {
      _RoundEndPhase.lastCapture => kLastCaptureDuration,
      _RoundEndPhase.tally => kCardTallyDuration,
      _RoundEndPhase.summary => kRoundEndDuration,
    };
    Future.delayed(duration, () {
      if (!mounted) return;
      final next = switch (_phase) {
        _RoundEndPhase.lastCapture => _RoundEndPhase.tally,
        _RoundEndPhase.tally => _RoundEndPhase.summary,
        _RoundEndPhase.summary => null,
      };
      if (next == null) {
        widget.onDone();
        return;
      }
      setState(() => _phase = next);
      _scheduleNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _RoundEndPhase.tally) {
      return _CardTallyOverlay(
        countA: widget.event.cardCounts['A'] ?? 0,
        countB: widget.event.cardCounts['B'] ?? 0,
      );
    }
    if (_phase == _RoundEndPhase.lastCapture) {
      return _LastCaptureOverlay(
        kind: _specialKind!,
        team: widget.event.lastCaptureTeam ?? 'A',
      );
    }

    final strings = context.watch<AppStrings>();
    final e = widget.event;
    return _AnnouncementPanel(
      title: strings.t('overlay.roundEndTitle'),
      icon: Icons.emoji_events_rounded,
      children: [
        _PanelRow(
          icon: Icons.style_rounded,
          label: strings.t('overlay.cardsCollected'),
          value: strings.t('overlay.cardsCollectedValue', {
            'countA': e.cardCounts['A'] ?? 0,
            'countB': e.cardCounts['B'] ?? 0,
          }),
        ),
        const SizedBox(height: 8),
        for (final entry in e.butinPoints.entries)
          _PanelRow(
            icon: Icons.savings_rounded,
            iconColor: RondaColors.teamLight(entry.key),
            label: strings.t('overlay.butinTeam', {'letter': entry.key}),
            value: strings.t('overlay.pointsRow', {'n': entry.value}),
          ),
        if (e.butinPoints.isEmpty)
          _PanelRow(
            icon: Icons.balance_rounded,
            label: strings.t('overlay.butinTie'),
            value: strings.t('overlay.zeroPts'),
          ),
        for (final entry in e.bonusPoints.entries)
          _PanelRow(
            icon: e.lastCaptureRank == 12 ? Icons.workspace_premium_rounded : Icons.warning_rounded,
            iconColor: e.lastCaptureRank == 12 ? RondaColors.goldLight : const Color(0xFFE05A2B),
            label: e.lastCaptureRank == 12
                ? strings.t('overlay.lastCaptureKing')
                : strings.t('overlay.lastCaptureAce'),
            value: strings.t('overlay.pointsTeamValue', {'n': entry.value, 'letter': entry.key}),
          ),
      ],
    );
  }
}

/// Animation de distribution : le Lead envoie les cartes face cachée vers
/// chaque joueur (bas = soi, haut = en face, côtés en 2v2), puis la main
/// se dévoile quand l'overlay se retire.
class DealOverlay extends StatefulWidget {
  final String dealerName;
  final int cardsPerPlayer;
  final int dealIndex;
  final int dealsPerRound;
  final int playerCount; // 2 ou 4
  final VoidCallback onDone;

  const DealOverlay({
    super.key,
    required this.dealerName,
    required this.cardsPerPlayer,
    required this.dealIndex,
    required this.dealsPerRound,
    required this.playerCount,
    required this.onDone,
  });

  @override
  State<DealOverlay> createState() => _DealOverlayState();
}

class _DealOverlayState extends State<DealOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kDealDuration)
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
    final strings = context.watch<AppStrings>();
    // Directions d'envol depuis le centre : bas (moi), haut, gauche, droite.
    final directions = widget.playerCount == 2
        ? const [Offset(0, 1), Offset(0, -1)]
        : const [Offset(0, 1), Offset(0, -1), Offset(-1, 0), Offset(1, 0)];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final veil = t < 0.12 ? t / 0.12 : (t < 0.85 ? 1.0 : 1 - (t - 0.85) / 0.15);
        final totalCards = widget.cardsPerPlayer * directions.length;

        return Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: (veil * 0.5).clamp(0, 1),
                child: const ColoredBox(color: Colors.black),
              ),
            ),
            // Cartes distribuées une à une, en tournoyant vers chaque joueur.
            ...List.generate(totalCards, (i) {
              final dir = directions[i % directions.length];
              // Départ étalé sur 70% de l'animation, vol sur 30%.
              final start = (i / totalCards) * 0.65;
              final flight = ((t - start) / 0.3).clamp(0.0, 1.0);
              if (flight <= 0) return const SizedBox.shrink();
              final eased = Curves.easeOutCubic.transform(flight);
              final screen = MediaQuery.of(context).size;
              final target = Offset(
                dir.dx * screen.width * 0.42,
                dir.dy * screen.height * 0.38,
              );
              return Positioned(
                left: screen.width / 2 - 21 + target.dx * eased,
                top: screen.height / 2 - 32 + target.dy * eased,
                child: Opacity(
                  opacity: flight < 0.85 ? 1 : 1 - (flight - 0.85) / 0.15,
                  child: Transform.rotate(
                    angle: eased * 2.4 + i * 0.4,
                    child: const CardBackWidget(width: 42),
                  ),
                ),
              );
            }),
            Align(
              alignment: const Alignment(0, -0.45),
              child: Opacity(
                opacity: veil.clamp(0, 1),
                child: _JuicyText(
                  label: strings.t('overlay.dealBadge', {
                    'n': widget.dealIndex + 1,
                    'total': widget.dealsPerRound,
                  }),
                  sub: strings.t('overlay.dealerDeals', {
                    'nickname': widget.dealerName.toUpperCase(),
                  }),
                  fontSize: 40,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Décompte animé des cartes ramassées par chaque équipe en fin de ter7 :
/// deux compteurs qui montent en parallèle, deux piles qui grandissent, et
/// la différence qui apparaît en gros pour l'équipe en tête (GDD 2.10).
class _CardTallyOverlay extends StatefulWidget {
  final int countA;
  final int countB;

  const _CardTallyOverlay({required this.countA, required this.countB});

  @override
  State<_CardTallyOverlay> createState() => _CardTallyOverlayState();
}

class _CardTallyOverlayState extends State<_CardTallyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kCardTallyDuration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppStrings>();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final veil = t < 0.1 ? t / 0.1 : (t < 0.9 ? 1.0 : 1 - (t - 0.9) / 0.1);
        // Les compteurs montent sur les 65% premiers, la différence pop ensuite.
        final countT = Curves.easeOutCubic.transform((t / 0.65).clamp(0.0, 1.0));
        final shownA = (widget.countA * countT).round();
        final shownB = (widget.countB * countT).round();
        final revealDiff = t > 0.68;
        final diffT = Curves.elasticOut.transform(((t - 0.68) / 0.32).clamp(0.0, 1.0));

        // Points de butin = ce qui DÉPASSE 20 pour l'équipe au-dessus (GDD 2.10) :
        // 26 cartes -> +6 pts, l'autre équipe ne perd rien. Pas la différence brute.
        // À 20-20 il n'y a PAS de leader : on n'affiche aucune équipe (le serveur
        // n'attribue de butin qu'au-dessus de 20, strict) — badge doré neutre.
        final isTie = widget.countA == widget.countB;
        final leader = widget.countA > widget.countB ? 'A' : 'B';
        final leaderCount = leader == 'A' ? widget.countA : widget.countB;
        final butin = isTie ? 0 : (leaderCount - 20).clamp(0, 20);
        final badgeTop = isTie ? RondaColors.goldLight : RondaColors.teamLight(leader);
        final badgeBottom = isTie ? RondaColors.gold : RondaColors.team(leader);

        return Container(
          color: Colors.black.withValues(alpha: (veil * 0.72).clamp(0, 1)),
          child: Center(
            child: Opacity(
              opacity: veil.clamp(0, 1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _JuicyText(label: strings.t('overlay.tallyTitle'), sub: '', fontSize: 30),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _TeamTally(team: 'A', count: shownA, maxCount: 40, strings: strings),
                      const SizedBox(width: 30),
                      _TeamTally(team: 'B', count: shownB, maxCount: 40, strings: strings),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Différence : « +N pour l'équipe en tête », en gros à la fin.
                  Opacity(
                    opacity: revealDiff ? 1.0 : 0.0,
                    child: Transform.scale(
                      scale: revealDiff ? diffT : 0.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [badgeTop, badgeBottom]),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: RondaColors.cream.withValues(alpha: 0.8), width: 2),
                          boxShadow: [
                            BoxShadow(color: badgeBottom.withValues(alpha: 0.6), blurRadius: 16),
                          ],
                        ),
                        child: Text(
                          isTie
                              ? strings.t('overlay.tallyTie')
                              : strings.t('overlay.tallyResult', {'n': butin, 'letter': leader}),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: RondaColors.cream,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Colonne d'une équipe dans le décompte : pile de cartes proportionnelle au
/// nombre ramassé, gros compteur, badge d'équipe.
class _TeamTally extends StatelessWidget {
  final String team;
  final int count;
  final int maxCount;
  final AppStrings strings;

  const _TeamTally({
    required this.team,
    required this.count,
    required this.maxCount,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    // Hauteur de pile proportionnelle (bornée) : ~0 à 120px sur 40 cartes.
    final fill = (count / maxCount).clamp(0.0, 1.0);
    final stackCards = (count / 4).ceil().clamp(0, 10); // une carte dessinée / 4 ramassées

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 124,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              for (var i = 0; i < stackCards; i++)
                Positioned(
                  bottom: i * 11.0,
                  child: Transform.rotate(
                    angle: ((i * 37) % 9 - 4) * 0.012,
                    child: Container(
                      width: 46,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [RondaColors.teamLight(team), RondaColors.team(team)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: RondaColors.cream.withValues(alpha: 0.7), width: 1),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 2, offset: const Offset(0, 1)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Gros compteur de cartes.
        Container(
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RondaColors.teamLight(team), width: 2),
          ),
          child: Column(
            children: [
              Text(
                strings.t('overlay.teamAbbrev', {'letter': team}),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: RondaColors.teamLight(team),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: RondaColors.cream,
                  shadows: [
                    Shadow(color: RondaColors.team(team).withValues(alpha: 0.9), blurRadius: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Barre de remplissage sous le compteur.
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 62,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fill,
            child: Container(
              decoration: BoxDecoration(
                color: RondaColors.teamLight(team),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _LastCaptureKind { king, ace, leadMissed }

/// Animation dédiée à la fin du ter7 : Roi = triomphe doré,
/// As = douche froide bleutée, Lead qui rate la dernière prise = MAJEBTICH.
class _LastCaptureOverlay extends StatefulWidget {
  final _LastCaptureKind kind;
  final String team;

  const _LastCaptureOverlay({required this.kind, required this.team});

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
    final strings = context.watch<AppStrings>();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final veil = t < 0.15 ? t / 0.15 : (t < 0.85 ? 1.0 : 1 - (t - 0.85) / 0.15);
        final scale = Curves.elasticOut.transform(math.min(1, t * 1.8));

        if (widget.kind == _LastCaptureKind.king) {
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
                          label: strings.t('overlay.royalCapture'),
                          sub: strings.t('overlay.royalCaptureSub', {'letter': widget.team}),
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

        // Déception (As ou Lead qui rate la dernière prise) : voile froid,
        // pluie triste, texte qui s'affaisse.
        final isAce = widget.kind == _LastCaptureKind.ace;
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
                        child: Icon(
                          isAce
                              ? Icons.heart_broken_rounded
                              : Icons.sentiment_very_dissatisfied_rounded,
                          size: 74,
                          color: const Color(0xFF9FB4CC),
                          shadows: const [Shadow(color: Colors.black87, blurRadius: 14)],
                        ),
                      ),
                      _JuicyText(
                        label: isAce
                            ? strings.t('overlay.aceOuch')
                            : strings.t('overlay.majebtich').replaceFirst(' ', '\n'),
                        sub: isAce
                            ? strings.t('overlay.aceSub')
                            : strings.t('overlay.majebtichSub'),
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
