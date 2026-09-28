import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';
import '../../core/assets.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/navigation.dart';
import '../../domain/engine/calendar.dart';
import '../../domain/engine/journey.dart';
import '../../domain/engine/mission.dart';
import '../../domain/engine/recovery.dart';
import '../../domain/engine/weakest_link.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/local_date.dart';
import '../../domain/models/workout.dart';
import '../progress/progress_helpers.dart';
import 'sheets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final mission = ref.watch(missionDayProvider);
    final today = ref.watch(todayProvider);
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final now = ref.watch(clockProvider).now();

    int i = 0;
    Widget e(Widget w) => w.enter(context, index: i++);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: BfPalette.ink,
          backgroundColor: c.primary,
          onRefresh: () => ref.read(syncProvider.notifier).syncNow(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, Space.md, 0, 120),
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            children: [
              e(Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Overline(greetingFor(now)),
                      const SizedBox(height: 2),
                      Text(profile?.firstName ?? '', style: t.headlineLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  SyncBadge(status: ref.watch(syncProvider), onTap: () => ref.read(syncProvider.notifier).syncNow()),
                  const SizedBox(width: Space.xs),
                  CircleIconButton(icon: BfIcons.settings, tooltip: 'Settings', onTap: () => context.push('/settings')),
                ]),
              )),
              const SizedBox(height: Space.lg),
              e(const _ResumeBanner()),
              e(Padding(padding: const EdgeInsets.symmetric(horizontal: Space.gutter), child: _WeekStrip(today: today))),
              const SizedBox(height: Space.lg),
              e(Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: mission == null ? const Shimmer(height: 260) : _MissionCard(day: mission),
              )),
              const SizedBox(height: Space.md),
              e(const _QuickRow()),
              e(const _LowMotivationCard()),
              e(const _WeeklyPrompt()),
              e(const SectionHeader('Your progress')),
              e(const _ProgressStrip()),
              e(const SectionHeader('12-week journey')),
              e(const _JourneyCard()),
              e(const _WeakLinkCard()),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumeBanner extends ConsumerWidget {
  const _ResumeBanner();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(hasActiveSessionProvider).value ?? false;
    if (!active) return const SizedBox.shrink();
    final c = context.bf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
      child: BfCard(
        color: c.secondary,
        onTap: () => context.push('/player'),
        child: Row(children: [
          const Icon(BfIcons.play, color: BfPalette.ink),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text('Workout in progress — tap to continue',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: BfPalette.ink)),
          ),
          const Icon(BfIcons.chevronRight, color: BfPalette.ink),
        ]),
      ).pop(context),
    );
  }
}

class _WeekStrip extends ConsumerWidget {
  const _WeekStrip({required this.today});
  final LocalDate today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cal = {for (final d in ref.watch(calendarProvider)) d.date: d};
    final start = today.startOfWeek;
    final c = context.bf;
    return DateStrip(
      days: [for (var i = 0; i < 7; i++) start.addDays(i)],
      today: today,
      onTap: (_) => context.push('/calendar'),
      statusColor: (d) => switch (cal[d]?.status) {
        DayStatus.completed => c.primary,
        DayStatus.modified => c.secondary,
        DayStatus.recovery => c.tertiary,
        DayStatus.planned || DayStatus.today => c.outline,
        DayStatus.missed => c.danger.withValues(alpha: 0.6),
        _ => null,
      },
    );
  }
}

/// TODAY'S MISSION (spec §26) — the answer to "what should I do today?".
class _MissionCard extends ConsumerWidget {
  const _MissionCard({required this.day});
  final MissionDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final plan = ref.watch(missionPlanProvider);
    final type = day.missionType;
    final recovery = ref.watch(todaysRecoveryProvider);

