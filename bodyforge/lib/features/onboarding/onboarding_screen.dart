import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../domain/engine/environment.dart';
import '../../domain/engine/program_generator.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/local_date.dart';
import '../../domain/models/profile.dart';

/// Onboarding (spec §3): learns about the user, then forges the plan.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _step = 0;
  static const _steps = 10;

  // Draft answers.
  final _name = TextEditingController();
  int _age = 25;
  Sex _sex = Sex.male;
  double _heightCm = 170;
  double _weightKg = 70;
  FitnessLevel _level = FitnessLevel.beginner;
  TrainingExperience _exp = TrainingExperience.none;
  PushAbility _push = PushAbility.knee;
  SquatAbility _squat = SquatAbility.underTen;
  PlankAbility _plank = PlankAbility.twentyTo45;
  Limitations _lim = const Limitations();
  bool _healthOk = false;
  final Set<Goal> _goals = {};
  int _days = 3;
  final Set<int> _prefDays = {};
  int _minutes = 20;
  TrainingEnvironment _env = TrainingEnvironment.livingRoom;
  WorkoutStyle _style = WorkoutStyle.mixed;

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
        0 => _name.text.trim().length >= 2,
        1 => _age >= 16,
        5 => _healthOk,
        6 => _goals.isNotEmpty,
        _ => true,
      };

  void _next() {
    if (!_canContinue) return;
    FocusScope.of(context).unfocus();
    Haptics.light();
    if (_step < _steps - 1) {
      setState(() => _step++);
      _page.animateToPage(_step, duration: Motion.of(context, Motion.slow), curve: Motion.emphasized);
    }
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _page.animateToPage(_step, duration: Motion.of(context, Motion.slow), curve: Motion.emphasized);
  }

  UserProfile _draft() => UserProfile(
        id: '',
        name: _name.text.trim(),
        age: _age,
        sex: _sex,
        heightCm: _heightCm,
        weightKg: _weightKg,
        level: _level,
        experience: _exp,
        goals: {..._goals},
        daysPerWeek: _days,
        sessionMinutes: _minutes,
        environment: _env,
        limitations: _lim,
        preferredDays: _prefDays.length == _days ? (_prefDays.toList()..sort()) : const [],
        style: _style,
        pushAbility: _push,
        squatAbility: _squat,
        plankAbility: _plank,
        journeyStart: LocalDate.fromDateTime(DateTime.now()),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          if (_step < _steps - 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
              child: Row(children: [
                AnimatedOpacity(
                  opacity: _step == 0 ? 0 : 1,
                  duration: Motion.fast,
                  child: CircleIconButton(icon: BfIcons.back, onTap: _step == 0 ? null : _back, tooltip: 'Back'),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: ClipRRect(
                    borderRadius: Radii.pillAll,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: (_step + 1) / (_steps - 1)),
                      duration: Motion.of(context, Motion.slow),
                      curve: Motion.emphasized,
                      builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8),
                    ),
                  ),
                ),
                const SizedBox(width: Space.md),
                Text('${_step + 1}/${_steps - 1}', style: BfType.number(14, color: c.textMuted)),
              ]),
            ),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _about(),
                _ageSex(),
                _body(),
                _fitness(),
                _abilities(),
                _limits(),
                _goalsStep(),
                _schedule(),
                _space(),
                _Forge(draft: _draft, active: _step == _steps - 1),
              ],
            ),
          ),
          if (_step < _steps - 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.md),
              child: BfButton(
                label: _step == _steps - 2 ? 'Forge my plan' : 'Continue',
                trailingIcon: BfIcons.forward,
                onPressed: _canContinue ? _next : null,
              ),
            ),
        ]),
      ),
    );
  }

  // ─────────────────────────── steps ───────────────────────────

  Widget _stepShell({required String title, String? subtitle, String? image, required List<Widget> children}) {
    final t = Theme.of(context).textTheme;
    return ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.xl),
        children: [
          if (image != null) _ParallaxHero(image: image, controller: _page),
          Text(title, style: t.headlineLarge).enter(context),
          if (subtitle != null) ...[
            const SizedBox(height: Space.xs),
            Text(subtitle, style: t.bodyMedium?.copyWith(color: context.bf.textMuted)).enter(context, index: 1),
          ],
          const SizedBox(height: Space.xl),
          for (var i = 0; i < children.length; i++) children[i].enter(context, index: i + 2),
        ],
    );
  }

  Widget _about() => _stepShell(
        title: 'Let\'s build this around you.',
        subtitle: 'BODYFORGE doesn\'t give everyone the same workout. First, what should we call you?',
        image: Img.ama,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
            decoration: const InputDecoration(labelText: 'Your name'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _next(),
          ),
        ],
      );

  Widget _ageSex() => _stepShell(
        title: 'A little about you',
        subtitle: 'Used to set safe starting volumes. BODYFORGE is for ages 16+.',
        children: [
          _NumberDial(label: 'Age', value: _age, min: 16, max: 100, unit: 'years', onChanged: (v) => setState(() => _age = v)),
          const SizedBox(height: Space.lg),
          for (final s in Sex.values)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: OptionCard(title: s.label, selected: _sex == s, onTap: () => setState(() => _sex = s)),
            ),
        ],
      );

  Widget _body() {
    final units = ref.watch(settingsProvider).units;
    final imperial = units == UnitSystem.imperial;
    return _stepShell(
      title: 'Height & weight',
      subtitle: 'Weight lets us track your progress and suggest protein targets. Change units any time.',
      children: [
        Row(children: [
          for (final u in UnitSystem.values)
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              child: PillChip(
                label: u.label,
                selected: units == u,
                onTap: () => ref.read(settingsProvider.notifier).update((s) => s.copyWith(units: u)),
              ),
            ),
        ]),
        const SizedBox(height: Space.lg),
        _NumberDial(
          label: 'Height',
          value: Units.lengthToDisplay(_heightCm, units).round(),
          min: imperial ? 48 : 120,
          max: imperial ? 90 : 230,
          unit: imperial ? 'in · ${Units.height(_heightCm, units)}' : 'cm',
          onChanged: (v) => setState(() => _heightCm = Units.lengthFromDisplay(v.toDouble(), units)),
        ),
        const SizedBox(height: Space.lg),
        _NumberDial(
          label: 'Weight',
          value: Units.weightToDisplay(_weightKg, units).round(),
          min: imperial ? 70 : 30,
          max: imperial ? 440 : 200,
          unit: Units.weightUnit(units),
          onChanged: (v) => setState(() => _weightKg = Units.weightFromDisplay(v.toDouble(), units)),
        ),
      ],
    );
  }

  Widget _fitness() => _stepShell(
        title: 'Where are you starting?',
        subtitle: 'Be honest — the plan adapts either way.',
        children: [
          for (final l in FitnessLevel.values)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: OptionCard(title: l.label, subtitle: l.description, selected: _level == l, onTap: () => setState(() => _level = l)),
            ),
          const SizedBox(height: Space.md),
          const Overline('Training experience'),
          const SizedBox(height: Space.sm),
          Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
            for (final e in TrainingExperience.values)
              PillChip(label: e.label, selected: _exp == e, onTap: () => setState(() => _exp = e)),
          ]),
        ],
      );

  Widget _abilities() {
    Widget group<T>(String label, IconData icon, List<T> values, T current, String Function(T) name, void Function(T) set) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 18, color: context.bf.textMuted), const SizedBox(width: 6), Overline(label)]),
          const SizedBox(height: Space.sm),
          Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
            for (final v in values) PillChip(label: name(v), selected: current == v, onTap: () => setState(() => set(v))),
          ]),
          const SizedBox(height: Space.lg),
        ]);
    return _stepShell(
      title: 'Current abilities',
      subtitle: 'This places you on each skill path. In one go, with good form:',
      image: Img.onboardingGoals,
      children: [
        group('Push-ups', BfIcons.forAchievement('push'), PushAbility.values, _push, (v) => v.label, (v) => _push = v),
        group('Squats', BfIcons.forAchievement('legs'), SquatAbility.values, _squat, (v) => v.label, (v) => _squat = v),
        group('Plank hold', BfIcons.timer, PlankAbility.values, _plank, (v) => v.label, (v) => _plank = v),
      ],
    );
  }

  Widget _limits() {
    final t = Theme.of(context).textTheme;
    Widget toggle(String title, String sub, bool v, Limitations Function(bool) f) => Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: OptionCard(title: title, subtitle: sub, selected: v, multi: true, onTap: () => setState(() => _lim = f(!v))),
        );
    return _stepShell(
      title: 'Anything we should know?',
      subtitle: 'Pick any that apply. We\'ll only give you exercises that suit you.',
      children: [
        toggle('No jumping', 'Joint-friendly, quiet options only', _lim.noJumping, (v) => _lim.copyWith(noJumping: v)),
        toggle('Getting on the floor is hard', 'Standing and wall-based options', _lim.avoidFloor, (v) => _lim.copyWith(avoidFloor: v)),
        toggle('Sensitive knees', 'Skip deep single-leg and jumping knee work', _lim.kneeSensitive,
            (v) => _lim.copyWith(kneeSensitive: v)),
        toggle('Sensitive wrists', 'Skip the hardest hand-balancing moves', _lim.wristSensitive,
            (v) => _lim.copyWith(wristSensitive: v)),
        const SizedBox(height: Space.md),
        BfCard(
          color: context.bf.surfaceRaised,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(BfIcons.heart, color: context.bf.danger, size: 18),
              const SizedBox(width: Space.xs),
              Text('Health check', style: t.titleSmall),
            ]),
            const SizedBox(height: Space.xs),
            Text(
              'If you have a heart condition, chest pain, dizziness, a recent injury or are pregnant, talk to a health '
              'professional before starting. Stop any exercise that causes pain.',
              style: t.bodySmall,
            ),
            const SizedBox(height: Space.sm),
            OptionCard(
              title: 'I understand and I\'m ready to train',
              selected: _healthOk,
              multi: true,
              onTap: () => setState(() => _healthOk = !_healthOk),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _goalsStep() => _stepShell(
        title: 'What are you forging?',
        subtitle: 'Choose one or more goals.',
        children: [
          for (final g in Goal.values)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: OptionCard(
                title: g.label,
                subtitle: g.description,
                multi: true,
                selected: _goals.contains(g),
                onTap: () => setState(() => _goals.contains(g) ? _goals.remove(g) : _goals.add(g)),
              ),
            ),
        ],
      );

  Widget _schedule() {
    final t = Theme.of(context).textTheme;
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final preview = generateProgram(goals: _goals, daysPerWeek: _days, minutes: _minutes, preferredDays: _prefDays.toList());
    return _stepShell(
      title: 'Your week',
      subtitle: 'How often and how long? You can always do less on busy days.',
      children: [
        _NumberDial(label: 'Workout days per week', value: _days, min: 2, max: 7, unit: 'days', onChanged: (v) {
          setState(() {
            _days = v;
            if (_prefDays.length > v) _prefDays.clear();
          });
        }),
        const SizedBox(height: Space.lg),
        Overline('Preferred days (optional — pick $_days)'),
        const SizedBox(height: Space.sm),
        Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
          for (var d = 1; d <= 7; d++)
            PillChip(
              label: names[d - 1],
              dense: true,
              selected: _prefDays.contains(d),
              onTap: () => setState(() {
                if (_prefDays.contains(d)) {
                  _prefDays.remove(d);
                } else if (_prefDays.length < _days) {
                  _prefDays.add(d);
                }
              }),
            ),
        ]),
        const SizedBox(height: Space.lg),
        const Overline('Preferred workout length'),
        const SizedBox(height: Space.sm),
        Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
          for (final m in [10, 15, 20, 30, 45, 60])
            PillChip(label: '$m min', selected: _minutes == m, onTap: () => setState(() => _minutes = m)),
        ]),
        const SizedBox(height: Space.lg),
        BfCard(
          color: context.bf.surface,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Overline('Your week will look like'),
            const SizedBox(height: Space.sm),
            for (final d in preview.days)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(width: 48, child: Text(names[d.weekday - 1], style: t.labelMedium)),
                  Text(d.dayType.label, style: t.bodyMedium),
                ]),
              ),
          ]),
        ),
      ],
    );
  }

  Widget _space() => _stepShell(
        title: 'Where will you train?',
        subtitle: 'Exercises are filtered to fit. You can switch any day.',
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Space.sm,
            crossAxisSpacing: Space.sm,
            childAspectRatio: 0.95,
            children: [
              for (final e in TrainingEnvironment.values) _EnvTile(env: e, selected: _env == e, onTap: () => setState(() => _env = e)),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(kEnvironmentProfiles[_env]!.note, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Space.lg),
          const Overline('Workout style'),
          const SizedBox(height: Space.sm),
          for (final s in WorkoutStyle.values)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: OptionCard(title: s.label, subtitle: s.description, selected: _style == s, onTap: () => setState(() => _style = s)),
            ),
        ],
      );
}

