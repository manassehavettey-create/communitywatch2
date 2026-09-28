import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/assets.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../domain/engine/calendar.dart';
import '../../domain/engine/records.dart';
import '../../domain/models/enums.dart';
import 'calendar_screen.dart';
import 'progress_helpers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final workouts = ref.watch(workoutsProvider).value ?? const [];
    final history = ref.watch(recordHistoryProvider).value ?? const [];
    final measurements = ref.watch(measurementsProvider).value ?? const [];
    final units = ref.watch(settingsProvider).units;
    final cal = ref.watch(calendarProvider);
    final program = ref.watch(activeProgramProvider).value;
    final today = ref.watch(todayProvider);
    final c30 = consistency(
      from: today.addDays(-29),
      to: today,
      sessionDates: [for (final w in workouts) w.date],
      program: program?.spec,
      programStart: program?.startedOn ?? today,
    );
    final prs = history.where((r) => r.previous != null).length;
    final weights = [for (final m in measurements) if (m.point.type == MeasurementType.weight) m.point];
    final featured = featuredRecords(history);

    var i = 0;
    Widget e(Widget w) => w.enter(context, index: i++);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 120),
          children: [
            e(Text('Progress', style: t.displaySmall)),
            const SizedBox(height: Space.md),
            e(Row(children: [
              Expanded(child: StatTile(label: 'Workouts', value: CountUp(value: workouts.length.toDouble()))),
              const SizedBox(width: Space.sm),
              Expanded(
                child: BfCard(
                  padding: const EdgeInsets.all(Space.md),
                  onTap: () => context.push('/calendar'),
                  child: Row(children: [
                    RingProgress(
                      progress: c30,
                      size: 54,
                      stroke: 6,
                      child: Text('${(c30 * 100).round()}', style: BfType.number(14, color: c.text)),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(child: Text('30-day\nconsistency', style: t.labelSmall)),
                  ]),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(child: StatTile(label: 'PRs', color: c.ember, value: CountUp(value: prs.toDouble()))),
            ])),
            const SizedBox(height: Space.md),
            e(BfCard(
              color: c.surfaceRaised,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(BfIcons.info, color: c.secondary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    'Belly fat can\'t be burned by ab exercises alone. Visible abs come from lowering overall body fat '
                    '(nutrition + training) while building the ab muscles. Track your waist and strength — not just the mirror.',
                    style: t.bodySmall?.copyWith(color: c.text),
                  ),
                ),
              ]),
            )),
            e(SectionHeader('Strength', action: 'All records', onAction: () => context.push('/records'), padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm))),
            if (featured.isEmpty)
              e(const EmptyState(image: Img.emptyRecords, title: 'No records yet', message: 'Your first workout sets your baselines.', imageHeight: 110))
            else ...[
              for (final f in featured)
                e(Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: _StrengthCard(record: f, history: history),
                )),
            ],
            e(SectionHeader('Body weight', action: 'Measurements', onAction: () => context.push('/measurements'), padding: const EdgeInsets.only(top: Space.lg, bottom: Space.sm))),
            e(BfCard(
              onTap: () => context.push('/measurements'),
              child: weights.length < 2
                  ? Row(children: [
                      const SizedBox(width: 64, height: 64, child: AppImage(Img.emptyMeasurements, alignment: Alignment.center)),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Text(
                          weights.isEmpty ? 'Log your weight and waist to see changes over time.' : 'Log again in a week to see your trend.',
                          style: t.bodyMedium?.copyWith(color: c.textMuted),
                        ),
                      ),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(Units.formatMeasurement(MeasurementType.weight, weights.first.value, units),
                            style: BfType.number(18, color: c.textMuted)),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(BfIcons.forward, size: 16, color: c.textMuted)),
                        Text(Units.formatMeasurement(MeasurementType.weight, weights.last.value, units),
                            style: BfType.number(28, color: c.text)),
                        const Spacer(),
                        Text(Units.formatDelta(MeasurementType.weight, weights.last.value - weights.first.value, units),
                            style: BfType.number(14, color: c.secondary)),
                      ]),
                      const SizedBox(height: Space.md),
                      DrawInLineChart(
                        color: c.secondary,
                        height: 150,
                        points: [
                          for (final w in weights)
                            ChartPoint(w.date.daysSince(weights.first.date).toDouble(), Units.toDisplay(MeasurementType.weight, w.value, units))
                        ],
                        formatY: (v) => Units.format(v),
                      ),
                    ]),
            )),
            e(SectionHeader('Consistency', action: '30 days', onAction: () => context.push('/calendar'), padding: const EdgeInsets.only(top: Space.lg, bottom: Space.sm))),
            e(BfCard(onTap: () => context.push('/calendar'), child: CalendarGrid(days: cal, compact: true))),
            const SizedBox(height: Space.lg),
            for (final (icon, title, route) in [
              (BfIcons.calendar, 'Weekly reality check', '/weekly'),
              (BfIcons.map, '12-week journey', '/journey'),
              (BfIcons.trophy, 'Achievements', '/achievements'),
              (BfIcons.ruler, 'Body measurements', '/measurements'),
            ])
              e(Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: BfCard(
                  padding: const EdgeInsets.all(Space.md),
                  onTap: () => context.push(route),
                  child: Row(children: [
                    Icon(icon, color: c.primary),
                    const SizedBox(width: Space.md),
                    Expanded(child: Text(title, style: t.titleSmall)),
                    const Icon(BfIcons.chevronRight),
                  ]),
                ),
              )),
          ],
        ),
      ),
    );
  }
}

class _StrengthCard extends StatelessWidget {
  const _StrengthCard({required this.record, required this.history});
  final FeaturedRecord record;
  final List history;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final t = Theme.of(context).textTheme;
    final pts = history.where((r) => r.exerciseId == record.exerciseId).toList()..sort((a, b) => a.date.compareTo(b.date));
    final first = pts.first.date;
    final chart = <ChartPoint>[
      if (pts.first.previous != null) ChartPoint(0, pts.first.previous!.toDouble()),
      for (final p in pts) ChartPoint(p.date.daysSince(first).toDouble() + (pts.first.previous != null ? 0.5 : 0), p.value.toDouble()),
    ];
    return BfCard(
      onTap: () => context.push('/records'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Overline(record.label),
              Text(record.exerciseName, style: t.titleSmall),
            ]),
          ),
          Text(record.format(record.first), style: BfType.number(16, color: c.textMuted)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(BfIcons.forward, size: 14, color: c.textMuted)),
          Text(record.format(record.best), style: BfType.number(26, color: c.primary)),
        ]),
        if (chart.length >= 2) ...[
          const SizedBox(height: Space.sm),
          DrawInLineChart(
            points: chart,
            height: 110,
            formatY: (v) => record.metric == RecordMetric.maxHold ? formatSeconds(v.round()) : v.toStringAsFixed(0),
          ),
        ],
      ]),
    );
  }
}
