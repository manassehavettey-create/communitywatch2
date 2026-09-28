import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/icons.dart';

import '../../app/providers.dart';
import '../../bible/references.dart';
import '../../core/haptics.dart';
import '../../core/motion/motion.dart';
import '../../core/motion/reveal.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/progress.dart';
import '../../data/repos/plans_repository.dart';
import '../../domain/days.dart';
import '../../domain/plans.dart';
import '../reader/reader_screen.dart';
import 'plan_widgets.dart';

class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final catalog = ref.watch(planCatalogProvider).value;
    final plan = catalog?.where((x) => x.id == planId).firstOrNull;
    final mine = ref.watch(userPlansProvider).value;
    final user = mine?.where((u) => u.plan.id == planId).firstOrNull;

    if (catalog == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This plan is no longer available.')),
      );
    }
    final color = planColor(plan.category, p);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: color,
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                MediaQuery.paddingOf(context).top + Space.x3,
                Space.gutter,
                Space.x6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleIconButton(
                        icon: PhosphorIconsBold.caretLeft,
                        tooltip: 'Back',
                        background: p.onPastel.withValues(alpha: 0.08),
                        foreground: p.onPastel,
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      if (user != null) _PlanMenu(user: user),
                    ],
                  ),
                  const SizedBox(height: Space.x5),
                  Text(
                    plan.category.label.toUpperCase(),
                    style: AppType.overline.copyWith(color: p.onPastel),
                  ),
                  const SizedBox(height: Space.x2),
                  Text(
                    plan.title,
                    style: AppType.displayM.copyWith(color: p.onPastel),
                  ),
                  const SizedBox(height: Space.x2),
                  Text(
                    plan.description,
                    style: AppType.body.copyWith(color: p.onPastel),
                  ),
                  const SizedBox(height: Space.x5),
                  Row(
                    children: [
                      _Stat(
                        label: 'Duration',
                        value: durationLabel(plan.totalDays),
                      ),
                      _Stat(
                        label: 'Each day',
                        value: '~${plan.minutesPerDay} min',
                      ),
                      if (user != null)
                        _Stat(
                          label: 'Done',
                          value:
                              '${user.state.completedCount}/${plan.totalDays}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (user == null)
            SliverToBoxAdapter(child: _NotStarted(plan: plan))
          else
            ..._started(context, ref, user),
          const SliverToBoxAdapter(child: SizedBox(height: Space.x14)),
        ],
      ),
    );
  }

  List<Widget> _started(BuildContext context, WidgetRef ref, UserPlan user) {
    final p = context.palette;
    final s = user.state;
    final today = Days.today();
    final behind = s.behindBy(today);
    final day = s.currentDay;
    return [
      SliverToBoxAdapter(
        child: Reveal(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x6,
              Space.gutter,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedCount(
                  value: s.percent,
                  suffix: '%',
                  style: AppType.displayL.copyWith(
                    color: p.ink,
                    fontSize: 56,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(switch (s.status) {
                      PlanStatus.completed => 'Finished — well done.',
                      PlanStatus.paused => 'Paused. Your place is saved.',
                      PlanStatus.active when behind > 0 =>
                        '$behind ${behind == 1 ? 'day' : 'days'} behind — no rush.',
                      _ => 'On track',
                    }, style: AppType.body.copyWith(color: p.inkSoft)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x3,
            Space.gutter,
            0,
          ),
          child: ProgressBar(value: s.fraction, height: 10),
        ),
      ),
      if (s.status == PlanStatus.paused)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x5,
              Space.gutter,
              0,
            ),
            child: PillButton(
              label: 'Continue plan',
              icon: PhosphorIconsBold.play,
              expand: true,
              onPressed: () =>
                  ref.read(plansRepositoryProvider).resume(user.progressId),
            ),
          ),
        ),
      if (!s.isFinished)
        SliverToBoxAdapter(
          child: Reveal(
            index: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x6,
                Space.gutter,
                0,
              ),
              child: _DayCard(user: user, day: day, isToday: true),
            ),
          ),
        ),
      if (s.upcomingDays().isNotEmpty) ...[
        const SliverToBoxAdapter(child: SectionHeader(title: 'Coming up')),
        SliverList.builder(
          itemCount: s.upcomingDays().length,
          itemBuilder: (context, i) =>
              _DayRow(user: user, day: s.upcomingDays()[i]),
        ),
      ],
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'All days',
          actionLabel: '${s.completedCount} done',
        ),
      ),
      SliverList.builder(
        itemCount: s.totalDays,
        itemBuilder: (context, i) => _DayRow(user: user, day: i + 1),
      ),
    ];
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: Space.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.caption.copyWith(color: p.onPastel)),
          Text(value, style: AppType.titleS.copyWith(color: p.onPastel)),
        ],
      ),
    );
  }
}

