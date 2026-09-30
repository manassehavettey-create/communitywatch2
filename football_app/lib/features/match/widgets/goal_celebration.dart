import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';

/// Full-bleed goal moment: lime burst, "GOAL" letters springing in, scorer
/// and crest. ~2.6s, tap to dismiss, reduced to a simple fade when the OS
/// asks for less motion. Significant without blocking the screen for long.
class GoalCelebration extends StatefulWidget {
  const GoalCelebration({super.key, required this.team, required this.scorer, required this.minute, required this.score, required this.onDone});
  final TeamRef team;
  final String? scorer;
  final String? minute;
  final String score;
  final VoidCallback onDone;

  @override
  State<GoalCelebration> createState() => _GoalCelebrationState();
}

class _GoalCelebrationState extends State<GoalCelebration> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduce = context.reduceMotion;
    return GestureDetector(
      onTap: widget.onDone,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final fadeOut = t > 0.82 ? 1 - (t - 0.82) / 0.18 : 1.0;
          final enter = Curves.easeOut.transform((t / 0.18).clamp(0, 1));
          return Opacity(
            opacity: (reduce ? 1.0 : enter) * fadeOut,
            child: Stack(fit: StackFit.expand, children: [
              ColoredBox(color: c.bg.withValues(alpha: 0.78)),
              if (!reduce) CustomPaint(painter: _BurstPainter(progress: t, color: c.accent, second: c.mint)),
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Transform.scale(scale: reduce ? 1 : 0.6 + 0.4 * Curves.elasticOut.transform((t / 0.4).clamp(0, 1)), child: TeamCrest(team: widget.team, size: 84)),
                  const SizedBox(height: 18),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < 4; i++)
                      Transform.translate(
                        offset: Offset(0, reduce ? 0 : 40 * (1 - Curves.easeOutBack.transform(((t - 0.05 - i * 0.05) / 0.3).clamp(0, 1)))),
                        child: Opacity(
                          opacity: reduce ? 1 : ((t - 0.05 - i * 0.05) / 0.15).clamp(0, 1),
                          child: Text('GOAL'[i], style: AppType.display(76, weight: 900, width: 125, color: c.accent, spacing: -2, italic: true)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  Opacity(
                    opacity: reduce ? 1 : ((t - 0.3) / 0.2).clamp(0, 1),
                    child: Column(children: [
                      if (widget.scorer != null) Text(widget.scorer!, style: AppType.display(24, color: c.text)),
                      const SizedBox(height: 4),
                      Text([widget.team.name, ?widget.minute].join(' · '), style: AppType.body(15, weight: 600, color: c.textMuted)),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(color: c.surface2, borderRadius: Radii.pillAll),
                        child: Text(widget.score, style: AppType.numeric(20, color: c.text)),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.color, required this.second});
  final double progress;
  final Color color;
  final Color second;
  static final _rand = math.Random(7);
  static final _particles = List.generate(46, (i) => (angle: _rand.nextDouble() * math.pi * 2, speed: 0.45 + _rand.nextDouble() * 0.55, size: 2.0 + _rand.nextDouble() * 5, alt: _rand.nextBool()));

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 30);
    final maxR = size.shortestSide * 0.75;
    // Expanding rings.
    for (var k = 0; k < 2; k++) {
      final p = ((progress - k * 0.08) / 0.5).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      canvas.drawCircle(center, maxR * Curves.easeOut.transform(p), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - p) + 0.5
        ..color = color.withValues(alpha: 0.6 * (1 - p)));
    }
    // Particles.
    final p = Curves.easeOutCubic.transform((progress / 0.7).clamp(0, 1));
    final fade = (1 - (progress - 0.4) / 0.4).clamp(0.0, 1.0);
    for (final q in _particles) {
      final r = maxR * q.speed * p;
      final pos = center + Offset(math.cos(q.angle), math.sin(q.angle)) * r + Offset(0, 60 * p * p);
      canvas.drawCircle(pos, q.size * (1 - 0.4 * p), Paint()..color = (q.alt ? second : color).withValues(alpha: fade));
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}