    if (type == null) {
      // Rest day.
      return BfCard(
        color: c.surface,
        rings: true,
        padding: const EdgeInsets.all(Space.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Overline('Today\'s mission'),
          const SizedBox(height: Space.xs),
          Text(day.doneToday ? 'Done for today.' : 'Rest day', style: t.displaySmall),
          const SizedBox(height: Space.xs),
          Text(
            day.doneToday
                ? 'Great work. Recovery is where the body is forged.'
                : 'Muscles grow while you rest. Walk, stretch, sleep well.',
            style: t.bodyMedium?.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: Space.lg),
          BfButton(
            label: 'Optional: recovery flow',
            kind: BfButtonKind.secondary,
            icon: BfIcons.leaf,
            onPressed: () => openDay(context, ref, DayType.recovery, minutes: 12),
          ),
        ]),
      );
    }

    final minutes = plan?.estimatedMinutes ?? 0;
    final adjusted = plan != null && plan.kind == SessionKind.recoveryReduced;
    return Hero(
      tag: 'mission',
      flightShuttleBuilder: (_, anim, _, _, to) => to.widget,
      child: Material(
        type: MaterialType.transparency,
        child: _AnimatedGradient(
          child: SizedBox(
            height: 300,
            child: Stack(clipBehavior: Clip.none, children: [
              const Positioned.fill(child: ConcentricRings(color: Color(0x14000000), alignment: Alignment(1.2, -0.4), animate: true)),
              Positioned(
                right: -8,
                top: 8,
                bottom: 78,
                width: 190,
                child: AppImage(Img.forDay(type), alignment: Alignment.bottomRight)
                    .animate()
                    .fadeIn(duration: Motion.of(context, Motion.slower))
                    .moveX(begin: 30, end: 0, curve: Motion.emphasized, duration: Motion.of(context, Motion.slower)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.lg),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Overline(day.isRestDay ? 'Catch-up mission' : 'Today\'s mission', color: BfPalette.ink.withValues(alpha: 0.6)),
                  const SizedBox(height: Space.xs),
                  SizedBox(
                    width: 180,
                    child: Text(type.label, style: t.headlineLarge?.copyWith(color: BfPalette.ink, height: 1.05)),
                  ),
                  const SizedBox(height: Space.sm),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _Tag(icon: BfIcons.time, text: '$minutes min'),
                    _Tag(icon: BfIcons.flame, text: plan?.difficultyLabel ?? '—'),
                    if (adjusted) const _Tag(icon: BfIcons.leaf, text: 'Adjusted'),
                    if (day.doneToday) const _Tag(icon: BfIcons.check, text: 'Done'),
                  ]),
                  const Spacer(),
                  if (recovery != null && recovery.mode != RecoveryMode.full)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: Text(recovery.mode.message,
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: BfPalette.ink)),
                    ),
                  SwipeToStart(
                    label: day.doneToday ? 'Train again' : 'Start workout',
                    onComplete: () {
                      if (plan != null) openSession(context, ref, plan);
                    },
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: BfPalette.ink.withValues(alpha: 0.08), borderRadius: Radii.pillAll),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: BfPalette.ink),
          const SizedBox(width: 4),
          Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: BfPalette.ink)),
        ]),
      );
}

/// Lime card with a slow, subtle moving gradient (the "alive" mission card).
class _AnimatedGradient extends StatefulWidget {
  const _AnimatedGradient({required this.child});
  final Widget child;
  @override
  State<_AnimatedGradient> createState() => _AnimatedGradientState();
}

class _AnimatedGradientState extends State<_AnimatedGradient> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final reduced = Motion.reduced(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = reduced ? 0.5 : Curves.easeInOut.transform(_c.value);
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: Radii.cardLarge,
            gradient: LinearGradient(
              begin: Alignment(-1 + v, -1),
              end: Alignment(1, 1 - v),
              colors: [c.primary, Color.lerp(c.primary, BfPalette.butter, 0.35)!, c.primary],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _QuickRow extends ConsumerWidget {
  const _QuickRow();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(todaysRecoveryProvider);
    final profile = ref.watch(profileProvider).value;
    final plan = ref.watch(missionPlanProvider);
    final day = ref.watch(missionDayProvider);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        children: [
          PillChip(
            label: check == null ? 'How are you feeling?' : 'Recovery: ${check.mode.label}',
            icon: BfIcons.heart,
            selected: check != null,
            onTap: () => showRecoveryCheck(context),
          ),
          const SizedBox(width: Space.xs),
          PillChip(
            label: 'How much time?',
            icon: BfIcons.time,
            selected: false,
            onTap: () async {
              final type = day?.missionType ?? DayType.fullBody;
              final m = await pickTime(context, current: plan?.estimatedMinutes);
              if (m != null && context.mounted) openDay(context, ref, type, minutes: m);
            },
          ),
          const SizedBox(width: Space.xs),
          PillChip(
            label: profile?.environment.label ?? 'Space',
            icon: BfIcons.location,
            selected: false,
            onTap: () => _pickEnvironment(context, ref),
          ),
        ],
      ),
    );
  }
}