class _NotStarted extends ConsumerWidget {
  const _NotStarted({required this.plan});

  final PlanDefinition plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.all(Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillButton(
            label: 'Start this plan',
            icon: PhosphorIconsBold.play,
            expand: true,
            onPressed: () async {
              Haptics.light();
              await ref.read(plansRepositoryProvider).start(plan.id);
            },
          ),
          const SizedBox(height: Space.x6),
          Text(
            'FIRST DAYS',
            style: AppType.overline.copyWith(color: p.inkMute),
          ),
          const SizedBox(height: Space.x2),
          for (var d = 1; d <= plan.totalDays && d <= 5; d++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      'Day $d',
                      style: AppType.label.copyWith(color: p.inkSoft),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      plan.labelFor(d),
                      style: AppType.body.copyWith(color: p.ink),
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

/// Today's reading: each passage opens the reader in plan mode.
class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.user,
    required this.day,
    required this.isToday,
  });

  final UserPlan user;
  final int day;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final passages = user.plan.readingFor(day);
    final done = user.state.completedDays.contains(day);
    return PastelCard(
      color: planColor(user.plan.category, p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DAY $day · ${DateFormat('EEE d MMM').format(Days.parse(user.state.dateOfDay(day, Days.today())))}',
            style: AppType.overline.copyWith(color: p.onPastel),
          ),
          const SizedBox(height: Space.x3),
          for (final pass in passages)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x2),
              child: Semantics(
                button: true,
                label: 'Read ${pass.label}',
                excludeSemantics: true,
                child: Pressable(
                  onTap: () async {
                    final completed = await context.push<bool>(
                      ReaderArgs.location(
                        VerseRef(
                          pass.bookId,
                          pass.startChapter,
                          pass.startVerse ?? 1,
                        ),
                        plan: user.progressId,
                        day: day,
                      ),
                    );
                    if (completed == true && context.mounted) {
                      final plans = await ref.read(userPlansProvider.future);
                      final now = plans
                          .where((u) => u.progressId == user.progressId)
                          .firstOrNull;
                      if (now != null &&
                          now.state.isFinished &&
                          context.mounted) {
                        await showPlanComplete(context, user.plan.title);
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.x4,
                      vertical: Space.x3,
                    ),
                    decoration: BoxDecoration(
                      color: p.onPastel.withValues(alpha: 0.08),
                      borderRadius: Radii.smAll,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.bookOpen,
                          color: p.onPastel,
                          size: 20,
                        ),
                        const SizedBox(width: Space.x3),
                        Expanded(
                          child: Text(
                            pass.label,
                            style: AppType.titleS.copyWith(color: p.onPastel),
                          ),
                        ),
                        Icon(
                          PhosphorIconsBold.arrowRight,
                          color: p.onPastel,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: Space.x2),
          PillButton(
            label: done ? 'Completed' : 'Mark day $day complete',
            icon: done
                ? PhosphorIconsBold.checkCircle
                : PhosphorIconsBold.check,
            variant: done ? PillVariant.tonal : PillVariant.primary,
            expand: true,
            onPressed: () => toggleDay(context, ref, user, day, !done),
          ),
        ],
      ),
    );
  }
}

