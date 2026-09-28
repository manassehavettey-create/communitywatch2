import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/page.dart';
import '../../domain/models/enums.dart';

/// Weekly reality check (spec §17): real, measurable change — revealed one
/// line at a time.
class WeeklyCheckScreen extends ConsumerStatefulWidget {
  const WeeklyCheckScreen({super.key});
  @override
  ConsumerState<WeeklyCheckScreen> createState() => _WeeklyCheckScreenState();
}

class _WeeklyCheckScreenState extends ConsumerState<WeeklyCheckScreen> {
  int _offset = 0; // 0 = this week, -1 = last week…

  @override
  void initState() {
    super.initState();
    // Early in the week, show last week's full picture by default.
    if (ref.read(todayProvider).weekday <= 2) _offset = -1;
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final weekStart = today.startOfWeek.addDays(7 * _offset);
    final report = ref.watch(weeklyReportProvider(weekStart));
    final units = ref.watch(settingsProvider).units;
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final fmt = DateFormat('d MMM');

    return BfPage(
      title: 'Weekly reality check',
      children: [
        Row(children: [
          CircleIconButton(
              icon: BfIcons.chevronLeft, background: c.surfaceRaised, foreground: c.text, onTap: () => setState(() => _offset--)),
          Expanded(
            child: Column(children: [
              Text(_offset == 0 ? 'This week' : (_offset == -1 ? 'Last week' : '${-_offset} weeks ago'), style: t.titleMedium),
              Text('${fmt.format(weekStart.toLocalDateTime())} – ${fmt.format(weekStart.addDays(6).toLocalDateTime())}', style: t.bodySmall),
            ]),
          ),
          CircleIconButton(
            icon: BfIcons.chevronRight,
            background: c.surfaceRaised,
            foreground: _offset < 0 ? c.text : c.textFaint,
            onTap: _offset < 0 ? () => setState(() => _offset++) : null,
          ),
        ]),
        const SizedBox(height: Space.xl),
        if (report == null)
          const Shimmer(height: 300)
        else
          KeyedSubtree(
            key: ValueKey(weekStart),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('YOUR WEEK', style: BfType.number(40, color: c.text, weight: FontWeight.w800)).enter(context),
              const SizedBox(height: Space.lg),
              for (final (i, row) in [
                (
                  'Workouts',
                  '${report.completed} / ${report.planned}',
                  report.completed >= report.planned && report.planned > 0 ? c.accentText : c.text,
                  report.modified > 0 ? '${report.modified} modified · ${report.recoverySessions} recovery' : null,
                ),
                ('Consistency', '${(report.consistency * 100).round()}%', c.accentText, null),
                for (final d in report.prDeltas.take(3)) ('${d.name} record', d.deltaLabel, c.ember, null),
                if (report.weightDelta != null)
                  ('Weight', Units.formatDelta(MeasurementType.weight, report.weightDelta!, units), c.secondary, null),
                if (report.waistDelta != null)
                  ('Waist', Units.formatDelta(MeasurementType.waist, report.waistDelta!, units), c.secondary, null),
                ('Recovery', report.recovery, c.isDark ? c.tertiary : c.secondary, null),
                ('Time trained', '${report.totalMinutes} min', c.text, '${report.totalReps} reps logged'),
              ].indexed)
                _Row(label: row.$1, value: row.$2, color: row.$3, sub: row.$4, index: i),
              const SizedBox(height: Space.xl),
              BfCard(
                color: c.surfaceRaised,
                child: Text(
                  report.isEmpty
                      ? 'A quiet week. That\'s okay — start again with one short session. Something is better than nothing.'
                      : report.consistency >= 0.8
                          ? 'Strong week. Consistency like this is what changes bodies.'
                          : 'Progress, not perfection. Aim for one more session next week.',
                  style: t.bodyMedium,
                ),
              ).animate(delay: Motion.stagger(9, base: 300.ms)).fadeIn(duration: Motion.of(context, Motion.slow)),
            ]),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.color, required this.index, this.sub});
  final String label;
  final String value;
  final Color color;
  final String? sub;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.outline.withValues(alpha: 0.6)))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: BfType.overline(c.textMuted)),
            if (sub != null) Text(sub!, style: t.bodySmall),
          ]),
        ),
        Text(value, style: BfType.number(26, color: color)),
      ]),
    )
        .animate(delay: Duration(milliseconds: Motion.reduced(context) ? 0 : 250 + index * 220))
        .fadeIn(duration: Motion.of(context, Motion.slow))
        .moveX(begin: 24, end: 0, curve: Motion.emphasized, duration: Motion.of(context, Motion.slow));
  }
}
