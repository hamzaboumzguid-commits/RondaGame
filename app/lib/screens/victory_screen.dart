import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../net/game_client.dart';
import '../theme.dart';
import '../widgets/chunky_button.dart';

class VictoryScreen extends StatefulWidget {
  final String winningTeam;

  const VictoryScreen({super.key, required this.winningTeam});

  @override
  State<VictoryScreen> createState() => _VictoryScreenState();
}

class _VictoryScreenState extends State<VictoryScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = context.watch<GameClient>();
    final strings = context.watch<AppStrings>();
    final myTeam = client.me?.team;
    final iWon = myTeam == widget.winningTeam;
    final scores = client.state?.scores ?? {};

    return Scaffold(
      body: IllustratedBackground(
        asset: 'assets/ui/home_bg.png',
        dim: iWon ? 0.25 : 0.55,
        child: SafeArea(
          child: Stack(
            children: [
              if (iWon)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => CustomPaint(
                      painter: _ConfettiPainter(progress: _controller.value),
                    ),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.elasticOut,
                      builder: (_, t, child) => Transform.scale(scale: t, child: child),
                      child: Icon(
                        iWon ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                        size: 100,
                        color: iWon ? RondaColors.gold : RondaColors.creamDark,
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 16)],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      iWon ? strings.t('victory.win') : strings.t('victory.loss'),
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                        color: iWon ? RondaColors.goldLight : RondaColors.creamDark,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 3)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ChunkyPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                      child: Column(
                        children: [
                          Text(
                            strings.t('victory.teamWins', {'team': widget.winningTeam}),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4A2E15),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${scores['A'] ?? 0}  —  ${scores['B'] ?? 0}',
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4A2E15),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 42),
                    SizedBox(
                      width: 280,
                      child: ChunkyButton.red(
                        label: strings.t('victory.playAgain'),
                        icon: Icons.replay_rounded,
                        onPressed: () {
                          context.read<GameClient>().leaveRoom();
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;

  _ConfettiPainter({required this.progress});

  static const _colors = [
    RondaColors.gold,
    RondaColors.goldLight,
    RondaColors.red,
    RondaColors.green,
    RondaColors.cream,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    for (int i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final speed = 0.4 + rng.nextDouble() * 0.6;
      final phase = rng.nextDouble();
      final y = ((progress * speed + phase) % 1.0) * (size.height + 40) - 20;
      final wobble = math.sin((progress * 6 + phase) * math.pi * 2) * 14;
      final color = _colors[i % _colors.length];
      final angle = (progress + phase) * math.pi * 4;

      canvas.save();
      canvas.translate(x + wobble, y);
      canvas.rotate(angle);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 8, height: 5),
        Paint()..color = color.withValues(alpha: 0.85),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