Future<void> toggleDay(
  BuildContext context,
  WidgetRef ref,
  UserPlan user,
  int day,
  bool complete,
) async {
  if (complete) Haptics.success();
  final finished = await ref
      .read(plansRepositoryProvider)
      .setDayComplete(
        user.progressId,
        day,
        complete,
        totalDays: user.plan.totalDays,
      );
  if (complete) {
    // Plan readings count as reading too.
    for (final pass in user.plan.readingFor(day)) {
      for (final c in pass.chapters) {
        await ref.read(readingRepositoryProvider).recordChapterRead(c);
      }
    }
  }
  if (finished && context.mounted) {
    await showPlanComplete(context, user.plan.title);
  }
}

class _DayRow extends ConsumerWidget {
  const _DayRow({required this.user, required this.day});

  final UserPlan user;
  final int day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final m = Motion.of(context);
    final done = user.state.completedDays.contains(day);
    final current = day == user.state.currentDay && !user.state.isFinished;
    return Semantics(
      label: 'Day $day, ${user.plan.labelFor(day)}${done ? ', completed' : ''}',
      child: InkWell(
        onTap: () {
          final pass = user.plan.readingFor(day).first;
          context.push(
            ReaderArgs.location(
              VerseRef(pass.bookId, pass.startChapter, pass.startVerse ?? 1),
              plan: user.progressId,
              day: day,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.gutter,
            vertical: 10,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  'Day $day',
                  style: AppType.label.copyWith(
                    color: current ? p.tangerineText : p.inkSoft,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  user.plan.labelFor(day),
                  style: AppType.body.copyWith(
                    color: done ? p.inkMute : p.ink,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: p.inkMute,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: done ? 'Mark day $day not done' : 'Mark day $day done',
                child: Pressable(
                  onTap: () => toggleDay(context, ref, user, day, !done),
                  child: AnimatedContainer(
                    duration: m.fast,
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: done ? p.ink : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done ? p.ink : p.line,
                        width: 2,
                      ),
                    ),
                    child: done
                        ? Icon(
                            PhosphorIconsBold.check,
                            size: 16,
                            color: p.paper,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanMenu extends ConsumerWidget {
  const _PlanMenu({required this.user});

  final UserPlan user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final repo = ref.read(plansRepositoryProvider);
    final paused = user.state.status == PlanStatus.paused;
    return PopupMenuButton<String>(
      tooltip: 'Plan options',
      icon: Icon(PhosphorIconsBold.dotsThree, color: p.onPastel),
      color: p.surface,
      shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      onSelected: (v) async {
        switch (v) {
          case 'pause':
            await repo.pause(user.progressId);
          case 'resume':
            await repo.resume(user.progressId);
          case 'restart':
            if (await confirmDestructive(
              context,
              title: 'Restart plan?',
              message:
                  'Your ticked days will be cleared and day 1 starts today.',
              confirmLabel: 'Restart',
            )) {
              await repo.restart(user.progressId);
            }
          case 'remove':
            if (await confirmDestructive(
              context,
              title: 'Remove plan?',
              message: 'This stops the plan and clears its progress.',
              confirmLabel: 'Remove',
            )) {
              await repo.remove(user.progressId);
            }
        }
      },
      itemBuilder: (_) => [
        if (!user.state.isFinished)
          PopupMenuItem(
            value: paused ? 'resume' : 'pause',
            child: Text(paused ? 'Continue' : 'Pause'),
          ),
        const PopupMenuItem(value: 'restart', child: Text('Restart')),
        const PopupMenuItem(value: 'remove', child: Text('Remove')),
      ],
    );
  }
}
