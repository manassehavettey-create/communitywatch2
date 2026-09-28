import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import 'figure_demos.dart';
import 'figure_rig.dart';

/// Looping, code-drawn demonstration of an exercise (no video or image
/// needed). Under reduced motion it shows the start pose with the end pose
/// ghosted, so the movement is still readable.
class ExerciseFigure extends StatefulWidget {
  const ExerciseFigure({
    super.key,
    required this.demo,
    this.color = const Color(0xFF111113),
    this.farColor,
    this.propColor,
    this.floorColor,
    this.playing = true,
    this.speed = 1.0,
  });

  /// Demo key from the exercise catalog.
  final String demo;
  final Color color;
  final Color? farColor;
  final Color? propColor;
  final Color? floorColor;
  final bool playing;
  final double speed;

  @override
  State<ExerciseFigure> createState() => _ExerciseFigureState();
}

class _ExerciseFigureState extends State<ExerciseFigure> with SingleTickerProviderStateMixin {
  late Demo _demo = demoFor(widget.demo);
  late final AnimationController _c = AnimationController(vsync: this, duration: _period());

  Duration _period() => Duration(milliseconds: (_demo.period.inMilliseconds / widget.speed).round());

  @override
  void didUpdateWidget(ExerciseFigure old) {
    super.didUpdateWidget(old);
    if (old.demo != widget.demo || old.speed != widget.speed) {
      _demo = demoFor(widget.demo);
      _c.duration = _period();
      _sync();
    } else if (old.playing != widget.playing) {
      _sync();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    if (widget.playing && !Motion.reduced(context)) {
      if (!_c.isAnimating) _c.repeat();
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
    final reduced = Motion.reduced(context);
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: Rig.stageW,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _FigurePainter(
              demo: _demo,
              t: reduced ? 0 : _c.value,
              ghost: reduced,
              color: widget.color,
              farColor: widget.farColor ?? widget.color.withValues(alpha: _demo.front ? 1 : 0.55),
              propColor: widget.propColor ?? widget.color.withValues(alpha: 0.14),
              floorColor: widget.floorColor ?? widget.color.withValues(alpha: 0.18),
            ),
          ),
        ),
      ),
    );
  }
}

class _FigurePainter extends CustomPainter {
  _FigurePainter({
    required this.demo,
    required this.t,
    required this.ghost,
    required this.color,
    required this.farColor,
    required this.propColor,
    required this.floorColor,
  });

  final Demo demo;
  final double t;
  final bool ghost;
  final Color color;
  final Color farColor;
  final Color propColor;
  final Color floorColor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / Rig.stageW;
    canvas.save();
    canvas.scale(s);

    // Floor.
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0.08, Rig.floor, Rig.stageW - 0.16, 0.012), const Radius.circular(0.01)),
      Paint()..color = floorColor,
    );
    // Wall.
    final wx = demo.wallX;
    if (wx != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(wx, 0.0, 0.03, Rig.floor), const Radius.circular(0.01)),
        Paint()..color = propColor,
      );
    }
    // Furniture / towel.
    for (final p in demo.props) {
      final paint = Paint()..color = propColor;
      canvas.drawRRect(RRect.fromRectAndRadius(p.rect, Radius.circular(p.kind == PropKind.box ? 0.035 : 0.01)), paint);
    }

    if (ghost && demo.poses.length > 1) {
      _drawFigure(canvas, Skeleton.solve(demo.poses[demo.poses.length > 2 ? 1 : 1]), color.withValues(alpha: 0.18),
          farColor.withValues(alpha: 0.12));
    }
    _drawFigure(canvas, Skeleton.solve(demo.at(t)), color, farColor);
    canvas.restore();
  }

  void _limb(Canvas c, Offset a, Offset b, Offset d, double w, Color col) {
    final p = Paint()
      ..color = col
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(d.dx, d.dy);
    c.drawPath(path, p);
  }

  Offset _foot(Offset knee, Offset ankle) {
    // Toe points "forward" relative to the shin (perpendicular), for a side view.
    final v = ankle - knee;
    final len = v.distance == 0 ? 1.0 : v.distance;
    var perp = Offset(-v.dy, v.dx) / len;
    if (perp.dx < 0 && !demo.front) perp = -perp;
    if (demo.front) perp = Offset(0, 0.4) + Offset(v.dx.sign * 0.4, 0);
    return ankle + perp * 0.06;
  }

  void _drawFigure(Canvas canvas, Skeleton k, Color near, Color far) {
    const limbW = 0.052;
    const torsoW = 0.085;

    // Far side first.
    _limb(canvas, k.hip, k.fKnee, k.fAnkle, limbW, far);
    _limb(canvas, k.fAnkle, k.fAnkle, _foot(k.fKnee, k.fAnkle), limbW * 0.8, far);
    _limb(canvas, k.shoulder, k.fElbow, k.fHand, limbW * 0.9, far);
    canvas.drawCircle(k.fHand, 0.024, Paint()..color = far);

    // Torso (optionally curved spine).
    final mid = Offset.lerp(k.hip, k.shoulder, 0.5)!;
    final dir = k.shoulder - k.hip;
    final normal = Offset(-dir.dy, dir.dx) / (dir.distance == 0 ? 1 : dir.distance);
    final ctrl = mid + normal * (-k.curve);
    final torso = Path()
      ..moveTo(k.hip.dx, k.hip.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, k.shoulder.dx, k.shoulder.dy)
      ..lineTo(k.neckTop.dx, k.neckTop.dy);
    canvas.drawPath(
      torso,
      Paint()
        ..color = near
        ..strokeWidth = torsoW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(k.head, Rig.headR, Paint()..color = near);

    // Near side on top.
    _limb(canvas, k.hip, k.nKnee, k.nAnkle, limbW * 1.05, near);
    _limb(canvas, k.nAnkle, k.nAnkle, _foot(k.nKnee, k.nAnkle), limbW * 0.85, near);
    _limb(canvas, k.shoulder, k.nElbow, k.nHand, limbW, near);
    canvas.drawCircle(k.nHand, 0.026, Paint()..color = near);
  }

  @override
  bool shouldRepaint(_FigurePainter o) => o.t != t || o.demo != demo || o.color != color || o.ghost != ghost;
}
