import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/page.dart';
import '../../domain/engine/program_generator.dart';
import '../../domain/models/enums.dart';

/// Build your own program (spec §19).
class BuildProgramScreen extends ConsumerStatefulWidget {
  const BuildProgramScreen({super.key});
  @override
  ConsumerState<BuildProgramScreen> createState() => _BuildProgramScreenState();
}

enum _BuildGoal {
  muscle('Muscle', Goal.buildMuscle),
  strength('Strength', Goal.getStronger),
  fatLoss('Fat loss', Goal.loseFat),
  abs('Abs', Goal.visibleAbs),
  fullBody('Full body', Goal.fullTransformation);

  const _BuildGoal(this.label, this.goal);
  final String label;
  final Goal goal;
}

class _BuildProgramScreenState extends ConsumerState<BuildProgramScreen> {
  _BuildGoal _goal = _BuildGoal.muscle;
  int _days = 4;
  int _minutes = 30;
  final Set<MuscleFocus> _focus = {MuscleFocus.fullBody};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider).value;
    if (p != null) {
      _days = p.daysPerWeek.clamp(2, 7);
      _minutes = (p.sessionMinutes ~/ 5 * 5).clamp(5, 60);
    }
  }

  ProgramSpec get _spec => generateProgram(
        goals: {_goal.goal},
        daysPerWeek: _days,
        minutes: _minutes,
        focus: _focus,
        preferredDays: ref.read(profileProvider).value?.preferredDays ?? const [],
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(profileRepoProvider).activateProgram(_spec);
    if (!mounted) return;
    Haptics.heavy();
    toast(context, 'New program active from today');
    context.popOr('/workout');
  }

  Future<void> _restoreDefault() async {
    final p = ref.read(profileProvider).value;
    if (p == null) return;
    await ref.read(trainingServiceProvider).regenerateProgram(p);
    if (mounted) {
      toast(context, 'Back to your personalised plan');
      context.popOr('/workout');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final spec = _spec;
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return BfPage(
      title: 'Build your program',
      bottom: BfButton(label: 'Use this program', loading: _saving, onPressed: _focus.isEmpty ? null : _save),
      children: [
        const Overline('Goal'),
        const SizedBox(height: Space.sm),
        Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
          for (final g in _BuildGoal.values) PillChip(label: g.label, selected: _goal == g, onTap: () => setState(() => _goal = g)),
        ]).enter(context),
        const SizedBox(height: Space.lg),
        Row(children: [
          const Expanded(child: Overline('Training frequency')),
          Text('$_days days / week', style: BfType.number(16, color: c.text)),
        ]),
        Slider(value: _days.toDouble(), min: 2, max: 7, divisions: 5, label: '$_days', onChanged: (v) => setState(() => _days = v.round())),
        Row(children: [
          const Expanded(child: Overline('Duration')),
          Text('$_minutes min', style: BfType.number(16, color: c.text)),
        ]),
        Slider(value: _minutes.toDouble(), min: 5, max: 60, divisions: 11, label: '$_minutes', onChanged: (v) => setState(() => _minutes = v.round())),
        const SizedBox(height: Space.md),
        const Overline('Focus'),
        const SizedBox(height: Space.sm),
        Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
          for (final f in MuscleFocus.values)
            PillChip(
              label: f.label,
              selected: _focus.contains(f),
              onTap: () => setState(() => _focus.contains(f) ? _focus.remove(f) : _focus.add(f)),
            ),
        ]),
        const SizedBox(height: Space.lg),
        BfCard(
          color: c.secondary,
          rings: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Overline('Preview', color: BfPalette.ink.withValues(alpha: 0.6)),
            Text(spec.name, style: t.titleLarge?.copyWith(color: BfPalette.ink)),
            const SizedBox(height: Space.sm),
            for (final d in spec.days)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(width: 48, child: Text(names[d.weekday - 1], style: t.labelMedium?.copyWith(color: BfPalette.ink))),
                  Text(d.dayType.label, style: t.bodyMedium?.copyWith(color: BfPalette.ink)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: Space.md),
        TextButton.icon(onPressed: _restoreDefault, icon: const Icon(BfIcons.reset), label: const Text('Restore my personalised plan')),
      ],
    );
  }
}