class _ParallaxHero extends StatelessWidget {
  const _ParallaxHero({required this.image, required this.controller});
  final String image;
  final PageController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: SizedBox(
        height: 170,
        child: BfCard(
          color: context.bf.secondary,
          rings: true,
          padding: EdgeInsets.zero,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final p = controller.hasClients && controller.position.haveDimensions ? (controller.page ?? 0) : 0.0;
              final frac = p - p.floorToDouble();
              return Transform.translate(offset: Offset(-frac * 60, 0), child: child);
            },
            child: Padding(
              padding: const EdgeInsets.only(top: Space.md),
              child: AppImage(image, alignment: Alignment.bottomCenter),
            ),
          ),
        ),
      ).animate().fadeIn(duration: Motion.of(context, Motion.slow)).scale(
            begin: const Offset(0.96, 0.96),
            end: const Offset(1, 1),
            curve: Motion.emphasized,
            duration: Motion.of(context, Motion.slow),
          ),
    );
  }
}

class _EnvTile extends StatelessWidget {
  const _EnvTile({required this.env, required this.selected, required this.onTap});
  final TrainingEnvironment env;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.tile,
      scale: 0.97,
      semanticLabel: env.label,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.medium),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surface,
          borderRadius: Radii.tile,
          border: Border.all(color: selected ? Colors.transparent : c.outline),
        ),
        padding: const EdgeInsets.all(Space.sm),
        child: Column(children: [
          Expanded(child: AppImage(Img.environment(env), alignment: Alignment.center)),
          const SizedBox(height: Space.xs),
          Text(env.label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: selected ? BfPalette.ink : c.text)),
        ]),
      ),
    );
  }
}

