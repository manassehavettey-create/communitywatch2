import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/page.dart';
import '../../domain/engine/calendar.dart';

Color statusColor(BuildContext context, DayStatus s) {
  final c = context.bf;
  return switch (s) {
    DayStatus.completed => c.primary,
    DayStatus.modified => c.secondary,
    DayStatus.recovery => c.tertiary,
    DayStatus.rest => c.surfaceRaised,
    DayStatus.missed => c.surface,
    DayStatus.planned => c.surface,
    DayStatus.today => c.surface,
  };
}

/// 30-day consistency grid (spec §18): cells pop in one after another.
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({super.key, required this.days, this.compact = false});
  final List<CalendarDay> days;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final t = Theme.of(context).textTheme;
    if (days.isEmpty) return const SizedBox.shrink();
    // Align the first day under its weekday column.
    final lead = days.first.date.weekday - 1;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var i = 0; i < days.length; i++)
        () {
          final d = days[i];
          final isToday = d.status == DayStatus.today || i == days.length - 1;
          return Container(
            decoration: BoxDecoration(
              color: statusColor(context, d.status),
              borderRadius: BorderRadius.circular(compact ? 8 : 12),
              border: Border.all(
                color: isToday
                    ? c.text
                    : d.status == DayStatus.missed
                        ? c.danger.withValues(alpha: 0.5)
                        : (d.status == DayStatus.planned ? c.outline : Colors.transparent),
                width: isToday ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: compact
                ? null
                : Text('${d.date.day}',
                    style: BfType.number(13,
                        color: d.status == DayStatus.completed || d.status == DayStatus.modified || d.status == DayStatus.recovery
                            ? BfPalette.ink
                            : c.textMuted,
                        weight: FontWeight.w700)),
          ).animate(delay: Duration(milliseconds: Motion.reduced(context) ? 0 : 18 * i)).fadeIn(duration: Motion.of(context, Motion.medium)).scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                curve: Motion.gentleSpring,
                duration: Motion.of(context, Motion.medium),
              );
        }(),
    ];
    return Column(children: [
      Row(children: [
        for (final l in ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Expanded(child: Center(child: Text(l, style: t.labelSmall))),
      ]),
      const SizedBox(height: 6),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: compact ? 5 : 8,
        crossAxisSpacing: compact ? 5 : 8,
        childAspectRatio: compact ? 1.25 : 1,
        children: cells,
      ),
      const SizedBox(height: Space.sm),
      Wrap(spacing: Space.md, runSpacing: 6, children: [
        for (final s in [DayStatus.completed, DayStatus.modified, DayStatus.recovery, DayStatus.rest, DayStatus.missed])
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor(context, s),
                borderRadius: BorderRadius.circular(3),
                border: s == DayStatus.missed ? Border.all(color: c.danger.withValues(alpha: 0.5)) : null,
              ),
            ),
            const SizedBox(width: 4),
            Text(s.label, style: t.labelSmall),
          ]),
      ]),
    ]);
  }
}

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(calendarProvider);
    final workouts = ref.watch(workoutsProvider).value ?? const [];
    final today = ref.watch(todayProvider);
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final done = days.where((d) => d.status == DayStatus.completed || d.status == DayStatus.modified || d.status == DayStatus.recovery).length;
    final planned = days.where((d) => d.planned != null && !d.date.isAfter(today)).length;
    final streak = activeWeekStreak(today, [for (final w in workouts) w.date]);
    return BfPage(
      title: 'Consistency',
      children: [
        Text('Last 30 days', style: t.headlineMedium),
        const SizedBox(height: 4),
        Text('Missing one workout doesn\'t erase anything. What matters is the pattern.', style: t.bodyMedium?.copyWith(color: c.textMuted)),
        const SizedBox(height: Space.lg),
        Row(children: [
          Expanded(child: StatTile(label: 'Training days', value: Text('$done'))),
          const SizedBox(width: Space.sm),
          Expanded(child: StatTile(label: 'Consistency', color: c.primary, value: Text(planned == 0 ? '—' : '${(done / planned * 100).clamp(0, 100).round()}%'))),
          const SizedBox(width: Space.sm),
          Expanded(child: StatTile(label: 'Week streak', color: c.secondary, value: Text('$streak'))),
        ]),
        const SizedBox(height: Space.lg),
        BfCard(child: CalendarGrid(days: days)),
      ],
    );
  }
}
