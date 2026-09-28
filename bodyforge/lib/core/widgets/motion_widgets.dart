import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../motion/motion.dart';
import '../theme/bf_colors.dart';
import '../theme/typography.dart';

/// Global haptics switch (mirrors Settings → Haptics).
abstract final class Haptics {
  static bool enabled = true;
  static void tap() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}

/// Scale-on-press wrapper with haptics and an ink ripple.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.scale = Motion.pressScale,
    this.haptic = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _down && !reduced ? widget.scale : 1,
        duration: Motion.fast,
        curve: Motion.standard,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: widget.borderRadius,
            onTapDown: (_) => _set(true),
            onTapCancel: () => _set(false),
            onTapUp: (_) => _set(false),
            onTap: widget.onTap == null
                ? null
                : () {
                    if (widget.haptic) Haptics.tap();
                    widget.onTap!();
                  },
            onLongPress: widget.onLongPress,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

extension EnterAnimation on Widget {
  /// Staggered entrance: fade + slight rise. Collapses to a quick fade when
  /// the user prefers reduced motion.
  Widget enter(BuildContext context, {int index = 0, Duration base = Duration.zero, double rise = 18}) {
    if (Motion.reduced(context)) {
      return animate().fadeIn(duration: Motion.instant);
    }
    return animate(delay: Motion.stagger(index, base: base))
        .fadeIn(duration: Motion.slow, curve: Motion.standard)
        .moveY(begin: rise, end: 0, duration: Motion.slow, curve: Motion.emphasized);
  }

  /// Pop-in used for badges and celebratory elements.
  Widget pop(BuildContext context, {Duration delay = Duration.zero}) {
    if (Motion.reduced(context)) return animate().fadeIn(duration: Motion.instant);
    return animate(delay: delay)
        .fadeIn(duration: Motion.medium)
        .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), duration: Motion.slower, curve: Motion.gentleSpring);
  }
}

/// A number that counts up to [value] the first time it's shown (and animates
/// between values after that).
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
    this.duration = Motion.countUp,
    this.formatter,
  });

  final double value;
  final TextStyle? style;
  final int decimals;
  final String prefix;
  final String suffix;
  final Duration duration;
  final String Function(double v)? formatter;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: Motion.of(context, duration),
      curve: Motion.decelerate,
      builder: (context, v, _) => Text(
        formatter?.call(v) ?? '$prefix${v.toStringAsFixed(decimals)}$suffix',
        style: style,
      ),
    );
  }
}

/// Gapped progress ring, animated from 0 to [progress]. Optional gradient
/// (lime → ember) as in the reference "Total calories" ring.
class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.progress,
    this.size = 120,
    this.stroke = 12,
    this.color,
    this.track,
    this.gradient,
    this.child,
    this.gapDegrees = 0,
    this.duration = Motion.chartDraw,
  });

  final double progress;
  final double size;
  final double stroke;
  final Color? color;
  final Color? track;
  final List<Color>? gradient;
  final Widget? child;
  final double gapDegrees;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0, 1)),
      duration: Motion.of(context, duration),
      curve: Motion.emphasized,
      builder: (context, v, child) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: v,
            stroke: stroke,
            color: color ?? c.primary,
            track: track ?? c.surfaceRaised,
            gradient: gradient,
            gap: gapDegrees,
          ),
          child: Center(child: child),
        ),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.stroke,
    required this.color,
    required this.track,
    required this.gap,
    this.gradient,
  });

  final double progress;
  final double stroke;
  final Color color;
  final Color track;
  final List<Color>? gradient;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final gapRad = gap * math.pi / 180;
    final start = -math.pi / 2 + gapRad / 2;
    final sweepAll = 2 * math.pi - gapRad;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(r, start, sweepAll, false, base);
    if (progress <= 0) return;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (gradient != null) {
      p.shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: gradient!,
        transform: GradientRotation(start),
      ).createShader(r);
    } else {
      p.color = color;
    }
    canvas.drawArc(r, start, sweepAll * progress, false, p);
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.progress != progress || o.color != color || o.track != track || o.stroke != stroke;
}

/// The concentric-ring texture from the reference cards.
class ConcentricRings extends StatelessWidget {
  const ConcentricRings({super.key, this.color, this.alignment = const Alignment(1.1, -0.2), this.rings = 6, this.animate = false});
  final Color? color;
  final Alignment alignment;
  final int rings;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final col = color ?? Colors.black.withValues(alpha: 0.07);
    if (!animate || Motion.reduced(context)) {
      return CustomPaint(painter: _RingsPainter(col, alignment, rings, 0));
    }
    return _AnimatedRings(color: col, alignment: alignment, rings: rings);
  }
}

