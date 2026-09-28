import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/application/app_actions.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skill_icons.dart';
import '../../../core/widgets/states.dart';
import '../../skills/application/skill_providers.dart';
import '../../skills/data/milestone_repository.dart';
import '../../skills/data/skill_repository.dart';
import '../../skills/presentation/level_up.dart';
import '../application/timer_providers.dart';

class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key, this.initialSkillId});

  final int? initialSkillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(activeTimerProvider);
    return AsyncView(
      value: timer,
      onRetry: () => ref.invalidate(activeTimerProvider),
      data: (t) => AnimatedSwitcher(
        duration: Motion.slow,
        child: t == null
            ? _PickSkill(key: const ValueKey('pick'), initialSkillId: initialSkillId)
            : _Running(key: ValueKey('run-${t.timer.startedAt}'), view: t),
      ),
    );
  }
}

class _PickSkill extends ConsumerStatefulWidget {
  const _PickSkill({super.key, this.initialSkillId});

  final int? initialSkillId;

  @override
  ConsumerState<_PickSkill> createState() => _PickSkillState();
}

class _PickSkillState extends ConsumerState<_PickSkill> {
  int? _selected;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSkillId;
  }

  Future<void> _start() async {
    final id = _selected;
    if (id == null) return;
    setState(() => _starting = true);
    await guarded(context, () => ref.read(appActionsProvider).startTimer(id));
    if (mounted) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final skills = ref.watch(skillsOverviewProvider);
    final gl = context.gl;
    return Scaffold(
      body: SafeArea(
        child: AsyncView(
          value: skills,
          data: (list) {
            if (list.isEmpty) {
              return Center(
                child: EmptyState(
                  image: AppAssets.emptySkills,
                  title: 'No skills yet',
                  message: 'Create a skill, then time your practice.',
                  actionLabel: 'Add a skill',
                  onAction: () => context.pushReplacement(Routes.newSkill),
                ),
              );
            }
            if (_selected == null || !list.any((s) => s.skill.id == _selected)) {
              _selected = list.first.skill.id;
            }
            final selected = list.firstWhere((s) => s.skill.id == _selected).skill;
            final color = Color(selected.colorValue);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
                  child: Row(
                    children: [
                      CircleIconButton(
                        icon: PhosphorIconsBold.x,
                        tooltip: 'Close',
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.md),
                  child: DisplayTitle(bold: 'What are you', italic: 'practising?', size: 36),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Space.xs),
                    itemBuilder: (_, i) {
                      final s = list[i].skill;
                      final sel = s.id == _selected;
                      return Semantics(
                        selected: sel,
                        child: Pressable(
                          onTap: () => setState(() => _selected = s.id),
                          semanticLabel: s.name,
                          child: AnimatedContainer(
                            duration: Motion.fast,
                            padding: const EdgeInsets.all(Space.sm),
                            decoration: BoxDecoration(
                              color: sel ? Color(s.colorValue) : gl.surface,
                              borderRadius: Radii.pillR,
                              border: Border.all(color: sel ? Color(s.colorValue) : gl.hairline),
                            ),
                            child: Row(
                              children: [
                                SkillAvatar(skill: s, inverted: sel),
                                const SizedBox(width: Space.sm),
                                Expanded(
                                  child: Text(
                                    s.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.subtitle.copyWith(color: sel ? Palette.ink : gl.text),
                                  ),
                                ),
                                Text(
                                  '${Fmt.hours(list[i].totalSec)} h',
                                  style: AppText.caption.copyWith(
                                    color: sel ? Palette.ink : gl.muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: Space.xs),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Space.xl),
                  child: Center(
                    child: _starting
                        ? const SizedBox(height: 112, child: LoadingState(height: 112))
                        : Semantics(
                            button: true,
                            label: 'Start ${selected.name} timer',
                            child: Pressable(
                              onTap: _start,
                              scale: 0.92,
                              child: Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                child: Container(
                                  margin: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(color: Palette.ink, shape: BoxShape.circle),
                                  child: Icon(PhosphorIconsFill.play, color: color, size: 38),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Running extends ConsumerStatefulWidget {
  const _Running({super.key, required this.view});

  final ActiveTimerView view;

  @override
  ConsumerState<_Running> createState() => _RunningState();
}

class _RunningState extends ConsumerState<_Running> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _stop() async {
    final elapsed = ref.read(timerRepositoryProvider).elapsed(widget.view.timer);
    await showAppSheet<void>(
      context,
      builder: (_) => StopTimerSheet(view: widget.view, elapsed: elapsed),
    );
  }

  Future<void> _discard() async {
    final ok = await confirm(
      context,
      title: 'Discard this session?',
      message: 'The timer will stop and nothing will be saved.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final router = GoRouter.of(context);
    await guarded(context, () => ref.read(appActionsProvider).discardTimer());
    if (router.canPop()) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(tickerProvider);
    final skill = widget.view.skill;
    final color = Color(skill.colorValue);
    final elapsed = ref.read(timerRepositoryProvider).elapsed(widget.view.timer);
    final readout = Fmt.clock(elapsed);
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: color,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Column(
            children: [
              Row(
                children: [
                  CircleIconButton(
                    icon: PhosphorIconsBold.caretDown,
                    tooltip: 'Minimise',
                    background: Palette.white,
                    foreground: Palette.ink,
                    onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(color: Palette.ink, borderRadius: Radii.pillR),
                    child: Row(
                      children: [
                        FadeTransition(
                          opacity: Tween(begin: 0.3, end: 1.0).animate(_pulse),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Recording', style: AppText.caption.copyWith(color: Palette.white, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: width * 0.72,
                height: width * 0.72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!MediaQuery.disableAnimationsOf(context))
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, _) => CustomPaint(
                          size: Size.square(width * 0.72),
                          painter: _PulsePainter(_pulse.value),
                        ),
                      ),
                    Container(
                      width: width * 0.5,
                      height: width * 0.5,
                      decoration: const BoxDecoration(color: Palette.ink, shape: BoxShape.circle),
                      child: Icon(SkillIcons.of(skill.iconKey), color: color, size: width * 0.16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.lg),
              Text(
                skill.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title.copyWith(color: Palette.ink),
              ),
              Semantics(
                label: 'Elapsed ${Fmt.duration(elapsed.inSeconds)}',
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      readout,
                      style: AppText.display.copyWith(
                        color: Palette.ink,
                        fontSize: 68,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                'Started ${Fmt.time(widget.view.timer.startedAt)}'
                '${elapsed.inHours >= 12 ? ' · still going?' : ''}',
                style: AppText.body.copyWith(color: Palette.ink.withValues(alpha: 0.7)),
              ),
              const Spacer(),
              PillButton(
                label: 'Stop & save',
                icon: PhosphorIconsFill.stop,
                expand: true,
                background: Palette.ink,
                foreground: color,
                onPressed: _stop,
              ),
              const SizedBox(height: Space.xs),
              TextButton(
                onPressed: _discard,
                child: Text('Discard', style: AppText.button.copyWith(color: Palette.ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.width / 2;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      final r = maxR * (0.7 + 0.3 * p);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Palette.ink.withValues(alpha: (1 - p) * 0.35);
      canvas.drawCircle(center, r, paint);
    }
    final dot = Paint()..color = Palette.ink;
    final a = t * 2 * math.pi - math.pi / 2;
    canvas.drawCircle(center + Offset(math.cos(a), math.sin(a)) * maxR * 0.78, 6, dot);
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t;
}

/// Confirms the duration (editable, e.g. if the timer was left running) and
/// saves the session.
class StopTimerSheet extends ConsumerStatefulWidget {
  const StopTimerSheet({super.key, required this.view, required this.elapsed});

  final ActiveTimerView view;
  final Duration elapsed;

  @override
  ConsumerState<StopTimerSheet> createState() => _StopTimerSheetState();
}

class _StopTimerSheetState extends ConsumerState<StopTimerSheet> {
  late int _minutes;
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _minutes = (widget.elapsed.inSeconds / 60).floor().clamp(0, 24 * 60);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final root = rootNavigatorKey.currentContext;
    final edited = _minutes != (widget.elapsed.inSeconds / 60).floor();
    final result = await guarded(context, () async {
      final r = await ref.read(appActionsProvider).stopTimer(
            durationSec: edited ? _minutes * 60 : null,
            note: _note.text,
          );
      return r ?? const <Achievement>[];
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == null) return;
    navigator.pop();
    if (router.canPop()) router.pop();
    if (root != null && root.mounted) {
      if (result.isEmpty) {
        showSnack(root, 'Saved ${Fmt.duration(_minutes * 60)} of ${widget.view.skill.name}');
      }
      await celebrate(root, result);
    }
  }

  Future<void> _discardShort() async {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    await ref.read(appActionsProvider).discardTimer();
    if (router.canPop()) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final forgot = widget.elapsed.inHours >= 12;
    if (_minutes < 1) {
      return SheetScaffold(
        title: 'Under a minute',
        primaryLabel: 'Keep going',
        onPrimary: () => Navigator.pop(context),
        secondary: TextButton(onPressed: _discardShort, child: const Text('Discard')),
        child: Text(
          'Sessions need at least one minute to count. Keep the timer running, or discard it.',
          style: context.text.bodyMedium?.copyWith(color: context.gl.muted),
        ),
      );
    }
    return SheetScaffold(
      title: 'Nice work!',
      primaryLabel: 'Save ${Fmt.duration(_minutes * 60)}',
      primaryLoading: _saving,
      onPrimary: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (forgot)
            Container(
              margin: const EdgeInsets.only(bottom: Space.sm),
              padding: const EdgeInsets.all(Space.md),
              decoration: const BoxDecoration(color: Palette.butter, borderRadius: Radii.cardSmallR),
              child: Text(
                'This timer ran for ${Fmt.duration(widget.elapsed.inSeconds)}. Forgot to stop it? Adjust the time below.',
                style: AppText.body.copyWith(color: Palette.ink),
              ),
            ),
          Row(
            children: [
              CircleIconButton(
                icon: PhosphorIconsBold.minus,
                tooltip: 'Less time',
                onPressed: _minutes > 1 ? () => setState(() => _minutes = math.max(1, _minutes - 5)) : null,
              ),
              Expanded(
                child: Text(
                  Fmt.duration(_minutes * 60),
                  textAlign: TextAlign.center,
                  style: AppText.display.copyWith(fontSize: 40, color: context.gl.text),
                ),
              ),
              CircleIconButton(
                icon: PhosphorIconsBold.plus,
                tooltip: 'More time',
                onPressed: _minutes < 24 * 60
                    ? () => setState(() => _minutes = math.min(24 * 60, _minutes + 5))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _note,
            maxLength: SkillLimits.noteMax,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What did you work on? (optional)',
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}

/// Slim banner shown on Home while a timer runs.
class TimerBanner extends ConsumerWidget {
  const TimerBanner({super.key, required this.view});

  final ActiveTimerView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(tickerProvider);
    final elapsed = ref.read(timerRepositoryProvider).elapsed(view.timer);
    final color = Color(view.skill.colorValue);
    return Pressable(
      onTap: () => context.push(Routes.timer()),
      semanticLabel: 'Timer running for ${view.skill.name}, ${Fmt.duration(elapsed.inSeconds)}. Open timer',
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.sm, Space.sm),
        decoration: const BoxDecoration(color: Palette.inkCard, borderRadius: Radii.pillR),
        child: ExcludeSemantics(
          child: Row(
            children: [
              SkillAvatar(skill: view.skill, size: 36),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.skill.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: Palette.white.withValues(alpha: 0.7)),
                    ),
                    Text(
                      Fmt.clock(elapsed),
                      style: AppText.subtitle.copyWith(
                        color: Palette.white,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: color, borderRadius: Radii.pillR),
                child: Text('Open', style: AppText.button.copyWith(color: Palette.ink, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
