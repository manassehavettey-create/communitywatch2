import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/day.dart';
import '../../core/utils/format.dart';
import '../../data/logic/streak.dart';
import '../../data/repositories/stats_repository.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/illustration.dart';
import '../../shared/widgets/streak_badge.dart';

enum _Metric { pages, minutes }

enum _Range { week, month }

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  _Metric _metric = _Metric.pages;
  _Range _range = _Range.week;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    final stats = ref.watch(statsProvider).value;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: stats == null
            ? const SizedBox()
            : ListView(
                padding: const EdgeInsets.only(bottom: Space.navClearance),
                children: [
                  const ScreenTitle('Stats'),
                  if (!stats.hasHistory)
                    const EmptyState(
                      art: Art.emptyHistory,
                      title: 'No reading history yet',
                      message:
                          'Open a book and read for a minute. Your pages, time and streak '
                          'will start showing up here, stored only on this phone.',
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, 0),
                      child: _StreakHero(streak: stats.streak),
                    ).animate().fadeIn(duration: m.base),
                    const SizedBox(height: Space.x3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      child: Row(
                        children: [
                          _Tile(ShelfColor.butter, '${stats.pagesToday}', 'pages today'),
                          const SizedBox(width: Space.x3),
                          _Tile(ShelfColor.peach, '${stats.pagesWeek}', 'this week'),
                          const SizedBox(width: Space.x3),
                          _Tile(ShelfColor.rose, '${stats.pagesMonth}', 'this month'),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.x3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      child: Row(
                        children: [
                          _Tile(
                            ShelfColor.sky,
                            formatDuration(Duration(seconds: stats.totalSeconds), short: true),
                            'reading time',
                          ),
                          const SizedBox(width: Space.x3),
                          _Tile(ShelfColor.mint, '${stats.booksFinished}', 'books finished'),
                          const SizedBox(width: Space.x3),
                          _Tile(ShelfColor.lilac, '${stats.booksInProgress}', 'in progress'),
                        ],
                      ),
                    ),
                    SectionHeader(_metric == _Metric.pages ? 'Pages read' : 'Minutes read'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      child: Row(
                        children: [
                          PillChip(
                            label: 'Pages',
                            dense: true,
                            selected: _metric == _Metric.pages,
                            onTap: () => setState(() => _metric = _Metric.pages),
                          ),
                          const SizedBox(width: Space.x2),
                          PillChip(
                            label: 'Minutes',
                            dense: true,
                            selected: _metric == _Metric.minutes,
                            onTap: () => setState(() => _metric = _Metric.minutes),
                          ),
                          const Spacer(),
                          PillChip(
                            label: '7 days',
                            dense: true,
                            selected: _range == _Range.week,
                            onTap: () => setState(() => _range = _Range.week),
                          ),
                          const SizedBox(width: Space.x2),
                          PillChip(
                            label: '30 days',
                            dense: true,
                            selected: _range == _Range.month,
                            onTap: () => setState(() => _range = _Range.month),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.x3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(Space.x4, Space.x5, Space.x4, Space.x3),
                        decoration: BoxDecoration(color: context.colors.surface, borderRadius: Radii.lgAll),
                        child: _BarChart(
                          key: ValueKey('$_metric$_range'),
                          days: stats.lastDays(_range == _Range.week ? 7 : 30, DateTime.now()),
                          minutes: _metric == _Metric.minutes,
                        ),
                      ),
                    ),
                    const SectionHeader('Reading calendar'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      child: _Calendar(month: _month, days: stats.days, onMonth: (d) => setState(() => _month = d)),
                    ),
                    const SizedBox(height: Space.x3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      child: Text(
                        'A day counts toward your streak after 1 page or 1 minute of reading.',
                        style: context.text.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.streak});
  final StreakResult streak;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = context.brightness == Brightness.dark;
    final bg = dark ? c.surfaceMuted : c.ink;
    final fg = dark ? c.ink : c.onInk;
    return Container(
      padding: const EdgeInsets.all(Space.x5),
      decoration: BoxDecoration(color: bg, borderRadius: Radii.xlAll),
      child: Row(
        children: [
          StreakBadge(days: streak.current, size: 120),
          const SizedBox(width: Space.x5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak.current == 0
                      ? 'Start a new streak today'
                      : streak.readToday
                      ? 'You read today. Nice.'
                      : 'Read today to keep it going',
                  style: context.text.titleLarge?.copyWith(color: fg),
                ),
                const SizedBox(height: Space.x3),
                Row(
                  children: [
                    Icon(PhosphorIconsFill.fire, size: 16, color: c.lime),
                    const SizedBox(width: 6),
                    Text(
                      'Longest: ${plural(streak.longest, 'day')}',
                      style: context.text.labelLarge?.copyWith(color: fg.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.color, this.value, this.label);
  final ShelfColor color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final b = context.brightness;
    final fg = color.cardForeground(b);
    return Expanded(
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(Space.x3),
        decoration: BoxDecoration(color: color.cardBackground(b), borderRadius: Radii.lgAll),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: context.text.headlineMedium?.copyWith(color: fg, height: 1)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(color: fg.withValues(alpha: 0.75)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single-series bar chart: one hue, rounded tops on a baseline, a recessive
/// grid, labels only on the max and today, and tap/hover for exact values.
class _BarChart extends StatefulWidget {
  const _BarChart({super.key, required this.days, required this.minutes});
  final List<DayTotal> days;
  final bool minutes;

  @override
  State<_BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<_BarChart> {
  int? _active;
  bool _table = false;

  int _value(DayTotal d) => widget.minutes ? (d.seconds / 60).round() : d.pages;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = Motion.of(context);
    final bar = context.brightness == Brightness.dark ? const Color(0xFF8E72EC) : const Color(0xFF7C5CF0);
    final values = widget.days.map(_value).toList();
    final maxV = values.fold(0, (a, b) => a > b ? a : b);
    final niceMax = maxV <= 0 ? 1 : _nice(maxV);
    final unit = widget.minutes ? 'min' : 'pages';
    final total = values.fold(0, (a, b) => a + b);
    final few = widget.days.length <= 7;

    if (_table) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in widget.days.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(DateFormat('EEE d MMM').format(d.day), style: context.text.bodyMedium)),
                  Text('${_value(d)} $unit', style: context.text.labelLarge),
                ],
              ),
            ),
          TextButton(onPressed: () => setState(() => _table = false), child: const Text('Show chart')),
        ],
      );
    }

    final active = _active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          active == null
              ? '$total $unit in ${widget.days.length} days'
              : '${values[active]} $unit · ${DateFormat('EEEE d MMM').format(widget.days[active].day)}',
          style: context.text.titleSmall,
        ),
        const SizedBox(height: Space.x3),
        SizedBox(
          height: 160,
          child: LayoutBuilder(
            builder: (context, box) {
              final n = widget.days.length;
              final slot = box.maxWidth / n;
              final barW = (slot * (few ? 0.46 : 0.62)).clamp(3.0, 28.0);
              const labelH = 20.0;
              final plotH = box.maxHeight - labelH;
              return MouseRegion(
                onExit: (_) => setState(() => _active = null),
                onHover: (e) => setState(() => _active = (e.localPosition.dx / slot).floor().clamp(0, n - 1)),
                child: GestureDetector(
                  onTapDown: (e) {
                    HapticFeedback.selectionClick();
                    final i = (e.localPosition.dx / slot).floor().clamp(0, n - 1);
                    setState(() => _active = _active == i ? null : i);
                  },
                  child: Stack(
                    children: [
                      // Recessive grid: half and full scale.
                      for (final f in [0.5, 1.0])
                        Positioned(
                          left: 0,
                          right: 0,
                          top: plotH * (1 - f),
                          child: Row(
                            children: [
                              Expanded(child: Container(height: 1, color: c.hairline.withValues(alpha: 0.7))),
                              const SizedBox(width: 4),
                              Text('${(niceMax * f).round()}', style: context.text.labelSmall),
                            ],
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: plotH,
                        child: Container(height: 1, color: c.hairline),
                      ),
                      for (var i = 0; i < n; i++)
                        Positioned(
                          left: slot * i + (slot - barW) / 2,
                          width: barW,
                          bottom: labelH,
                          child: Semantics(
                            label: '${DateFormat('EEEE d MMMM').format(widget.days[i].day)}: ${values[i]} $unit',
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: values[i] / niceMax),
                              duration: m.slow * 2,
                              curve: Motion.emphasized,
                              builder: (context, v, _) => Container(
                                height: values[i] == 0 ? 2 : (plotH * v).clamp(2.0, plotH),
                                decoration: BoxDecoration(
                                  color: values[i] == 0
                                      ? c.hairline
                                      : (_active == null || _active == i ? bar : bar.withValues(alpha: 0.35)),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Direct labels only on the peak day (never every bar).
                      if (maxV > 0 && _active == null)
                        Builder(
                          builder: (context) {
                            final i = values.lastIndexOf(maxV);
                            final h = plotH * maxV / niceMax;
                            return Positioned(
                              left: (slot * i + slot / 2 - 30).clamp(0, box.maxWidth - 60),
                              width: 60,
                              bottom: labelH + h + 4,
                              child: Text('$maxV', textAlign: TextAlign.center, style: context.text.labelMedium),
                            );
                          },
                        ),
                      for (var i = 0; i < n; i++)
                        if (few || i == n - 1 || i % 7 == (n - 1) % 7)
                          Positioned(
                            left: slot * i,
                            width: slot,
                            bottom: 0,
                            child: Text(
                              i == n - 1
                                  ? 'Today'
                                  : (few
                                        ? DateFormat('E').format(widget.days[i].day)
                                        : DateFormat('d/M').format(widget.days[i].day)),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: context.text.labelSmall?.copyWith(
                                color: i == n - 1 ? c.ink : c.inkMuted,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => setState(() => _table = true), child: const Text('Show as table')),
        ),
      ],
    );
  }

  static int _nice(int v) {
    for (final step in [2, 4, 10, 20, 40, 100, 200, 400, 1000]) {
      if (v <= step) return step;
    }
    return ((v / 2000).ceil()) * 2000;
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.month, required this.days, required this.onMonth});
  final DateTime month;
  final List<DayTotal> days;
  final ValueChanged<DateTime> onMonth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final read = {
      for (final d in days)
        if (qualifiesForStreak(pagesRead: d.pages, seconds: d.seconds)) d.day: d,
    };
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday first
    final today = dateOnly(DateTime.now());
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();
    final count = read.keys.where((d) => d.year == month.year && d.month == month.month).length;
    final isCurrent = month.year == today.year && month.month == today.month;

    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(color: c.surface, borderRadius: Radii.lgAll),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
                icon: const Icon(PhosphorIconsRegular.caretLeft),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(DateFormat('MMMM yyyy').format(month), style: context.text.titleMedium),
                    Text(plural(count, 'reading day'), style: context.text.bodySmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: isCurrent ? null : () => onMonth(DateTime(month.year, month.month + 1)),
                icon: const Icon(PhosphorIconsRegular.caretRight),
              ),
            ],
          ),
          const SizedBox(height: Space.x2),
          Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(child: Text(d, style: context.text.labelSmall)),
                ),
            ],
          ),
          const SizedBox(height: Space.x2),
          for (var r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final idx = r * 7 + col - lead + 1;
                          if (idx < 1 || idx > daysInMonth) return const SizedBox(height: 36);
                          final day = DateTime(month.year, month.month, idx);
                          final hit = read[day];
                          final isToday = day == today;
                          return Semantics(
                            label:
                                '${DateFormat('d MMMM').format(day)}${hit != null ? ', read ${hit.pages} pages' : ''}',
                            excludeSemantics: true,
                            child: Container(
                              height: 36,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: hit != null ? c.lime : Colors.transparent,
                                borderRadius: Radii.smAll,
                                border: isToday ? Border.all(color: c.ink, width: 1.5) : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$idx',
                                style: context.text.labelMedium?.copyWith(
                                  color: hit != null
                                      ? const Color(0xFF161514)
                                      : (day.isAfter(today) ? c.hairline : c.inkMuted),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
