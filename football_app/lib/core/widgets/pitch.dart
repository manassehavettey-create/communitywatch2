import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Pitch markings. [vertical] pitches run bottom (home goal) → top.
class PitchPainter extends CustomPainter {
  PitchPainter({required this.line, this.fill, this.vertical = true, this.stripe});
  final Color line;
  final Color? fill;
  final Color? stripe;
  final bool vertical;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    if (fill != null) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(Radii.lg)), Paint()..color = fill!);
    }
    canvas.save();
    if (!vertical) {
      canvas.translate(size.width, 0);
      canvas.rotate(math.pi / 2);
    }
    final w = vertical ? size.width : size.height;
    final h = vertical ? size.height : size.width;
    if (stripe != null) {
      final sp = Paint()..color = stripe!;
      final band = h / 12;
      for (var i = 0; i < 12; i += 2) {
        canvas.drawRect(Rect.fromLTWH(0, i * band, w, band), sp);
      }
    }
    final p = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final m = w * 0.04;
    final field = Rect.fromLTRB(m, m, w - m, h - m);
    canvas.drawRect(field, p);
    canvas.drawLine(Offset(field.left, h / 2), Offset(field.right, h / 2), p);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.13, p);
    canvas.drawCircle(Offset(w / 2, h / 2), 2, p..style = PaintingStyle.fill);
    p.style = PaintingStyle.stroke;
    for (final top in [true, false]) {
      final y0 = top ? field.top : field.bottom;
      final dir = top ? 1.0 : -1.0;
      final boxW = field.width * 0.58, boxH = field.height * 0.16;
      final sixW = field.width * 0.27, sixH = field.height * 0.055;
      canvas.drawRect(Rect.fromLTWH(w / 2 - boxW / 2, top ? y0 : y0 - boxH, boxW, boxH), p);
      canvas.drawRect(Rect.fromLTWH(w / 2 - sixW / 2, top ? y0 : y0 - sixH, sixW, sixH), p);
      final spot = Offset(w / 2, y0 + dir * field.height * 0.11);
      canvas.drawCircle(spot, 1.8, Paint()..color = line);
      canvas.drawArc(Rect.fromCircle(center: spot, radius: w * 0.13), top ? 0.2 * math.pi : 1.2 * math.pi, 0.6 * math.pi, false, p);
      final goalW = field.width * 0.12;
      canvas.drawRect(Rect.fromLTWH(w / 2 - goalW / 2, top ? y0 - m * 0.5 : y0, goalW, m * 0.5), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PitchPainter old) => old.line != line || old.fill != fill || old.vertical != vertical;
}

/// Designed art used when a generated image asset is missing: dark gradient,
/// faint pitch geometry and a lime glow. Never a grey placeholder box.
class FallbackArt extends StatelessWidget {
  const FallbackArt({super.key, this.glow = const Alignment(0.6, -0.6)});
  final Alignment glow;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(center: glow, radius: 1.2, colors: [Color.lerp(c.accent, c.bg, 0.78)!, c.bg]),
      ),
      child: CustomPaint(painter: PitchPainter(line: c.accent.withValues(alpha: 0.18)), child: const SizedBox.expand()),
    );
  }
}

/// Asset image with a graceful designed fallback.
class ArtImage extends StatelessWidget {
  const ArtImage(this.asset, {super.key, this.fit = BoxFit.cover, this.alignment = Alignment.center});
  final String asset;
  final BoxFit fit;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) => Image.asset(asset, fit: fit, alignment: alignment, gaplessPlayback: true, errorBuilder: (_, _, _) => const FallbackArt());
}

/// Circular rotating text stamp (visual language borrowed from the art
/// reference, used on onboarding and share cards).
class StampBadge extends StatefulWidget {
  const StampBadge({super.key, required this.text, this.size = 92, this.center, this.color, this.textColor, this.spin = true});
  final String text;
  final double size;
  final Widget? center;
  final Color? color;
  final Color? textColor;
  final bool spin;
  @override
  State<StampBadge> createState() => _StampBadgeState();
}

class _StampBadgeState extends State<StampBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 18));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.spin && !context.reduceMotion) {
      _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = widget.color ?? c.away;
    final fg = widget.textColor ?? c.onAccent;
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(alignment: Alignment.center, children: [
        Container(decoration: BoxDecoration(shape: BoxShape.circle, color: bg)),
        RotationTransition(turns: _c, child: CustomPaint(size: Size.square(widget.size), painter: _CircleTextPainter(widget.text, AppType.overline(color: fg, size: widget.size * 0.105)))),
        ?widget.center,
      ]),
    );
  }
}

class _CircleTextPainter extends CustomPainter {
  _CircleTextPainter(this.text, this.style);
  final String text;
  final TextStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2 - style.fontSize! * 1.1;
    final chars = text.toUpperCase().split('');
    final step = 2 * math.pi / chars.length;
    canvas.translate(size.width / 2, size.height / 2);
    for (var i = 0; i < chars.length; i++) {
      final tp = TextPainter(text: TextSpan(text: chars[i], style: style), textDirection: TextDirection.ltr)..layout();
      canvas.save();
      canvas.rotate(i * step);
      canvas.translate(-tp.width / 2, -radius - tp.height / 2);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CircleTextPainter old) => old.text != text;
}
