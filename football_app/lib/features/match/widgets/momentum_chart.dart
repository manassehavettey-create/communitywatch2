import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';

/// Momentum timeline (spec §9): area above the axis = home pressure (lime),
/// below = away (violet). Events are pinned on the edges. Draws in on first
/// view; new minutes glide in as live data arrives.
class MomentumChart extends StatefulWidget {
  const MomentumChart({super.key, required this.points, required this.match, this.shots = const [], this.height = 150});
  final List<MomentumPoint> points;
  final Match match;
  final List<ShotEvent> shots;
  final double height;

  @override
  State<MomentumChart> createState() => _MomentumChartState();
}

class _MomentumChartState extends State<MomentumChart> with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(vsync: this, duration: Motion.draw * 1.4);

  @override
  void initState() {
    super.initState();
    _draw.forward();
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (context.reduceMotion) _draw.value = 1;
    final m = widget.match;
    return Column(children: [
      Row(children: [
        TeamCrest(team: m.home, size: 18),
        const SizedBox(width: 6),
        Text(m.home.short, style: AppType.body(12, weight: 650, color: c.accentInk)),
        const Spacer(),
        Text(m.away.short, style: AppType.body(12, weight: 650, color: c.away)),
        const SizedBox(width: 6),
        TeamCrest(team: m.away, size: 18),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _draw,
          builder: (_, _) => TweenAnimationBuilder<double>(
            tween: Tween(end: widget.points.length.toDouble()),
            duration: Motion.slow,
            curve: Motion.emphasized,
            builder: (_, visible, _) => CustomPaint(
              size: Size.infinite,
              painter: _MomentumPainter(
                points: widget.points,
                visibleCount: visible,
                progress: Motion.emphasized.transform(_draw.value),
                events: m.sortedEvents,
                bigChances: widget.shots.where((s) => (s.xg ?? 0) >= 0.3 && s.outcome != ShotOutcome.goal).toList(),
                homeId: m.home.id,
                colors: c,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final l in ["0'", "45'", "90'"]) Text(l, style: AppType.body(11, color: c.textFaint)),
      ]),
    ]);
  }
}

class _MomentumPainter extends CustomPainter {
  _MomentumPainter({required this.points, required this.visibleCount, required this.progress, required this.events, required this.bigChances, required this.homeId, required this.colors});
  final List<MomentumPoint> points;
  final double visibleCount;
  final double progress;
  final List<MatchEvent> events;
  final List<ShotEvent> bigChances;
  final int homeId;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final maxMin = 94.0;
    double xFor(num minute) => (minute / maxMin).clamp(0, 1) * size.width;
    final amp = mid - 16;

    // Axis + half-time marker.
    final axis = Paint()
      ..color = colors.hairline
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), axis);
    final ht = xFor(46);
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawLine(Offset(ht, y), Offset(ht, y + 3), axis);
    }
    if (points.isEmpty) return;

    final n = visibleCount.floor().clamp(1, points.length);
    final pts = points.take(n).toList();
    final clipW = xFor(pts.last.minute) * progress;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, clipW + 1, size.height));

    // Bars look crisper than a smoothed area for minute-by-minute data.
    final barW = (size.width / maxMin) * 0.72;
    for (final p in pts) {
      final v = p.value / 100;
      final h = v.abs() * amp;
      if (h < 0.5) continue;
      final x = xFor(p.minute);
      final rect = v > 0 ? Rect.fromLTWH(x - barW / 2, mid - h, barW, h) : Rect.fromLTWH(x - barW / 2, mid, barW, h);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(barW / 2)), Paint()..color = (v > 0 ? colors.accent : colors.away).withValues(alpha: 0.35 + 0.65 * v.abs()));
    }
    canvas.restore();

    // Event pins.
    for (final e in events) {
      if (!(e.isGoal || e.isRed || e.kind == EventKind.yellow || e.kind == EventKind.sub)) continue;
      final x = xFor(e.minute + (e.minute > 45 ? 2 : 0) + (e.extra ?? 0));
      if (x > clipW + 1) continue;
      final top = e.teamId == homeId;
      final y = top ? 6.0 : size.height - 6;
      if (e.isGoal) {
        canvas.drawCircle(Offset(x, y), 5.5, Paint()..color = colors.text);
        canvas.drawCircle(Offset(x, y), 2.4, Paint()..color = colors.bg);
        canvas.drawLine(Offset(x, top ? y + 6 : y - 6), Offset(x, mid), Paint()
          ..color = colors.text.withValues(alpha: 0.35)
          ..strokeWidth = 1);
      } else if (e.isCard) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 5, height: 8), const Radius.circular(1)), Paint()..color = e.isRed ? colors.redCard : colors.yellowCard);
      } else {
        final p = Path()
          ..moveTo(x, y - 3.5)
          ..lineTo(x + 3.5, y + 2.5)
          ..lineTo(x - 3.5, y + 2.5)
          ..close();
        canvas.drawPath(p, Paint()..color = colors.mint.withValues(alpha: 0.8));
      }
    }
    for (final s in bigChances) {
      final x = xFor(s.minute + (s.minute > 45 ? 2 : 0));
      if (x > clipW + 1) continue;
      final top = s.teamId == homeId;
      canvas.drawCircle(Offset(x, top ? 16 : size.height - 16), 3, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = colors.text.withValues(alpha: 0.6));
    }
  }

  @override
  bool shouldRepaint(_MomentumPainter old) => old.progress != progress || old.visibleCount != visibleCount || old.points != points || old.events != events;
}

class MomentumLegend extends StatelessWidget {
  const MomentumLegend({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget item(Widget icon, String label) => Row(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(width: 5), Text(label, style: AppType.body(11.5, color: c.textMuted))]);
    return Wrap(spacing: 14, runSpacing: 6, children: [
      item(Icon(Icons.circle, size: 10, color: c.text), 'Goal'),
      item(const CardChip(red: false, size: 10), 'Card'),
      item(Icon(Icons.change_history_rounded, size: 11, color: c.mint), 'Sub'),
      item(Icon(Icons.circle_outlined, size: 10, color: c.textMuted), 'Big chance'),
    ]);
  }
}
