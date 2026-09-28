import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';

/// Rounded progress bar that animates to its value.
class FolioProgressBar extends StatelessWidget {
  const FolioProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
    this.track,
  });

  final double value;
  final double height;
  final Color? color;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = Motion.of(context);
    return Semantics(
      value: '${(value * 100).round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: m.slow * 2,
        curve: Motion.emphasized,
        builder: (context, v, _) => Container(
          height: height,
          decoration: BoxDecoration(color: track ?? c.surfaceMuted, borderRadius: Radii.pillAll),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            child: Container(
              decoration: BoxDecoration(color: color ?? c.lime, borderRadius: Radii.pillAll),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ring used for the daily goal and session timer.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.size,
    this.stroke = 10,
    this.color,
    this.track,
    this.child,
    this.animate = true,
  });

  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Color? track;
  final Widget? child;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = Motion.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate ? 0 : value, end: value.clamp(0.0, 1.0)),
      duration: animate ? m.slow * 2 : Duration.zero,
      curve: Motion.emphasized,
      builder: (context, v, child) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(v, stroke, color ?? c.lime, track ?? c.surfaceMuted),
          child: Center(child: child),
        ),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.stroke, this.color, this.track);
  final double v;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    if (v > 0) canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.v != v || old.color != color || old.track != track || old.stroke != stroke;
}

/// Counts up from 0 to [value] once.
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, this.style, this.suffix = ''});
  final int value;
  final TextStyle? style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: m.slow * 2,
      curve: Motion.curve,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}
