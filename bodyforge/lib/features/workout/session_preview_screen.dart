import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/assets.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/navigation.dart';
import '../../core/widgets/page.dart';
import '../../domain/catalog/exercises.dart';
import '../../domain/engine/environment.dart';
import '../../domain/engine/session_builder.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/workout.dart';
import '../exercise/exercise_figure.dart';
import '../home/sheets.dart';
import '../player/player_controller.dart';

class SessionPreviewScreen extends ConsumerStatefulWidget {
  const SessionPreviewScreen({super.key});
  @override
  ConsumerState<SessionPreviewScreen> createState() => _SessionPreviewScreenState();
}

class _SessionPreviewScreenState extends ConsumerState<SessionPreviewScreen> {
  bool _starting = false;

  SessionBuilder? _builderFor(WorkoutPlan plan, {TrainingEnvironment? env}) {
    final day = plan.dayType == DayType.benchmark ? DayType.benchmark : plan.dayType;
    final base = ref.read(sessionInputsProvider(day));
    if (base == null) return null;
    final p = ref.read(profileProvider).value;
    final filter = env == null ? base.filter : ExerciseFilter(env, p?.limitations ?? base.filter.limitations);
    return SessionBuilder(SessionInputs(
      dayType: day,
      params: base.params,
      progress: base.progress,
      filter: filter,
      minutes: plan.targetMinutes ?? base.minutes,
      weakest: base.weakest,
      style: base.style,
      focus: base.focus,
      seed: base.seed,
      recovery: plan.kind == SessionKind.lowMotivation ? base.recovery : base.recovery,
      bestRecords: base.bestRecords,
      kind: plan.kind,
    ));
  }

  Future<void> _changeTime(WorkoutPlan plan) async {
    final m = await pickTime(context, current: plan.targetMinutes);
    if (m == null) return;
    final b = _builderFor(plan);
    if (b == null) return;
    ref.read(pendingSessionProvider.notifier).set(b.refit(plan, m));
  }

