import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A scalloped badge outline (DESIGN.md → Stickers).
class ScallopBorder extends OutlinedBorder {
  const ScallopBorder({this.lobes = 12, this.depth = 0.08, super.side});

  final int lobes;

  /// Lobe depth as a fraction of the radius.
  final double depth;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final c = rect.center;
    final r = rect.shortestSide / 2;
    final inner = r * (1 - depth);
    final path = Path();
    const steps = 240;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * 2 * math.pi;
      // Smooth lobes: radius oscillates with a raised cosine.
      final rr = inner + (r - inner) * (0.5 + 0.5 * math.cos(t * lobes));
      final pt = Offset(c.dx + rr * math.cos(t), c.dy + rr * math.sin(t));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(getOuterPath(rect), side.toPaint());
  }

  @override
  ScallopBorder scale(double t) =>
      ScallopBorder(lobes: lobes, depth: depth, side: side.scale(t));

  @override
  ScallopBorder copyWith({BorderSide? side}) =>
      ScallopBorder(lobes: lobes, depth: depth, side: side ?? this.side);
}

/// A soft organic blob, used behind illustrations and empty states.
class BlobBorder extends OutlinedBorder {
  const BlobBorder({this.seed = 0, super.side});

  final int seed;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final rnd = math.Random(seed);
    final c = rect.center;
    final rx = rect.width / 2, ry = rect.height / 2;
    const n = 6;
    final pts = List.generate(n, (i) {
      final a = i / n * 2 * math.pi + seed * 0.4;
      final k = 0.84 + rnd.nextDouble() * 0.16;
      return Offset(c.dx + rx * k * math.cos(a), c.dy + ry * k * math.sin(a));
    });
    // Closed Catmull-Rom spline through the points.
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < n; i++) {
      final p0 = pts[(i - 1 + n) % n], p1 = pts[i];
      final p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  BlobBorder scale(double t) => BlobBorder(seed: seed, side: side.scale(t));

  @override
  BlobBorder copyWith({BorderSide? side}) =>
      BlobBorder(seed: seed, side: side ?? this.side);
}

/// Scalloped sticker with centred content (streak count, date, badges).
class Sticker extends StatelessWidget {
  const Sticker({
    super.key,
    required this.color,
    required this.child,
    this.size = 72,
    this.rotation = -0.08,
  });

  final Color color;
  final Widget child;
  final double size;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: ShapeDecoration(color: color, shape: const ScallopBorder()),
        child: Transform.rotate(angle: -rotation, child: child),
      ),
    );
  }
}