/// Big number with − / + steppers and hold-to-repeat.
class _NumberDial extends StatelessWidget {
  const _NumberDial({required this.label, required this.value, required this.min, required this.max, required this.unit, required this.onChanged});
  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    void set(int v) {
      final nv = v.clamp(min, max);
      if (nv != value) {
        HapticFeedback.selectionClick();
        onChanged(nv);
      }
    }

    return BfCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Overline(label),
        const SizedBox(height: Space.sm),
        Row(children: [
          CircleIconButton(icon: BfIcons.remove, onTap: () => set(value - 1), background: c.surfaceRaised, foreground: c.text),
          Expanded(
            child: Column(children: [
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.fast),
                transitionBuilder: (w, a) => ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: w)),
                child: Text('$value', key: ValueKey(value), style: BfType.number(44, color: c.text)),
              ),
              Text(unit, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          CircleIconButton(icon: BfIcons.add, onTap: () => set(value + 1)),
        ]),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value',
          onChanged: (v) => set(v.round()),
        ),
      ]),
    );
  }
}

/// Final step: animated "forging" reveal, then save and go.
class _Forge extends ConsumerStatefulWidget {
  const _Forge({required this.draft, required this.active});
  final UserProfile Function() draft;
  final bool active;
  @override
  ConsumerState<_Forge> createState() => _ForgeState();
}

