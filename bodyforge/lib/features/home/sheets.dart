import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../domain/engine/quick_sessions.dart';
import '../../domain/engine/recovery.dart';
import '../../domain/engine/session_builder.dart';
import '../../domain/engine/time_fitter.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/workout.dart';
import '../player/player_controller.dart';

/// Recovery check (spec §9): three quick questions → how today's workout changes.
Future<void> showRecoveryCheck(BuildContext context) =>
    showBfSheet(context, builder: (_) => const _RecoverySheet());

class _RecoverySheet extends ConsumerStatefulWidget {
  const _RecoverySheet();
  @override
  ConsumerState<_RecoverySheet> createState() => _RecoverySheetState();
}

class _RecoverySheetState extends ConsumerState<_RecoverySheet> {
  SleepQuality? _sleep;
  Soreness? _sore;
  Energy? _energy;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final today = ref.read(todaysRecoveryProvider);
    if (today != null) {
      _sleep = today.check.sleep;
      _sore = today.check.soreness;
      _energy = today.check.energy;
    }
  }

  RecoveryCheck? get _check =>
      _sleep == null || _sore == null || _energy == null ? null : RecoveryCheck(sleep: _sleep!, soreness: _sore!, energy: _energy!);

  Widget _q<T extends Enum>(String title, IconData icon, List<T> values, T? current, String Function(T) label, void Function(T) set) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 18, color: context.bf.textMuted), const SizedBox(width: 6), Text(title, style: t.titleMedium)]),
        const SizedBox(height: Space.sm),
        Row(children: [
          for (final v in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _Choice(label: label(v), selected: current == v, onTap: () => setState(() => set(v))),
              ),
            ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final check = _check;
    final adj = check == null ? null : adjustForRecovery(check);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('How are you today?', style: t.headlineMedium),
        const SizedBox(height: 4),
        Text('Your answers adjust today\'s workout.', style: t.bodyMedium?.copyWith(color: c.textMuted)),
        const SizedBox(height: Space.xl),
        _q('How did you sleep?', BfIcons.moon, SleepQuality.values, _sleep, (v) => v.label, (v) => _sleep = v),
        _q('How sore are you?', BfIcons.sore, Soreness.values, _sore, (v) => v.label, (v) => _sore = v),
        _q('How is your energy?', BfIcons.energy, Energy.values, _energy, (v) => v.label, (v) => _energy = v),
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.medium),
          child: adj == null
              ? const SizedBox(height: 0)
              : BfCard(
                  key: ValueKey(adj.mode),
                  color: switch (adj.mode) {
                    RecoveryMode.full => c.primary,
                    RecoveryMode.trimmed => c.tertiary,
                    RecoveryMode.reduced => c.secondary,
                    RecoveryMode.recovery => c.secondary,
                  },
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Overline(adj.mode.label, color: BfPalette.ink.withValues(alpha: 0.7)),
                    const SizedBox(height: 4),
                    Text(adj.message, style: t.titleMedium?.copyWith(color: BfPalette.ink)),
                  ]),
                ),
        ),
        const SizedBox(height: Space.lg),
        BfButton(
          label: 'Save',
          loading: _saving,
          onPressed: check == null
              ? null
              : () async {
                  setState(() => _saving = true);
                  await ref.read(trainingRepoProvider).saveRecoveryCheck(check, adj!.mode);
                  if (context.mounted) Navigator.pop(context);
                },
        ),
      ]),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.tile,
      scale: 0.95,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.medium),
        curve: Motion.standard,
        height: 56,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surfaceRaised,
          borderRadius: Radii.tile,
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: selected ? BfPalette.ink : c.text)),
      ),
    );
  }
}

/// "How much time do you have?" (spec §8). Returns the minutes chosen.
Future<int?> pickTime(BuildContext context, {int? current}) => showBfSheet<int>(
      context,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('How much time do you have?', style: t.headlineMedium),
            const SizedBox(height: 4),
            Text('Your session is compressed or expanded — the objective stays the same.',
                style: t.bodyMedium?.copyWith(color: ctx.bf.textMuted)),
            const SizedBox(height: Space.xl),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Space.sm,
              crossAxisSpacing: Space.sm,
              childAspectRatio: 1.25,
              children: [
                for (var i = 0; i < kTimeOptions.length; i++)
                  Pressable(
                    onTap: () => Navigator.pop(ctx, kTimeOptions[i]),
                    borderRadius: Radii.tile,
                    child: Container(
                      decoration: BoxDecoration(
                        color: current == kTimeOptions[i] ? ctx.bf.primary : ctx.bf.surfaceRaised,
                        borderRadius: Radii.tile,
                      ),
                      alignment: Alignment.center,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(kTimeOptions[i] == 45 ? '45+' : '${kTimeOptions[i]}',
                            style: BfType.number(30,
                                color: current == kTimeOptions[i] ? BfPalette.ink : ctx.bf.text, weight: FontWeight.w700)),
                        Text('min',
                            style: t.labelSmall?.copyWith(color: current == kTimeOptions[i] ? BfPalette.ink : ctx.bf.textMuted)),
                      ]),
                    ),
                  ).enter(ctx, index: i),
              ],
            ),
          ]),
        );
      },
    );

/// "I don't feel like working out" (spec §7).
Future<void> showQuickMode(BuildContext context, WidgetRef ref) => showBfSheet(
      context,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        final c = ctx.bf;
        return Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Not feeling it?', style: t.headlineMedium),
            const SizedBox(height: 4),
            Text(kLowMotivationMessage, style: t.titleMedium?.copyWith(color: c.primary)),
            const SizedBox(height: Space.xl),
            for (var i = 0; i < QuickOption.values.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: BfCard(
                  color: [c.secondary, c.tertiary, c.primary][i],
                  onTap: () {
                    final plan = buildQuick(ref, QuickOption.values[i]);
                    Navigator.pop(ctx);
                    if (plan != null) openSession(context, ref, plan);
                  },
                  child: Row(children: [
                    Text('${QuickOption.values[i].minutes}', style: BfType.number(40, color: BfPalette.ink, weight: FontWeight.w700)),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('minutes', style: t.labelMedium?.copyWith(color: BfPalette.ink)),
                        Text(QuickOption.values[i].description, style: t.bodyMedium?.copyWith(color: BfPalette.ink.withValues(alpha: 0.75))),
                      ]),
                    ),
                    const Icon(BfIcons.forward, color: BfPalette.ink),
                  ]),
                ).enter(ctx, index: i),
              ),
          ]),
        );
      },
    );

WorkoutPlan? buildQuick(WidgetRef ref, QuickOption option) {
  final day = ref.read(missionDayProvider)?.planned ?? DayType.fullBody;
  final base = ref.read(sessionInputsProvider(day == DayType.rest || day == DayType.recovery ? DayType.fullBody : day));
  if (base == null) return null;
  return buildQuickSession(option, base, todaysDay: day);
}

/// Put [plan] on the preview screen.
void openSession(BuildContext context, WidgetRef ref, WorkoutPlan plan) {
  ref.read(pendingSessionProvider.notifier).set(plan);
  context.push('/session');
}

/// Build a full session for [day] and open the preview.
void openDay(BuildContext context, WidgetRef ref, DayType day, {int? minutes}) {
  final inputs = ref.read(sessionInputsProvider(day));
  if (inputs == null) return;
  var plan = SessionBuilder(minutes == null ? inputs : inputs.copyWith(minutes: minutes)).build();
  if (plan.kind == SessionKind.planned && day == DayType.benchmark) plan = plan.copyWith(kind: SessionKind.benchmark);
  openSession(context, ref, plan);
}
