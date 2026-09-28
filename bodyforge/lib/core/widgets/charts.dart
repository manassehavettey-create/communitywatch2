import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/bf_colors.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

class ChartPoint {
  const ChartPoint(this.x, this.y, {this.label});

  /// Days since the first point.
  final double x;
  final double y;
  final String? label;
}

/// Line chart that draws itself in from left to right. One series, one
/// accent colour; axes stay quiet so the line carries the story.
class DrawInLineChart extends StatelessWidget {
  const DrawInLineChart({
    super.key,
    required this.points,
    this.color,
    this.height = 180,
    this.formatY,
    this.formatX,
    this.showDots = true,
  });

  final List<ChartPoint> points;
  final Color? color;
  final double height;
  final String Function(double v)? formatY;
  final String Function(double v)? formatX;
  final bool showDots;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final col = color ?? c.primary;
    if (points.isEmpty) return SizedBox(height: height);
    final ys = points.map((p) => p.y);
    var minY = ys.reduce(math.min);
    var maxY = ys.reduce(math.max);
    final pad = math.max((maxY - minY) * 0.2, maxY.abs() * 0.02 + 0.5);
    minY -= pad;
    maxY += pad;
    final maxX = math.max(points.last.x, 1.0);

    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.of(context, Motion.chartDraw),
        curve: Motion.emphasized,
        builder: (context, t, _) {
          final cutoff = maxX * t;
          final visible = [
            for (final p in points)
              if (p.x <= cutoff) FlSpot(p.x, p.y)
          ];
          if (visible.isEmpty) visible.add(FlSpot(points.first.x, points.first.y));
          return LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 3,
                getDrawingHorizontalLine: (_) => FlLine(color: c.outline.withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: (maxY - minY) / 3,
                    getTitlesWidget: (v, meta) => (v == meta.min || v == meta.max)
                        ? const SizedBox.shrink()
                        : Text(formatY?.call(v) ?? v.toStringAsFixed(0), style: BfType.number(10, color: c.textFaint)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: formatX != null,
                    reservedSize: 22,
                    interval: math.max(1, (maxX / 4).roundToDouble()),
                    getTitlesWidget: (v, meta) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(formatX?.call(v) ?? '', style: BfType.number(10, color: c.textFaint)),
                    ),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => c.isDark ? c.sheet : BfPalette.ink,
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(formatY?.call(s.y) ?? s.y.toStringAsFixed(1),
                          BfType.number(13, color: c.isDark ? BfPalette.ink : Colors.white, weight: FontWeight.w700))
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: visible,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  curveSmoothness: 0.25,
                  color: col,
                  barWidth: 3.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: showDots,
                    getDotPainter: (spot, _, _, i) => FlDotCirclePainter(
                      radius: i == visible.length - 1 ? 5 : 2.5,
                      color: col,
                      strokeWidth: i == visible.length - 1 ? 3 : 0,
                      strokeColor: c.canvas,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [col.withValues(alpha: 0.25), col.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ],
            ),
            duration: Duration.zero,
          );
        },
      ),
    );
  }
}

/// Bars that grow up in sequence (weekly workouts etc.).
class GrowBars extends StatelessWidget {
  const GrowBars({super.key, required this.values, required this.labels, this.color, this.height = 140, this.highlight});
  final List<double> values;
  final List<String> labels;
  final Color? color;
  final double height;
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final maxV = values.isEmpty ? 1.0 : math.max(values.reduce(math.max), 1.0);
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.of(context, Motion.chartDraw),
        curve: Motion.emphasized,
        builder: (context, t, _) => BarChart(
          BarChartData(
            maxY: maxV * 1.15,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(labels[v.toInt()], style: Theme.of(context).textTheme.labelSmall),
                  ),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < values.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: values[i] * math.min(1.0, math.max(0.0, t * values.length - i * 0.6)).clamp(0.0, 1.0),
                    width: 18,
                    borderRadius: BorderRadius.circular(6),
                    color: i == highlight ? (color ?? c.primary) : (color ?? c.primary).withValues(alpha: 0.45),
                  ),
                ]),
            ],
          ),
          duration: Duration.zero,
        ),
      ),
    );
  }
}
