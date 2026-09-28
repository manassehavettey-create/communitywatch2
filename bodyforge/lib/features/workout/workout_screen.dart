import 'package:flutter/material.dart';
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
import '../../domain/catalog/exercises.dart';
import '../../domain/catalog/skill_paths.dart';
import '../../domain/engine/calendar.dart';
import '../../domain/engine/journey.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/exercise.dart';
import '../exercise/exercise_figure.dart';
import '../home/sheets.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});
  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  int _tab = 0;
  static const _tabs = ['Plan', 'Skills', 'Library', 'Build'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.sm),
            child: Text('Workout', style: t.displaySmall),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: Space.xs),
                    child: PillChip(label: _tabs[i], selected: _tab == i, onTap: () => setState(() => _tab = i)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.medium),
              transitionBuilder: (w, a) => FadeTransition(opacity: a, child: w),
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: switch (_tab) {
                  0 => const _PlanTab(),
                  1 => const _SkillsTab(),
                  2 => const _LibraryTab(),
                  _ => const _BuildTab(),
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

class _PlanTab extends ConsumerWidget {
  const _PlanTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(activeProgramProvider).value;
    final today = ref.watch(todayProvider);
    final cal = {for (final d in ref.watch(calendarProvider)) d.date: d};
    final journey = ref.watch(journeyProvider);
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    if (program == null) return const Padding(padding: EdgeInsets.all(Space.gutter), child: Shimmer());
    final week = today.startOfWeek;
    final colors = [c.primary, c.secondary, c.tertiary, c.surface];
    var i = 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 120),
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Overline(program.spec.custom ? 'Your custom program' : 'Your program'),
              Text(program.spec.name, style: t.titleLarge),
            ]),
          ),
          TextButton(onPressed: () => context.push('/build'), child: const Text('Change')),
        ]).enter(context, index: i++),
        const SizedBox(height: Space.md),
        for (var d = 0; d < 7; d++)
          () {
            final date = week.addDays(d);
            final type = program.spec.dayTypeFor(date);
            final status = cal[date]?.status;
            final isToday = date == today;
            if (type == DayType.rest) {
              return Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Row(children: [
                  SizedBox(width: 100, child: Text(_dayNames[d], style: t.labelMedium?.copyWith(color: c.textMuted))),
                  Text('Rest', style: t.bodyMedium?.copyWith(color: c.textFaint)),
                ]),
              ).enter(context, index: i++);
            }
            final bg = isToday ? c.primary : (type == DayType.recovery ? c.tertiary : colors[(d + 1) % 2 + 1]);
            return Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: BfCard(
                color: bg,
                onTap: () => openDay(context, ref, type),
                padding: EdgeInsets.zero,
                rings: isToday,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 108),
                  child: Stack(alignment: AlignmentDirectional.centerStart, children: [
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 110,
                      child: AppImage(Img.forDay(type), alignment: Alignment.bottomRight),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 104),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Overline(isToday ? 'Today · ${_dayNames[d]}' : _dayNames[d], color: BfPalette.ink.withValues(alpha: 0.6)),
                          const SizedBox(height: 4),
                          Text(type.label, style: t.titleLarge?.copyWith(color: BfPalette.ink)),
                          const SizedBox(height: 2),
                          Text(
                            switch (status) {
                              DayStatus.completed => 'Done ✓',
                              DayStatus.modified => 'Done (modified) ✓',
                              DayStatus.recovery => 'Recovery done ✓',
                              DayStatus.missed => 'Missed — no stress, keep going',
                              _ => '${program.spec.minutes} min',
                            },
                            style: t.bodySmall?.copyWith(color: BfPalette.ink.withValues(alpha: 0.7)),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ).enter(context, index: i++);
          }(),
        const SizedBox(height: Space.md),
        if (journey != null && kBenchmarkWeeks.contains(journey.currentWeek))
          BfCard(
            color: c.ember,
            onTap: () => openDay(context, ref, DayType.benchmark),
            child: Row(children: [
              const Icon(BfIcons.test, color: BfPalette.ink),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Benchmark week', style: t.titleMedium?.copyWith(color: BfPalette.ink)),
                  Text('Test your push-ups, squats and plank to see your records move.',
                      style: t.bodySmall?.copyWith(color: BfPalette.ink.withValues(alpha: 0.75))),
                ]),
              ),
              const Icon(BfIcons.chevronRight, color: BfPalette.ink),
            ]),
          ).enter(context, index: i++),
        const SizedBox(height: Space.sm),
        BfCard(
          onTap: () => openDay(context, ref, DayType.recovery, minutes: 15),
          child: Row(children: [
            Icon(BfIcons.leaf, color: c.secondary),
            const SizedBox(width: Space.sm),
            Expanded(child: Text('Recovery flow · 15 min mobility', style: t.titleSmall)),
            const Icon(BfIcons.chevronRight),
          ]),
        ).enter(context, index: i++),
      ],
    );
  }
}

