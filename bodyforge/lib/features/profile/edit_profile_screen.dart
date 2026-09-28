import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/page.dart';
import '../../domain/engine/environment.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/profile.dart';

/// Edit one part of the profile. Changes to goals / schedule regenerate the
/// weekly plan (progress on every skill path is kept).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.section});
  final String section;
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  UserProfile? _p;
  late final TextEditingController _name;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _p = ref.read(profileProvider).value;
    _name = TextEditingController(text: _p?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final original = ref.read(profileProvider).value;
    var p = _p;
    if (p == null || original == null) return;
    if (_name.text.trim().length >= 2) p = p.copyWith(name: _name.text.trim());
    if (p.goals.isEmpty) {
      toast(context, 'Pick at least one goal');
      return;
    }
    setState(() => _saving = true);
    await ref.read(profileRepoProvider).saveProfile(p);
    final scheduleChanged = original.daysPerWeek != p.daysPerWeek ||
        original.sessionMinutes != p.sessionMinutes ||
        original.preferredDays.join() != p.preferredDays.join() ||
        !(original.goals.length == p.goals.length && original.goals.containsAll(p.goals));
    if (scheduleChanged) {
      final custom = ref.read(activeProgramProvider).value?.spec.custom ?? false;
      final regenerate = !custom ||
          (mounted &&
              await confirm(context,
                  title: 'Update your program?',
                  message: 'You\'re on a custom program. Replace it with a plan generated from your new preferences?',
                  confirmLabel: 'Replace'));
      if (regenerate) await ref.read(trainingServiceProvider).regenerateProgram(p);
    }
    if (original.weightKg != p.weightKg) {
      await ref.read(lifestyleRepoProvider).addMeasurement(MeasurementType.weight, p.weightKg);
    }
    if (mounted) context.popOr('/profile');
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    if (p == null) return const BfPage(title: 'Edit', children: []);
    final t = Theme.of(context).textTheme;
    final units = ref.watch(settingsProvider).units;
    final title = switch (widget.section) {
      'goals' => 'Goals',
      'fitness' => 'Fitness information',
      'preferences' => 'Preferences',
      _ => 'Body & limitations',
    };
    void set(UserProfile n) => setState(() => _p = n);
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return BfPage(
      title: title,
      bottom: BfButton(label: 'Save', loading: _saving, onPressed: _save),
      children: switch (widget.section) {
        'goals' => [
            for (final g in Goal.values)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: OptionCard(
                  title: g.label,
                  subtitle: g.description,
                  multi: true,
                  selected: p.goals.contains(g),
                  onTap: () => set(p.copyWith(goals: p.goals.contains(g) ? ({...p.goals}..remove(g)) : {...p.goals, g})),
                ),
              ),
          ],
        'fitness' => [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: Space.lg),
            const Overline('Fitness level'),
            const SizedBox(height: Space.sm),
            for (final l in FitnessLevel.values)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: OptionCard(title: l.label, subtitle: l.description, selected: p.level == l, onTap: () => set(p.copyWith(level: l))),
              ),
            const SizedBox(height: Space.md),
            const Overline('Experience'),
            const SizedBox(height: Space.sm),
            Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
              for (final e in TrainingExperience.values)
                PillChip(label: e.label, selected: p.experience == e, onTap: () => set(p.copyWith(experience: e))),
            ]),
            const SizedBox(height: Space.lg),
            _Stepper(
              label: 'Age',
              value: p.age.toDouble(),
              display: '${p.age}',
              min: 16,
              max: 100,
              step: 1,
              onChanged: (v) => set(p.copyWith(age: v.round())),
            ),
            _Stepper(
              label: 'Height',
              value: Units.lengthToDisplay(p.heightCm, units),
              display: Units.height(p.heightCm, units),
              min: units == UnitSystem.metric ? 120 : 48,
              max: units == UnitSystem.metric ? 230 : 90,
              step: 1,
              onChanged: (v) => set(p.copyWith(heightCm: Units.lengthFromDisplay(v, units))),
            ),
            _Stepper(
              label: 'Weight',
              value: Units.weightToDisplay(p.weightKg, units),
              display: Units.formatMeasurement(MeasurementType.weight, p.weightKg, units),
              min: units == UnitSystem.metric ? 30 : 70,
              max: units == UnitSystem.metric ? 200 : 440,
              step: 0.5,
              onChanged: (v) => set(p.copyWith(weightKg: Units.weightFromDisplay(v, units))),
            ),
            const SizedBox(height: Space.md),
            const Overline('Sex'),
            const SizedBox(height: Space.sm),
            Wrap(spacing: Space.xs, children: [
              for (final s in Sex.values) PillChip(label: s.label, selected: p.sex == s, onTap: () => set(p.copyWith(sex: s))),
            ]),
          ],
        'preferences' => [
            _Stepper(
              label: 'Workout days per week',
              value: p.daysPerWeek.toDouble(),
              display: '${p.daysPerWeek} days',
              min: 2,
              max: 7,
              step: 1,
              onChanged: (v) => set(p.copyWith(daysPerWeek: v.round(), preferredDays: const [])),
            ),
            const Overline('Preferred days'),
            const SizedBox(height: Space.sm),
            Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
              for (var d = 1; d <= 7; d++)
                PillChip(
                  label: names[d - 1],
                  dense: true,
                  selected: p.preferredDays.contains(d),
                  onTap: () {
                    final s = {...p.preferredDays};
                    if (s.contains(d)) {
                      s.remove(d);
                    } else if (s.length < p.daysPerWeek) {
                      s.add(d);
                    }
                    set(p.copyWith(preferredDays: s.toList()..sort()));
                  },
                ),
            ]),
            const SizedBox(height: Space.lg),
            const Overline('Workout length'),
            const SizedBox(height: Space.sm),
            Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
              for (final m in [10, 15, 20, 30, 45, 60])
                PillChip(label: '$m min', selected: p.sessionMinutes == m, onTap: () => set(p.copyWith(sessionMinutes: m))),
            ]),
            const SizedBox(height: Space.lg),
            const Overline('Default training space'),
            const SizedBox(height: Space.sm),
            for (final e in TrainingEnvironment.values)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: OptionCard(
                  title: e.label,
                  subtitle: kEnvironmentProfiles[e]!.note,
                  selected: p.environment == e,
                  onTap: () => set(p.copyWith(environment: e)),
                ),
              ),
            const SizedBox(height: Space.md),
            const Overline('Workout style'),
            const SizedBox(height: Space.sm),
            for (final s in WorkoutStyle.values)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: OptionCard(title: s.label, subtitle: s.description, selected: p.style == s, onTap: () => set(p.copyWith(style: s))),
              ),
          ],
        _ => [
            Text('We only give you exercises that suit your body.', style: t.bodyMedium),
            const SizedBox(height: Space.md),
            for (final (title, v, f) in [
              ('No jumping', p.limitations.noJumping, (bool x) => p.limitations.copyWith(noJumping: x)),
              ('Getting on the floor is hard', p.limitations.avoidFloor, (bool x) => p.limitations.copyWith(avoidFloor: x)),
              ('Sensitive knees', p.limitations.kneeSensitive, (bool x) => p.limitations.copyWith(kneeSensitive: x)),
              ('Sensitive wrists', p.limitations.wristSensitive, (bool x) => p.limitations.copyWith(wristSensitive: x)),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: OptionCard(title: title, selected: v, multi: true, onTap: () => set(p.copyWith(limitations: f(!v)))),
              ),
            const SizedBox(height: Space.lg),
            const Overline('Re-assess abilities'),
            const SizedBox(height: Space.xs),
            Text('Your skill paths already adapt every session. These only matter if you restart from scratch.', style: t.bodySmall),
          ],
      },
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.display, required this.min, required this.max, required this.step, required this.onChanged});
  final String label;
  final double value;
  final String display;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: BfCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Overline(label),
              Text(display, style: BfType.number(24, color: c.text)),
            ]),
          ),
          CircleIconButton(
              icon: Icons.remove_rounded,
              background: c.surfaceRaised,
              foreground: c.text,
              onTap: value - step >= min ? () => onChanged(value - step) : null),
          const SizedBox(width: Space.sm),
          CircleIconButton(icon: Icons.add_rounded, onTap: value + step <= max ? () => onChanged(value + step) : null),
        ]),
      ),
    );
  }
}
