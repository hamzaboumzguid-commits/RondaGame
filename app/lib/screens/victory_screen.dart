import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../net/game_client.dart';
import '../theme.dart';

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
    final myTeam = client.me?.team;
    final iWon = myTeam == widget.winningTeam;
    final scores = client.state?.scores ?? {};

    return Scaffold(
      body: ZelligeBackground(
        baseColor: iWon ? RondaColors.greenDeep : RondaColors.wood,
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
                    Icon(
                      iWon ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                      size: 96,
                      color: iWon ? RondaColors.gold : RondaColors.creamDark,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      iWon ? 'VICTOIRE !' : 'DÉFAITE',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                        color: iWon ? RondaColors.gold : RondaColors.creamDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'L\'équipe ${widget.winningTeam} remporte la partie',
                      style: const TextStyle(fontSize: 18, color: RondaColors.cream),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${scores['A'] ?? 0}  —  ${scores['B'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: RondaColors.cream,
                      ),
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: () {
                        context.read<GameClient>().leaveRoom();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text('RETOUR À L\'ACCUEIL'),
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
