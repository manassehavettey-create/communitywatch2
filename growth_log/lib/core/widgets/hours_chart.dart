import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';

class ChartBar {
  const ChartBar(
    this.label,
    this.seconds, {
    this.highlight = false,
    this.tooltip,
  });
  final String label;
  final int seconds;
  final bool highlight;
  final String? tooltip;
}

/// Rounded bar chart of practice time with a faint full-height track behind
/// each bar (the "Statistics" reference). Tap a bar for its exact value.
class HoursBarChart extends StatelessWidget {
  const HoursBarChart({
    super.key,
    required this.bars,
    this.height = 180,
    this.barColor = Palette.lime,
    this.highlightColor,
    this.trackColor,
    this.labelColor,
    this.tooltipColor = Palette.ink,
    this.tooltipTextColor = Palette.white,
  });

  final List<ChartBar> bars;
  final double height;
  final Color barColor;
  final Color? highlightColor;
  final Color? trackColor;
  final Color? labelColor;
  final Color tooltipColor;
  final Color tooltipTextColor;

  @override
  Widget build(BuildContext context) {
    final maxSec = bars.fold<int>(0, (m, b) => math.max(m, b.seconds));
    final maxY = maxSec == 0 ? 1.0 : maxSec / 3600 * 1.12;
    final dense = bars.length > 14;
    final width = dense ? 6.0 : (bars.length > 8 ? 14.0 : 22.0);
    final labels = labelColor ?? context.gl.muted;
    final track = trackColor ?? context.gl.hairline.withValues(alpha: 0.6);
    final total = bars.fold<int>(0, (s, b) => s + b.seconds);

    return Semantics(
      label: 'Bar chart, ${bars.length} bars, total ${Fmt.duration(total)}',
      child: SizedBox(
        height: height,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= bars.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      space: 6,
                      child: Text(
                        bars[i].label,
                        style: AppText.caption.copyWith(
                          color: labels,
                          fontSize: 11,
                          fontWeight: bars[i].highlight
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => tooltipColor,
                tooltipBorderRadius: Radii.pillR,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                getTooltipItem: (group, gi, rod, ri) {
                  final b = bars[group.x];
                  return BarTooltipItem(
                    b.tooltip ?? Fmt.duration(b.seconds),
                    AppText.caption.copyWith(
                      color: tooltipTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ),
            barGroups: [
              for (var i = 0; i < bars.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: bars[i].seconds / 3600,
                      width: width,
                      color: bars[i].highlight
                          ? (highlightColor ?? barColor)
                          : barColor,
                      borderRadius: BorderRadius.circular(width / 2),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: track,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          duration: Motion.medium,
        ),
      ),
    );
  }
}