  Future<void> _changeSpace(WorkoutPlan plan) async {
    final env = await showBfSheet<TrainingEnvironment>(context, builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Where are you training?', style: t.headlineMedium),
          const SizedBox(height: Space.md),
          for (final e in TrainingEnvironment.values)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: OptionCard(
                title: e.label,
                subtitle: kEnvironmentProfiles[e]!.note,
                selected: ref.read(profileProvider).value?.environment == e,
                leading: SizedBox(width: 44, height: 44, child: AppImage(Img.environment(e), alignment: Alignment.center)),
                onTap: () => Navigator.pop(ctx, e),
              ),
            ),
        ]),
      );
    });
    if (env == null) return;
    await ref.read(profileRepoProvider).setEnvironment(env);
    final b = _builderFor(plan, env: env);
    if (b == null) return;
    final rebuilt = plan.dayType == DayType.recovery ? b.buildRecovery(plan.targetMinutes ?? 15) : b.build();
    ref.read(pendingSessionProvider.notifier).set(rebuilt.copyWith(title: plan.title, kind: plan.kind, notes: plan.notes));
  }

  Future<void> _start(WorkoutPlan plan) async {
    if (_starting) return;
    setState(() => _starting = true);
    final existing = await ref.read(trainingRepoProvider).getActiveSession();
    if (existing != null && !existing.isFinished && mounted) {
      final replace = await confirm(context,
          title: 'Replace the workout in progress?',
          message: 'You have an unfinished workout. Starting a new one discards it.',
          confirmLabel: 'Start new',
          destructive: true);
      if (!replace) {
        setState(() => _starting = false);
        return;
      }
    }
    await ref.read(playerProvider.notifier).start(plan, recoveryCheckId: ref.read(todaysRecoveryProvider)?.id);
    ref.read(pendingSessionProvider.notifier).clear();
    if (mounted) context.pushReplacement('/player');
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(pendingSessionProvider);
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    if (plan == null) {
      return BfPage(title: 'Session', children: [
        EmptyState(image: Img.emptyWorkouts, title: 'Nothing queued', message: 'Pick a workout from Home or your plan.', action: 'Go home', onAction: () => context.go('/home')),
      ]);
    }
    var i = 0;
    return BfPage(
      title: plan.title,
      bottom: SwipeToStart(label: 'Start workout', onComplete: () => _start(plan)),
      children: [
        Hero(
          tag: 'mission',
          child: Material(
            type: MaterialType.transparency,
            child: BfCard(
              color: plan.dayType == DayType.recovery ? c.secondary : c.primary,
              rings: true,
              padding: const EdgeInsets.all(Space.xl),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Overline(plan.kind.label, color: BfPalette.ink.withValues(alpha: 0.6)),
                    const SizedBox(height: 4),
                    Text(plan.objective, style: t.titleLarge?.copyWith(color: BfPalette.ink)),
                    const SizedBox(height: Space.md),
                    Row(children: [
                      _Stat(value: '${plan.estimatedMinutes}', label: 'min'),
                      const SizedBox(width: Space.lg),
                      _Stat(value: '${plan.workExercises.length}', label: 'exercises'),
                      const SizedBox(width: Space.lg),
                      _Stat(value: plan.difficultyLabel, label: 'level', small: true),
                    ]),
                  ]),
                ),
                SizedBox(width: 90, height: 120, child: AppImage(Img.forDay(plan.dayType))),
              ]),
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        Row(children: [
          Expanded(
            child: PillChip(
              label: plan.targetMinutes == null ? 'Time' : '${plan.targetMinutes == 45 ? '45+' : plan.targetMinutes} min',
              icon: BfIcons.time,
              selected: false,
              onTap: () => _changeTime(plan),
            ),
          ),
          const SizedBox(width: Space.xs),
          Expanded(
            child: PillChip(
              label: ref.watch(profileProvider).value?.environment.label ?? 'Space',
              icon: BfIcons.location,
              selected: false,
              onTap: () => _changeSpace(plan),
            ),
          ),
        ]),
        for (final n in plan.notes)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: BfCard(
              color: c.surfaceRaised,
              padding: const EdgeInsets.all(Space.md),
              child: Row(children: [
                Icon(BfIcons.tip, color: c.primary, size: 18),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(n, style: t.bodyMedium)),
              ]),
            ),
          ).enter(context, index: i++),
        for (final b in plan.blocks) ...[
          const SizedBox(height: Space.lg),
          Row(children: [
            Text(b.kind.label, style: t.headlineSmall),
            const Spacer(),
            if (b.circuit && b.rounds > 1) Text('${b.rounds} rounds', style: t.labelMedium?.copyWith(color: c.textMuted)),
            Text('  ·  ${(b.estimatedSeconds / 60).ceil()} min', style: t.labelMedium?.copyWith(color: c.textMuted)),
          ]).enter(context, index: i++),
          const SizedBox(height: Space.sm),
          for (final e in b.exercises) _ExerciseRow(item: e, circuit: b.circuit).enter(context, index: i++),
        ],
        const SizedBox(height: Space.lg),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.small = false});
  final String value;
  final String label;
  final bool small;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: BfType.number(small ? 16 : 26, color: BfPalette.ink, weight: FontWeight.w700)),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: BfPalette.ink.withValues(alpha: 0.6))),
      ]);
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.item, required this.circuit});
  final PlannedExercise item;
  final bool circuit;

  @override
  Widget build(BuildContext context) {
    final ex = exerciseById(item.exerciseId);
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final amount = ex.isTimed ? '${item.amount}s' : '${item.amount}';
    final rx = circuit ? '$amount${ex.perSide ? ' / side' : ''}' : '${item.sets} × $amount${ex.perSide ? ' / side' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: BfCard(
        padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.md, Space.sm),
        onTap: () => context.push('/exercise/${ex.id}'),
        child: Row(children: [
          Container(
              width: 74,
              height: 54,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: c.isDark ? c.sheet : c.surfaceRaised, borderRadius: Radii.small),
              child: ExerciseFigure(demo: ex.demo, playing: false, color: BfPalette.ink),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ex.name, style: t.titleSmall),
              const SizedBox(height: 2),
              Text(
                [rx, if (!circuit && item.restSec >= 10) 'rest ${item.restSec}s'].join('  ·  '),
                style: t.bodySmall,
              ),
            ]),
          ),
          if (item.role == SlotRole.primary) Icon(BfIcons.star, size: 16, color: c.primary),
        ]),
      ),
    );
  }
}