class _AnimatedRings extends StatefulWidget {
  const _AnimatedRings({required this.color, required this.alignment, required this.rings});
  final Color color;
  final Alignment alignment;
  final int rings;
  @override
  State<_AnimatedRings> createState() => _AnimatedRingsState();
}

class _AnimatedRingsState extends State<_AnimatedRings> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(painter: _RingsPainter(widget.color, widget.alignment, widget.rings, _c.value)),
        ),
      );
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.color, this.alignment, this.rings, this.phase);
  final Color color;
  final Alignment alignment;
  final int rings;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = alignment.alongSize(size);
    final maxR = size.longestSide * 0.9;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color;
    for (var i = 0; i < rings; i++) {
      final t = ((i + phase) / rings);
      canvas.drawCircle(center, maxR * t + 24, p);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter o) => o.phase != phase || o.color != color;
}

/// Tasteful particle burst (confetti) for PRs, achievements and completion.
/// Skipped entirely under reduced motion.
class ParticleBurst extends StatefulWidget {
  const ParticleBurst({super.key, this.colors, this.count = 42, this.duration = Motion.celebration, this.origin = const Alignment(0, -0.2)});
  final List<Color>? colors;
  final int count;
  final Duration duration;
  final Alignment origin;

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _Particle {
  _Particle(this.angle, this.speed, this.size, this.color, this.spin, this.shape);
  final double angle, speed, size, spin;
  final Color color;
  final int shape;
}

class _ParticleBurstState extends State<ParticleBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late List<_Particle> _parts;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    final cols = widget.colors ?? const [Color(0xFFD4F55A), Color(0xFFA99BF7), Color(0xFFFF9A3C), Color(0xFFF7F7F2)];
    _parts = [
      for (var i = 0; i < widget.count; i++)
        _Particle(
          rnd.nextDouble() * 2 * math.pi,
          0.35 + rnd.nextDouble() * 0.65,
          4 + rnd.nextDouble() * 6,
          cols[i % cols.length],
          (rnd.nextDouble() - 0.5) * 12,
          i % 3,
        )
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !Motion.reduced(context)) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(
            size: Size.infinite,
            painter: _BurstPainter(_parts, _c.value, widget.origin),
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.parts, this.t, this.origin);
  final List<_Particle> parts;
  final double t;
  final Alignment origin;

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    final o = origin.alongSize(size);
    final ease = Curves.easeOutCubic.transform(t);
    final reach = size.shortestSide * 0.62;
    for (final p in parts) {
      final d = reach * p.speed * ease;
      final gravity = 180 * t * t;
      final pos = o + Offset(math.cos(p.angle) * d, math.sin(p.angle) * d + gravity);
      final paint = Paint()..color = p.color.withValues(alpha: (1 - t).clamp(0, 1));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      switch (p.shape) {
        case 0:
          canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size * 1.6, height: p.size * 0.7),
                  const Radius.circular(2)),
              paint);
        case 1:
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
        default:
          final path = Path()
            ..moveTo(0, -p.size / 2)
            ..lineTo(p.size / 2, p.size / 2)
            ..lineTo(-p.size / 2, p.size / 2)
            ..close();
          canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter o) => o.t != t;
}

/// Soft glow behind hero badges.
class Glow extends StatelessWidget {
  const Glow({super.key, required this.color, required this.child, this.radius = 80, this.pulse = true});
  final Color color;
  final Widget child;
  final double radius;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    Widget glow = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)]),
      ),
    );
    if (pulse && !Motion.reduced(context)) {
      glow = glow
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.08, 1.08), duration: 1400.ms, curve: Curves.easeInOut);
    }
    return Stack(alignment: Alignment.center, children: [glow, child]);
  }
}

/// Big ticking number used for timers (tabular figures, no jitter).
class BigNumber extends StatelessWidget {
  const BigNumber(this.text, {super.key, this.size = 64, this.color});
  final String text;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(text, style: BfType.number(size, color: color ?? context.bf.text));
}

/// [AnimatedSize] that becomes a plain child under reduced motion (a
/// zero-duration AnimatedSize trips a layout assertion).
class MotionSize extends StatelessWidget {
  const MotionSize({super.key, required this.child, this.duration = Motion.medium, this.curve = Motion.emphasized});
  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return AnimatedSize(duration: duration, curve: curve, child: child);
  }
}