class _SkillsTab extends ConsumerWidget {
  const _SkillsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider).value;
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    if (progress == null) return const Padding(padding: EdgeInsets.all(Space.gutter), child: Shimmer());
    final colors = [c.primary, c.secondary, c.tertiary, c.surface, c.surface, c.surface];
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 120),
      children: [
        Text('Progress through each path — every level is a real, harder variation.', style: t.bodyMedium?.copyWith(color: c.textMuted))
            .enter(context),
        const SizedBox(height: Space.md),
        for (var i = 0; i < kSkillPaths.length; i++)
          () {
            final path = kSkillPaths[i];
            final p = progress[path.id];
            final node = p?.nodeIndex ?? 0;
            final current = exerciseById(path.node(node).exerciseId);
            final next = node + 1 < path.length ? exerciseById(path.node(node + 1).exerciseId) : null;
            final bg = colors[i];
            final fg = c.onColor(bg);
            return Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: BfCard(
                color: bg,
                onTap: () => context.push('/skills/${path.id}'),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Overline(path.name, color: fg.withValues(alpha: 0.6)),
                      const SizedBox(height: 4),
                      Text(current.name, style: t.titleLarge?.copyWith(color: fg)),
                      Text(next == null ? 'Path mastered' : 'Next: ${next.name}', style: t.bodySmall?.copyWith(color: fg.withValues(alpha: 0.7))),
                      const SizedBox(height: Space.sm),
                      Row(children: [
                        for (var n = 0; n < path.length; n++)
                          Expanded(
                            child: Container(
                              height: 6,
                              margin: const EdgeInsets.only(right: 3),
                              decoration: BoxDecoration(
                                color: n <= node ? fg : fg.withValues(alpha: 0.15),
                                borderRadius: Radii.pillAll,
                              ),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      Text('Level ${node + 1} of ${path.length} · Goal: ${path.goalLabel}', style: t.labelSmall?.copyWith(color: fg.withValues(alpha: 0.7))),
                    ]),
                  ),
                  const SizedBox(width: Space.sm),
                  SizedBox(width: 80, height: 80, child: AppImage(Img.forPath(path.id), alignment: Alignment.center)),
                ]),
              ),
            ).enter(context, index: i + 1);
          }(),
      ],
    );
  }
}

class _LibraryTab extends ConsumerStatefulWidget {
  const _LibraryTab();
  @override
  ConsumerState<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<_LibraryTab> {
  String _q = '';
  Area? _area;
  bool _fits = true;
  bool _mobility = false;

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(filterProvider);
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final list = kExercises.where((e) {
      if (_q.isNotEmpty && !e.name.toLowerCase().contains(_q.toLowerCase())) return false;
      if (_area != null && e.area != _area) return false;
      if (_fits && !filter.allows(e)) return false;
      if (_mobility != e.mobility) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.difficulty.compareTo(b.difficulty));
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 120),
      children: [
        TextField(
          decoration: const InputDecoration(hintText: 'Search exercises', prefixIcon: Icon(BfIcons.search)),
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: Space.sm),
        Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
          PillChip(label: 'All', dense: true, selected: _area == null, onTap: () => setState(() => _area = null)),
          for (final a in Area.values)
            PillChip(label: a.label, dense: true, selected: _area == a, onTap: () => setState(() => _area = a)),
          PillChip(label: 'Mobility', dense: true, selected: _mobility, onTap: () => setState(() => _mobility = !_mobility)),
          PillChip(
            label: 'Fits ${filter.environment.label.toLowerCase()}',
            icon: BfIcons.location,
            dense: true,
            selected: _fits,
            onTap: () => setState(() => _fits = !_fits),
          ),
        ]),
        const SizedBox(height: Space.md),
        if (list.isEmpty)
          const EmptyState(image: Img.emptySearch, title: 'No matches', message: 'Try another search or filter.'),
        for (var i = 0; i < list.length; i++) _LibraryRow(ex: list[i], reason: filter.reason(list[i])).enter(context, index: i),
        const SizedBox(height: Space.md),
        Text('${list.length} of ${kExercises.length} exercises', textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: c.textFaint)),
      ],
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.ex, required this.reason});
  final Exercise ex;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: BfCard(
        padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.md, Space.sm),
        onTap: () => context.push('/exercise/${ex.id}'),
        child: Row(children: [
          Hero(
            tag: 'ex-${ex.id}',
            child: Container(
              width: 74,
              height: 54,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: c.isDark ? c.sheet : c.surfaceRaised, borderRadius: Radii.small),
              child: ExerciseFigure(demo: ex.demo, playing: false, color: BfPalette.ink),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ex.name, style: t.titleSmall),
              Text(reason ?? '${ex.area.label} · level ${ex.difficulty}',
                  style: t.bodySmall?.copyWith(color: reason == null ? c.textMuted : c.warning)),
            ]),
          ),
          Text('${ex.difficulty}', style: BfType.number(18, color: c.textMuted)),
        ]),
      ),
    );
  }
}

class _BuildTab extends ConsumerWidget {
  const _BuildTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 120),
      children: [
        BfCard(
          color: c.secondary,
          rings: true,
          padding: const EdgeInsets.all(Space.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Overline('Build your own', color: BfPalette.ink),
            const SizedBox(height: 4),
            Text('Your goal. Your days. Your focus.', style: t.headlineMedium?.copyWith(color: BfPalette.ink)),
            const SizedBox(height: Space.sm),
            Text('Pick a goal, 2–7 days, 5–60 minutes and the areas you want to focus on. BODYFORGE structures the rest — and it still adapts.',
                style: t.bodyMedium?.copyWith(color: BfPalette.ink.withValues(alpha: 0.75))),
            const SizedBox(height: Space.lg),
            BfButton(label: 'Build a program', kind: BfButtonKind.dark, trailingIcon: BfIcons.forward, onPressed: () => context.push('/build')),
          ]),
        ).enter(context),
        const SizedBox(height: Space.md),
        BfCard(
          onTap: () => showQuickMode(context, ref),
          child: Row(children: [
            Icon(BfIcons.bolt, color: c.primary),
            const SizedBox(width: Space.sm),
            Expanded(child: Text('Quick session: 5, 10 or 15 minutes', style: t.titleSmall)),
            const Icon(BfIcons.chevronRight),
          ]),
        ).enter(context, index: 1),
      ],
    );
  }
}