Future<void> _pickEnvironment(BuildContext context, WidgetRef ref) async {
  final current = ref.read(profileProvider).value?.environment;
  final env = await showBfSheet<TrainingEnvironment>(context, builder: (ctx) {
    final t = Theme.of(ctx).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Where are you training?', style: t.headlineMedium),
        const SizedBox(height: Space.lg),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.sm,
          crossAxisSpacing: Space.sm,
          childAspectRatio: 0.85,
          children: [
            for (final e in TrainingEnvironment.values)
              Pressable(
                onTap: () => Navigator.pop(ctx, e),
                borderRadius: Radii.tile,
                child: Container(
                  padding: const EdgeInsets.all(Space.xs),
                  decoration: BoxDecoration(
                    color: e == current ? ctx.bf.primary : ctx.bf.surfaceRaised,
                    borderRadius: Radii.tile,
                  ),
                  child: Column(children: [
                    Expanded(child: AppImage(Img.environment(e), alignment: Alignment.center)),
                    Text(e.label,
                        textAlign: TextAlign.center,
                        style: t.labelSmall?.copyWith(color: e == current ? BfPalette.ink : ctx.bf.text)),
                  ]),
                ),
              ),
          ],
        ),
      ]),
    );
  });
  if (env != null) await ref.read(profileRepoProvider).setEnvironment(env);
}

class _LowMotivationCard extends ConsumerWidget {
  const _LowMotivationCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
      child: BfCard(
        color: c.secondary,
        onTap: () => showQuickMode(context, ref),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Not feeling it today?', style: t.titleMedium?.copyWith(color: BfPalette.ink)),
              const SizedBox(height: 2),
              Text('TRY 10-MINUTE MODE', style: BfType.overline(BfPalette.ink.withValues(alpha: 0.7))),
            ]),
          ),
          const CircleIconButton(icon: BfIcons.bolt, size: 44),
        ]),
      ),
    );
  }
}

class _WeeklyPrompt extends ConsumerWidget {
  const _WeeklyPrompt();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    // Sunday evening through Monday: last/this week's summary is ready.
    if (today.weekday != DateTime.sunday && today.weekday != DateTime.monday) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
      child: BfCard(
        color: context.bf.surface,
        onTap: () => context.push('/weekly'),
        child: Row(children: [
          Icon(BfIcons.calendar, color: context.bf.primary),
          const SizedBox(width: Space.sm),
          Expanded(child: Text('Your weekly reality check is ready', style: t.titleSmall)),
          const Icon(BfIcons.chevronRight),
        ]),
      ),
    );
  }
}

