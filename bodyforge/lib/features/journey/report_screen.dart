import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/assets.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/page.dart';
import '../../domain/catalog/achievements.dart';
import '../../domain/engine/reports.dart';
import '../../domain/models/enums.dart';

/// 12-week performance report (spec §21).
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(journeyRecordProvider).value;
    final workouts = ref.watch(workoutsProvider).value;
    final records = ref.watch(recordHistoryProvider).value;
    final measurements = ref.watch(measurementsProvider).value;
    final progress = ref.watch(progressProvider).value;
    final milestones = ref.watch(milestonesProvider).value ?? const [];
    final unlocked = ref.watch(unlockedAchievementsProvider).value ?? const {};
    final program = ref.watch(activeProgramProvider).value;
    final journey = ref.watch(journeyProvider);
    final units = ref.watch(settingsProvider).units;
    final today = ref.watch(todayProvider);
    final t = Theme.of(context).textTheme;
    final c = context.bf;

    if (record == null || workouts == null || records == null || measurements == null || progress == null) {
      return const BfPage(title: '12-week report', children: [Shimmer(height: 400)]);
    }
    final end = record.completedOn ?? today;
    final r = buildFinalReport(
      start: record.startDate,
      end: end,
      workouts: workouts,
      records: records,
      measurements: [for (final m in measurements) m.point],
      startNodes: record.startNodes,
      currentNodes: {for (final e in progress.entries) e.key: e.value.nodeIndex},
      milestones: milestones,
      achievementIds: unlocked.keys.toList(),
      program: program?.spec,
    );
    final complete = journey?.complete ?? false;
    var i = 0;
    Widget e(Widget w) => w
        .animate(delay: Duration(milliseconds: Motion.reduced(context) ? 0 : 200 + 160 * i++))
        .fadeIn(duration: Motion.of(context, Motion.slow))
        .moveY(begin: 16, end: 0, curve: Motion.emphasized);

    return Stack(children: [
      BfPage(
        title: '12-week report',
        children: [
          e(BfCard(
            color: c.ember,
            rings: true,
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Overline(complete ? 'Journey complete' : 'Report so far', color: BfPalette.ink.withValues(alpha: 0.6)),
                  Text(complete ? 'You forged it.' : 'Week ${journey?.currentWeek ?? 1} of 12', style: t.headlineMedium?.copyWith(color: BfPalette.ink)),
                ]),
              ),
              SizedBox(width: 90, height: 90, child: Glow(color: BfPalette.ember, radius: 50, child: AppImage(Img.medal(MedalTier.ember)))),
            ]),
          )),
          const SizedBox(height: Space.md),
          e(Row(children: [
            Expanded(child: StatTile(label: 'Workouts', value: CountUp(value: r.workouts.toDouble()))),
            const SizedBox(width: Space.sm),
            Expanded(child: StatTile(label: 'Consistency', color: c.primary, value: CountUp(value: r.consistency * 100, suffix: '%'))),
            const SizedBox(width: Space.sm),
            Expanded(child: StatTile(label: 'PRs', color: c.ember, value: CountUp(value: r.prCount.toDouble()))),
          ])),
          const SizedBox(height: Space.sm),
          e(Row(children: [
            Expanded(child: StatTile(label: 'Minutes', value: CountUp(value: r.totalMinutes.toDouble()))),
            const SizedBox(width: Space.sm),
            Expanded(child: StatTile(label: 'Reps', value: CountUp(value: r.totalReps.toDouble()))),
          ])),
          e(const SectionHeader('Strength', padding: EdgeInsets.only(top: Space.xl, bottom: Space.sm))),
          for (final s in r.strength)
            e(Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: BfCard(
                padding: const EdgeInsets.all(Space.md),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.path.name, style: t.labelMedium?.copyWith(color: c.textMuted)),
                      Text('${s.fromName} → ${s.toName}', style: t.titleSmall),
                    ]),
                  ),
                  Text(s.levelsGained > 0 ? '+${s.levelsGained}' : '—', style: BfType.number(22, color: s.levelsGained > 0 ? c.primary : c.textFaint)),
                ]),
              ),
            )),
          if (r.records.isNotEmpty) ...[
            e(const SectionHeader('Personal records', padding: EdgeInsets.only(top: Space.lg, bottom: Space.sm))),
            for (final d in r.records.take(6))
              e(Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Row(children: [
                  Expanded(child: Text(d.name, style: t.bodyMedium)),
                  Text(d.deltaLabel, style: BfType.number(16, color: c.ember)),
                ]),
              )),
          ],
          e(const SectionHeader('Body', padding: EdgeInsets.only(top: Space.lg, bottom: Space.sm))),
          e(Row(children: [
            Expanded(
              child: StatTile(
                label: 'Weight',
                value: Text(r.weightChange == null ? '—' : Units.formatDelta(MeasurementType.weight, r.weightChange!, units)),
                caption: r.weightStart == null || r.weightEnd == null
                    ? 'Log weight to compare'
                    : '${Units.formatMeasurement(MeasurementType.weight, r.weightStart!, units)} → ${Units.formatMeasurement(MeasurementType.weight, r.weightEnd!, units)}',
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: StatTile(
                label: 'Waist',
                value: Text(r.waistChange == null ? '—' : Units.formatDelta(MeasurementType.waist, r.waistChange!, units)),
                caption: r.waistStart == null || r.waistEnd == null
                    ? 'Log waist to compare'
                    : '${Units.formatMeasurement(MeasurementType.waist, r.waistStart!, units)} → ${Units.formatMeasurement(MeasurementType.waist, r.waistEnd!, units)}',
              ),
            ),
          ])),
          if (r.milestones.isNotEmpty) ...[
            e(const SectionHeader('Milestones', padding: EdgeInsets.only(top: Space.lg, bottom: Space.sm))),
            for (final m in r.milestones.take(10))
              e(Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(BfIcons.flag, size: 16, color: c.primary),
                  const SizedBox(width: Space.sm),
                  Expanded(child: Text(m.title, style: t.bodyMedium)),
                ]),
              )),
          ],
          if (r.achievementIds.isNotEmpty) ...[
            e(const SectionHeader('Achievements', padding: EdgeInsets.only(top: Space.lg, bottom: Space.sm))),
            e(Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
              for (final id in r.achievementIds)
                if (kAchievementById[id] != null) MedalBadge(def: kAchievementById[id]!, unlocked: true, size: 56),
            ])),
          ],
        ],
      ),
      if (complete) const Positioned.fill(child: ParticleBurst(count: 70)),
    ]);
  }
}