class _ForgeState extends ConsumerState<_Forge> {
  bool _started = false;
  String? _error;
  ProgramSpec? _spec;

  @override
  void didUpdateWidget(_Forge old) {
    super.didUpdateWidget(old);
    if (widget.active && !_started) _run();
  }

  Future<void> _run() async {
    _started = true;
    final draft = widget.draft();
    setState(() => _spec = generateProgram(
        goals: draft.goals, daysPerWeek: draft.daysPerWeek, minutes: draft.sessionMinutes, preferredDays: draft.preferredDays));
    await Future<void>.delayed(Duration(milliseconds: Motion.reduced(context) ? 400 : 2600));
    try {
      await ref.read(trainingServiceProvider).completeOnboarding(draft);
      Haptics.heavy();
      // The router moves to Home as soon as the profile exists.
    } catch (e) {
      setState(() => _error = 'Couldn\'t save your plan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final t = Theme.of(context).textTheme;
    final spec = _spec;
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.all(Space.gutter),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          height: 220,
          child: Stack(alignment: Alignment.center, children: [
            RingProgress(progress: widget.active ? 1 : 0, size: 200, stroke: 10, duration: const Duration(milliseconds: 2400),
                gradient: [c.primary, c.secondary, c.primary]),
            const SizedBox(height: 170, child: AppImage(Img.onboardingPlan, alignment: Alignment.center)),
          ]),
        ),
        const SizedBox(height: Space.xl),
        Text('Forging your plan…', style: t.headlineMedium).animate().fadeIn(duration: Motion.of(context, Motion.slow)),
        const SizedBox(height: Space.lg),
        if (spec != null)
          for (var i = 0; i < spec.days.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 56, child: Text(names[spec.days[i].weekday - 1], style: t.labelMedium?.copyWith(color: c.textMuted))),
                Expanded(child: Text(spec.days[i].dayType.label, style: t.titleMedium)),
                Icon(BfIcons.check, color: c.primary, size: 20),
              ]),
            ).animate(delay: (400 + i * 260).ms).fadeIn(duration: Motion.of(context, Motion.medium)).moveX(begin: 16, end: 0),
        if (_error != null) Text(_error!, style: t.bodyMedium?.copyWith(color: c.danger)),
      ]),
    );
  }
}