class _ProgressStrip extends ConsumerWidget {
  const _ProgressStrip();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recordHistoryProvider).value;
    final c = context.bf;
    final t = Theme.of(context).textTheme;
    if (history == null) return const Padding(padding: EdgeInsets.symmetric(horizontal: Space.gutter), child: Shimmer(height: 110));
    final featured = featuredRecords(history);
    if (featured.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        child: BfCard(
          child: Row(children: [
            const SizedBox(width: 64, height: 64, child: AppImage(Img.emptyRecords, alignment: Alignment.center)),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text('Finish your first workout to set your baseline records.',
                  style: t.bodyMedium?.copyWith(color: c.textMuted)),
            ),
          ]),
        ),
      );
    }
    final colors = [c.surface, c.surface, c.surface];
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        itemCount: featured.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
        itemBuilder: (context, i) {
          final f = featured[i];
          return SizedBox(
            width: 170,
            child: BfCard(
              color: colors[i % colors.length],
              onTap: () => context.push('/records'),
              padding: const EdgeInsets.all(Space.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Overline(f.label),
                const Spacer(),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(f.format(f.first), style: BfType.number(18, color: c.textMuted)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(BfIcons.forward, size: 16, color: c.textMuted),
                  ),
                  f.metric.name == 'maxHold'
                      ? Text(f.format(f.best), style: BfType.number(30, color: c.primary))
                      : CountUp(value: f.best.toDouble(), style: BfType.number(30, color: c.primary)),
                ]),
                const SizedBox(height: 2),
                Text(f.exerciseName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _JourneyCard extends ConsumerWidget {
  const _JourneyCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final j = ref.watch(journeyProvider);
    final c = context.bf;
    final t = Theme.of(context).textTheme;
    if (j == null) return const Padding(padding: EdgeInsets.symmetric(horizontal: Space.gutter), child: Shimmer(height: 120));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: BfCard(
        onTap: () => context.push('/journey'),
        color: c.surface,
        rings: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Overline(j.phase.title),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text(j.complete ? 'Complete' : 'Week ${j.currentWeek}', style: t.headlineMedium),
                  if (!j.complete) Text(' / $kJourneyWeeks', style: t.titleMedium?.copyWith(color: c.textMuted)),
                ]),
              ]),
            ),
            RingProgress(
              progress: j.progress,
              size: 64,
              stroke: 7,
              gradient: [c.primary, c.ember, c.primary],
              child: CountUp(value: j.progress * 100, suffix: '%', style: BfType.number(14, color: c.text)),
            ),
          ]),
          const SizedBox(height: Space.md),
          _Segments(total: kJourneyWeeks, done: j.countedWeeks, current: j.complete ? -1 : j.currentWeek - 1),
          const SizedBox(height: Space.sm),
          Text(
            j.complete
                ? 'You finished the journey. See your 12-week report.'
                : j.currentWeekMet
                    ? 'This week counts ✓ — ${j.currentWeekWorkouts} workouts so far.'
                    : '${j.requiredPerWeek - j.currentWeekWorkouts} more workout${j.requiredPerWeek - j.currentWeekWorkouts == 1 ? '' : 's'} to count this week.',
            style: t.bodySmall,
          ),
        ]),
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.total, required this.done, required this.current});
  final int total;
  final int done;
  final int current;
  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    return Row(children: [
      for (var i = 0; i < total; i++)
        Expanded(
          child: Container(
            height: 10,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 4),
            decoration: BoxDecoration(
              color: i < done ? (i < 4 ? c.secondary : (i < 8 ? c.primary : c.ember)) : (i == current ? c.outline : c.surfaceRaised),
              borderRadius: Radii.pillAll,
            ),
          ).animate(delay: Motion.stagger(i, base: 200.ms)).scaleX(begin: 0, end: 1, alignment: Alignment.centerLeft, duration: Motion.of(context, Motion.medium)),
        ),
    ]);
  }
}

class _WeakLinkCard extends ConsumerWidget {
  const _WeakLinkCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(weakestLinkProvider);
    if (r == null || r.scores.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    return Column(children: [
      const SectionHeader('Weakest link'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        child: BfCard(
          onTap: () => context.push('/progress'),
          child: Column(children: [
            for (final a in Area.values)
              if (r.scores[a] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    SizedBox(width: 108, child: Text(a.label, style: t.labelMedium)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: Radii.pillAll,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: r.scores[a]!.score / 100),
                          duration: Motion.of(context, Motion.chartDraw),
                          curve: Motion.emphasized,
                          builder: (_, v, _) => LinearProgressIndicator(
                            value: v.clamp(0.04, 1),
                            minHeight: 8,
                            color: switch (r.scores[a]!.rating) {
                              AreaRating.strong => c.primary,
                              AreaRating.good => c.secondary,
                              AreaRating.needsWork => c.ember,
                            },
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 84,
                      child: Text(r.scores[a]!.rating.label,
                          textAlign: TextAlign.right,
                          style: t.labelSmall?.copyWith(
                              color: r.scores[a]!.rating == AreaRating.needsWork ? c.ember : c.textMuted)),
                    ),
                  ]),
                ),
            if (r.weakest != null) ...[
              const SizedBox(height: Space.xs),
              Text('Your plan adds a little extra ${r.weakest!.label.toLowerCase()} work to balance you out.', style: t.bodySmall),
            ],
          ]),
        ),
      ),
    ]);
  }
}

/// Used by other screens to show the plan's first primary exercise.
String? primaryExerciseOf(WorkoutPlan p) => p.main.exercises.isEmpty ? null : p.main.exercises.first.exerciseId;
