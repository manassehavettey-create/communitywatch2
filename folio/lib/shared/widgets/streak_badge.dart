import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// Circular running text ("READING STREAK · 12 DAYS ·") around a big number.
/// Rotates slowly; static when reduce-motion is on.
class StreakBadge extends StatefulWidget {
  const StreakBadge({super.key, required this.days, this.size = 112, this.color, this.textColor});
  final int days;
  final double size;
  final Color? color;
  final Color? textColor;

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.of(context).reduced) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fill = widget.color ?? c.lime;
    final ink = widget.textColor ?? const Color(0xFF161514);
    final label = 'READING STREAK · ${widget.days} ${widget.days == 1 ? 'DAY' : 'DAYS'} · ';
    return Semantics(
      label: 'Reading streak: ${widget.days} ${widget.days == 1 ? 'day' : 'days'}',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(decoration: BoxDecoration(color: fill, shape: BoxShape.circle)),
            RotationTransition(
              turns: _spin,
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: _CircleTextPainter(label, ink, widget.size),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: widget.days.toDouble()),
              duration: Motion.of(context).slow * 2,
              curve: Motion.curve,
              builder: (context, v, _) => Text(
                '${v.round()}',
                style: context.text.displayMedium?.copyWith(
                  color: ink,
                  fontSize: widget.size * 0.34,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleTextPainter extends CustomPainter {
  _CircleTextPainter(this.text, this.color, this.size);
  final String text;
  final Color color;
  final double size;

  @override
  void paint(Canvas canvas, Size s) {
    final radius = s.width / 2 - size * 0.1;
    final center = s.center(Offset.zero);
    final style = withWeight(
      TextStyle(fontFamily: Fonts.ui, fontSize: size * 0.085, color: color, letterSpacing: 1),
      800,
    );
    // Repeat the label to fill the circumference.
    final circumference = 2 * math.pi * radius;
    final one = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)
      ..layout();
    final reps = math.max(1, (circumference / one.width).floor());
    final full = List.filled(reps, text).join();
    final charAngle = 2 * math.pi / full.length;
    var angle = -math.pi / 2;
    for (final ch in full.characters) {
      final tp = TextPainter(text: TextSpan(text: ch, style: style), textDirection: TextDirection.ltr)
        ..layout();
      canvas.save();
      canvas.translate(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      canvas.rotate(angle + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      angle += charAngle;
    }
  }

  @override
  bool shouldRepaint(_CircleTextPainter old) => old.text != text || old.color != color;
}
