import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/assets.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/page.dart';
import '../../domain/catalog/achievements.dart';
import '../../domain/engine/journey.dart';
import '../../domain/models/enums.dart';
import '../home/sheets.dart';

/// The 12-week BODYFORGE journey (spec §21) with animated milestones.
class JourneyScreen extends ConsumerWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final j = ref.watch(journeyProvider);
    final milestones = ref.watch(milestonesProvider).value ?? const [];
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    if (j == null) return const BfPage(title: '12-week journey', children: [Shimmer(height: 300)]);
    final phaseColor = {JourneyPhase.habit: c.secondary, JourneyPhase.body: c.primary, JourneyPhase.forge: c.ember};
    final phaseImage = {JourneyPhase.habit: Img.phaseHabit, JourneyPhase.body: Img.phaseBody, JourneyPhase.forge: Img.phaseForge};

    return BfPage(
      title: '12-week journey',
      bottom: j.complete ? BfButton(label: 'See your 12-week report', onPressed: () => context.push('/report')) : null,
      children: [
        BfCard(
          color: phaseColor[j.phase],
          rings: true,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 190,
            child: Row(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(Space.xl),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Overline(j.phase.weeks, color: BfPalette.ink.withValues(alpha: 0.6)),
                    Text(j.phase.title, style: t.headlineMedium?.copyWith(color: BfPalette.ink)),
                    const Spacer(),
                    Text(j.complete ? 'Complete' : 'Week ${j.currentWeek} of $kJourneyWeeks',
                        style: BfType.number(22, color: BfPalette.ink, weight: FontWeight.w700)),
                  ]),
                ),
              ),
              SizedBox(width: 130, child: AppImage(j.complete ? Img.medal(MedalTier.ember) : phaseImage[j.phase])),
            ]),
          ),
        ).enter(context),
        const SizedBox(height: Space.md),
        Text(j.phase.description, style: t.bodyMedium?.copyWith(color: c.textMuted)).enter(context, index: 1),
        const SizedBox(height: Space.lg),
        for (var w = 1; w <= kJourneyWeeks; w++) ...[
          if (w == 1 || w == 5 || w == 9)
            Padding(
              padding: const EdgeInsets.only(top: Space.md, bottom: Space.sm),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: phaseColor[JourneyPhase.forWeek(w)], shape: BoxShape.circle)),
                const SizedBox(width: Space.sm),
                Text(JourneyPhase.forWeek(w).title.toUpperCase(), style: BfType.overline(c.textMuted)),
              ]),
            ),
          _WeekRow(week: w, state: j, color: phaseColor[JourneyPhase.forWeek(w)]!, index: w),
        ],
        const SizedBox(height: Space.lg),
        if (kBenchmarkWeeks.contains(j.currentWeek) && !j.complete)
          BfCard(
            color: c.ember,
            onTap: () => openDay(context, ref, DayType.benchmark),
            child: Row(children: [
              const Icon(BfIcons.test, color: BfPalette.ink),
              const SizedBox(width: Space.sm),
              Expanded(child: Text('Benchmark week — test your records', style: t.titleSmall?.copyWith(color: BfPalette.ink))),
              const Icon(BfIcons.chevronRight, color: BfPalette.ink),
            ]),
          ),
        if (milestones.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          Text('Milestones', style: t.headlineSmall),
          const SizedBox(height: Space.sm),
          for (final m in milestones.reversed.take(12))
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Row(children: [
                Icon(m.type == 'phase' ? BfIcons.flag : BfIcons.unlock, size: 18, color: c.primary),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(m.title, style: t.bodyMedium)),
                Text('${m.date.day}/${m.date.month}', style: t.bodySmall),
              ]),
            ),
        ],
        const SizedBox(height: Space.md),
        Text(
          'A week counts when you complete at least ${j.requiredPerWeek} of your ${j.plannedPerWeek} planned workouts. '
          'If a week falls short, you simply repeat it — the journey pauses, it never fails.',
          style: t.bodySmall,
        ),
      ],
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.week, required this.state, required this.color, required this.index});
  final int week;
  final JourneyState state;
  final Color color;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final t = Theme.of(context).textTheme;
    final done = week <= state.countedWeeks && !(week == state.currentWeek && !state.complete && !state.currentWeekMet);
    final current = week == state.currentWeek && !state.complete;
    final repeats = state.blocks.where((b) => b.journeyWeek == week && b.status == JourneyWeekStatus.repeated).length;
    Widget dot = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: done ? color : (current ? c.surfaceRaised : c.surface),
        shape: BoxShape.circle,
        border: Border.all(color: current ? color : c.outline, width: current ? 2.5 : 1),
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(BfIcons.check, size: 18, color: BfPalette.ink)
          : Text('$week', style: BfType.number(13, color: current ? c.text : c.textFaint, weight: FontWeight.w700)),
    );
    if (current && !Motion.reduced(context)) {
      dot = dot.animate(onPlay: (a) => a.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.12, 1.12), duration: 900.ms);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        dot,
        const SizedBox(width: Space.md),
        Expanded(
          child: Text(
            current
                ? 'This week · ${state.currentWeekWorkouts}/${state.requiredPerWeek} workouts'
                : done
                    ? 'Week $week counted${repeats > 0 ? ' (after $repeats repeat${repeats == 1 ? '' : 's'})' : ''}'
                    : 'Week $week',
            style: t.bodyMedium?.copyWith(color: done || current ? c.text : c.textFaint),
          ),
        ),
        if ({4, 8, 12}.contains(week)) Icon(BfIcons.flag, size: 16, color: done ? color : c.textFaint),
      ]),
    ).animate(delay: Motion.stagger(index, base: 150.ms)).fadeIn(duration: Motion.of(context, Motion.medium)).moveX(begin: 12, end: 0);
  }
}
