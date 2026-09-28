import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import '../../domain/catalog/exercises.dart';
import '../../domain/engine/player.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/workout.dart';
import '../exercise/exercise_figure.dart';
import 'player_controller.dart';

String _clock(Duration d) {
  final s = d.inSeconds;
  final m = s ~/ 60;
  return '${m.toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});
  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  Timer? _ui;
  bool _loading = true;
  int _reps = 0;
  int? _repsForStep;
  bool _showCues = false;

  /// Set once we've navigated to /complete, so rebuilds during the exit
  /// transition don't push it again.
  bool _handedOff = false;

  void _handOff() {
    if (_handedOff || !mounted) return;
    _handedOff = true;
    _ui?.cancel();
    context.pushReplacement('/complete');
  }

  @override
  void initState() {
    super.initState();
    ref.read(playerProvider.notifier).load().then((_) {
      if (mounted) setState(() => _loading = false);
    });
    _ui = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ui?.cancel();
    super.dispose();
  }

  Future<void> _end(PlayerSnapshot s) async {
    final done = s.results.where((r) => !r.skipped && r.blockKind != BlockKind.warmup).isNotEmpty;
    final choice = await showBfSheet<String>(context, builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('End workout?', style: t.headlineMedium),
          const SizedBox(height: 4),
          Text(done ? 'Save what you\'ve done — every set counts.' : 'Nothing has been logged yet.',
              style: t.bodyMedium?.copyWith(color: ctx.bf.textMuted)),
          const SizedBox(height: Space.lg),
          if (done) ...[
            BfButton(label: 'Finish & save', onPressed: () => Navigator.pop(ctx, 'save')),
            const SizedBox(height: Space.sm),
          ],
          BfButton(label: 'Keep going', kind: BfButtonKind.ghost, onPressed: () => Navigator.pop(ctx, 'keep')),
          const SizedBox(height: Space.sm),
          BfButton(label: 'Discard workout', kind: BfButtonKind.danger, onPressed: () => Navigator.pop(ctx, 'discard')),
        ]),
      );
    });
    if (!mounted) return;
    final ctl = ref.read(playerProvider.notifier);
    if (choice == 'save') {
      await ctl.finishEarly();
      _handOff();
    } else if (choice == 'discard') {
      await ctl.discard();
      if (mounted) context.go('/home');
    }
  }

  Future<void> _swap(PlayerStep step) async {
    final filter = ref.read(filterProvider);
    final options = swapCandidates(step.exerciseId, filter.allowsId);
    final chosen = await showBfSheet<String>(context, builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Swap exercise', style: t.headlineMedium),
          const SizedBox(height: 4),
          Text('Same movement, fits your space. Progress carries over.', style: t.bodyMedium?.copyWith(color: ctx.bf.textMuted)),
          const SizedBox(height: Space.lg),
          if (options.isEmpty) Text('No suitable swaps here.', style: t.bodyMedium),
          for (final id in options)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: OptionCard(
                title: exerciseById(id).name,
                subtitle: 'Level ${exerciseById(id).difficulty} · ${exerciseById(id).summary}',
                selected: false,
                leading: SizedBox(width: 60, height: 40, child: ExerciseFigure(demo: exerciseById(id).demo, playing: false, color: ctx.bf.text)),
                onTap: () => Navigator.pop(ctx, id),
              ),
            ),
        ]),
      );
    });
    if (chosen != null) await ref.read(playerProvider.notifier).swap(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(playerProvider);
    final c = context.bf;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (s == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('No workout running.', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: Space.lg),
              BfButton(label: 'Back home', expand: false, onPressed: () => context.go('/home')),
            ]),
          ),
        ),
      );
    }
    if (s.isFinished) {
      if (!_handedOff) WidgetsBinding.instance.addPostFrameCallback((_) => _handOff());
      return const Scaffold(body: SizedBox.shrink());
    }

    final now = ref.read(clockProvider).now();
    final step = s.current!;
    final ex = exerciseById(step.isRest ? (step.nextExerciseId ?? step.exerciseId) : step.exerciseId);
    if (_repsForStep != s.stepIndex) {
      _repsForStep = s.stepIndex;
      _reps = step.target;
      _showCues = false;
    }
    final block = s.plan.blocks[step.blockIndex];
    final media = step.isRest ? c.secondary : (block.kind == BlockKind.main ? c.primary : c.tertiary);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _end(s);
      },
      child: Scaffold(
        backgroundColor: c.canvas,
        body: Column(children: [
          // ───── media area ─────
          Expanded(
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.slow),
              color: media,
              child: SafeArea(
                bottom: false,
                child: Stack(children: [
                  const Positioned.fill(child: ConcentricRings(color: Color(0x12000000), alignment: Alignment(0, 0.3))),
                  Positioned.fill(
                    top: 70,
                    bottom: 40,
                    child: AnimatedSwitcher(
                      duration: Motion.of(context, Motion.slow),
                      switchInCurve: Motion.emphasized,
                      transitionBuilder: (w, a) => SlideTransition(
                        position: Tween(begin: const Offset(0.25, 0), end: Offset.zero).animate(a),
                        child: FadeTransition(opacity: a, child: w),
                      ),
                      child: Padding(
                        key: ValueKey('${ex.id}-${step.isRest}'),
                        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                        child: Hero(
                          tag: 'ex-${ex.id}',
                          child: ExerciseFigure(demo: ex.demo, color: BfPalette.ink, playing: !s.isPaused && step.isWork),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(Space.gutter),
                    child: Row(children: [
                      CircleIconButton(icon: BfIcons.close, tooltip: 'End workout', onTap: () => _end(s)),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: Radii.pillAll,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: s.progress),
                            duration: Motion.of(context, Motion.slow),
                            builder: (_, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 6,
                              color: BfPalette.ink,
                              backgroundColor: BfPalette.ink.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      CircleIconButton(
                        icon: s.isPaused ? BfIcons.play : BfIcons.pause,
                        tooltip: s.isPaused ? 'Resume' : 'Pause',
                        onTap: () => s.isPaused
                            ? ref.read(playerProvider.notifier).resume()
                            : ref.read(playerProvider.notifier).pause(),
                      ),
                    ]),
                  ),
                  Positioned(
                    left: Space.gutter,
                    right: Space.gutter,
                    bottom: Space.sm,
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          step.isRest ? 'Rest' : ex.name,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: BfPalette.ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (step.isWork) _PillOnAccent(text: block.kind.label),
                    ]),
                  ),
                  if (s.isPaused)
                    Positioned.fill(
                      child: Container(
                        color: BfPalette.ink.withValues(alpha: 0.35),
                        alignment: Alignment.center,
                        child: Text('Paused', style: BfType.number(40, color: Colors.white)),
                      ).animate().fadeIn(duration: Motion.of(context, Motion.fast)),
                    ),
                ]),
              ),
            ),
          ),
          // ───── control sheet ─────
          Container(
            decoration: BoxDecoration(
              color: c.sheet,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
            ),
            transform: Matrix4.translationValues(0, -24, 0),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.sm),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: BfPalette.ink),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: BfPalette.ink.withValues(alpha: 0.15), borderRadius: Radii.pillAll)),
                    const SizedBox(height: Space.md),
                    _TopStats(s: s, step: step, now: now),
                    const SizedBox(height: Space.md),
                    AnimatedSwitcher(
                      duration: Motion.of(context, Motion.medium),
                      transitionBuilder: (w, a) => FadeTransition(opacity: a, child: SizeTransition(sizeFactor: a, child: w)),
                      child: KeyedSubtree(
                        key: ValueKey(s.stepIndex),
                        child: step.isRest
                            ? _RestPanel(s: s, step: step, now: now)
                            : step.isClocked
                                ? _TimedPanel(s: s, step: step, now: now)
                                : _RepPanel(
                                    step: step,
                                    reps: _reps,
                                    benchmark: s.plan.dayType == DayType.benchmark,
                                    elapsed: s.stepElapsed(now),
                                    onChange: (v) => setState(() => _reps = v),
                                    onDone: () {
                                      Haptics.medium();
                                      final isHold = exerciseById(step.exerciseId).isTimed;
                                      ref.read(playerProvider.notifier).completeWork(isHold ? s.stepElapsed(now).inSeconds : _reps);
                                    },
                                  ),
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    if (step.isWork)
                      Row(children: [
                        _SmallAction(icon: BfIcons.info, label: 'Form', onTap: () => setState(() => _showCues = !_showCues)),
                        _SmallAction(icon: BfIcons.swap, label: 'Swap', onTap: () => _swap(step)),
                        _SmallAction(icon: BfIcons.skip, label: 'Skip set', onTap: () => ref.read(playerProvider.notifier).skip()),
                        _SmallAction(
                            icon: Icons.fast_forward_rounded,
                            label: 'Skip exercise',
                            onTap: () => ref.read(playerProvider.notifier).skipExercise()),
                      ]),
                    MotionSize(
                      child: _showCues && step.isWork ? _Cues(exerciseId: step.exerciseId) : const SizedBox(width: double.infinity),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PillOnAccent extends StatelessWidget {
  const _PillOnAccent({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: BfPalette.ink.withValues(alpha: 0.1), borderRadius: Radii.pillAll),
        child: Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: BfPalette.ink)),
      );
}

class _TopStats extends StatelessWidget {
  const _TopStats({required this.s, required this.step, required this.now});
  final PlayerSnapshot s;
  final PlayerStep step;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = BfPalette.ink.withValues(alpha: 0.55);
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Elapsed', style: t.labelSmall?.copyWith(color: muted)),
        Text(_clock(s.elapsed(now)), style: BfType.number(18, color: BfPalette.ink)),
      ]),
      const Spacer(),
      if (step.isWork)
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(s.plan.blocks[step.blockIndex].circuit ? 'Round' : 'Set', style: t.labelSmall?.copyWith(color: muted)),
          Text('${step.setIndex + 1}/${step.totalSets}', style: BfType.number(18, color: BfPalette.ink)),
        ]),
    ]);
  }
}

class _RepPanel extends StatelessWidget {
  const _RepPanel({
    required this.step,
    required this.reps,
    required this.onChange,
    required this.onDone,
    required this.benchmark,
    required this.elapsed,
  });
  final PlayerStep step;
  final int reps;
  final ValueChanged<int> onChange;
  final VoidCallback onDone;
  final bool benchmark;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final ex = exerciseById(step.exerciseId);
    final t = Theme.of(context).textTheme;
    // Benchmark holds count up until the user stops.
    if (ex.isTimed) {
      return Column(children: [
        Text('Max hold — stop when your form breaks', style: t.bodyMedium?.copyWith(color: BfPalette.ink.withValues(alpha: 0.6))),
        const SizedBox(height: Space.sm),
        Text(_clock(elapsed), style: BfType.number(64, color: BfPalette.ink)),
        const SizedBox(height: Space.md),
        BfButton(label: 'Stop', kind: BfButtonKind.dark, onPressed: onDone),
      ]);
    }
    return Column(children: [
      Text(
        benchmark
            ? 'Max effort: as many good reps as possible (beat ${step.target - 1})'
            : 'Target ${step.target}${ex.perSide ? ' per side' : ''} — log what you actually did',
        textAlign: TextAlign.center,
        style: t.bodyMedium?.copyWith(color: BfPalette.ink.withValues(alpha: 0.6)),
      ),
      const SizedBox(height: Space.sm),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircleIconButton(
          icon: BfIcons.remove,
          size: 56,
          background: BfPalette.ink.withValues(alpha: 0.08),
          foreground: BfPalette.ink,
          onTap: reps > 0 ? () => onChange(reps - 1) : null,
          tooltip: 'One less',
        ),
        SizedBox(
          width: 150,
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.fast),
            transitionBuilder: (w, a) => ScaleTransition(
              scale: Tween(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: a, curve: Motion.spring)),
              child: FadeTransition(opacity: a, child: w),
            ),
            child: Text('$reps', key: ValueKey(reps), textAlign: TextAlign.center, style: BfType.number(76, color: BfPalette.ink)),
          ),
        ),
        CircleIconButton(icon: BfIcons.add, size: 56, onTap: () => onChange(reps + 1), tooltip: 'One more'),
      ]),
      const SizedBox(height: Space.md),
      BfButton(label: 'Done', icon: BfIcons.check, kind: BfButtonKind.dark, onPressed: onDone),
    ]);
  }
}

class _TimedPanel extends StatelessWidget {
  const _TimedPanel({required this.s, required this.step, required this.now});
  final PlayerSnapshot s;
  final PlayerStep step;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ex = exerciseById(step.exerciseId);
    final remaining = s.remaining(now) ?? Duration.zero;
    final total = step.durationSec + s.stepExtraSec;
    final frac = total == 0 ? 0.0 : 1 - remaining.inMilliseconds / (total * 1000);
    final halfway = ex.perSide && remaining.inSeconds <= total ~/ 2 && remaining.inSeconds > total ~/ 2 - 3;
    Widget ring = SizedBox(
      width: 176,
      height: 176,
      child: CustomPaint(
        painter: _Arc(frac.clamp(0, 1), BfPalette.ink, BfPalette.ink.withValues(alpha: 0.08)),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_clock(remaining), style: BfType.number(46, color: BfPalette.ink)),
            if (ex.perSide) Text(halfway ? 'Switch sides!' : (remaining.inSeconds > total ~/ 2 ? 'Side 1' : 'Side 2'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: BfPalette.ink)),
          ]),
        ),
      ),
    );
    if (!s.isPaused && !Motion.reduced(context)) {
      ring = ring
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(begin: const Offset(1, 1), end: const Offset(1.03, 1.03), duration: 900.ms, curve: Curves.easeInOut);
    }
    return Column(children: [
      ring,
      const SizedBox(height: Space.sm),
      Text('Hold strong. Breathe.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BfPalette.ink.withValues(alpha: 0.6))),
    ]);
  }
}

class _RestPanel extends ConsumerWidget {
  const _RestPanel({required this.s, required this.step, required this.now});
  final PlayerSnapshot s;
  final PlayerStep step;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = s.remaining(now) ?? Duration.zero;
    final total = step.durationSec + s.stepExtraSec;
    final frac = total == 0 ? 1.0 : remaining.inMilliseconds / (total * 1000);
    final next = s.nextWork;
    final t = Theme.of(context).textTheme;
    return Column(children: [
      SizedBox(
        width: 150,
        height: 150,
        child: CustomPaint(
          painter: _Arc(frac.clamp(0, 1), BfPalette.lavenderDeep, BfPalette.ink.withValues(alpha: 0.08)),
          child: Center(child: Text(_clock(remaining), style: BfType.number(40, color: BfPalette.ink))),
        ),
      ),
      const SizedBox(height: Space.md),
      if (next != null)
        Container(
          padding: const EdgeInsets.all(Space.sm),
          decoration: BoxDecoration(color: BfPalette.lime, borderRadius: Radii.tile),
          child: Row(children: [
            Container(
              width: 64,
              height: 44,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: Radii.small),
              child: ExerciseFigure(demo: exerciseById(next.exerciseId).demo, color: BfPalette.ink),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Next', style: t.labelSmall?.copyWith(color: BfPalette.ink.withValues(alpha: 0.6))),
                Text(exerciseById(next.exerciseId).name, style: t.titleSmall?.copyWith(color: BfPalette.ink)),
              ]),
            ),
            Text(next.timed ? '${next.target}s' : '× ${next.target}', style: BfType.number(18, color: BfPalette.ink)),
          ]),
        ),
      const SizedBox(height: Space.md),
      Row(children: [
        Expanded(
          child: BfButton(
            label: '+15 s',
            kind: BfButtonKind.ghost,
            icon: BfIcons.plus15,
            onPressed: () => ref.read(playerProvider.notifier).extendRest(15),
          ),
        ),
        const SizedBox(width: Space.sm),
        Expanded(child: BfButton(label: 'Skip rest', kind: BfButtonKind.dark, onPressed: () => ref.read(playerProvider.notifier).skip())),
      ]),
    ]);
  }
}

class _Arc extends CustomPainter {
  _Arc(this.v, this.color, this.track);
  final double v;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(8);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = track;
    canvas.drawArc(r, 0, 6.2832, false, bg);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(r, -1.5708, 6.2832 * v, false, fg);
  }

  @override
  bool shouldRepaint(_Arc o) => o.v != v || o.color != color;
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        borderRadius: Radii.tile,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: [
            Icon(icon, color: BfPalette.ink, size: 22),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: BfPalette.ink.withValues(alpha: 0.7))),
          ]),
        ),
      ),
    );
  }
}

class _Cues extends StatelessWidget {
  const _Cues({required this.exerciseId});
  final String exerciseId;
  @override
  Widget build(BuildContext context) {
    final ex = exerciseById(exerciseId);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < ex.cues.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: BfPalette.lime, shape: BoxShape.circle),
                child: Text('${i + 1}', style: t.labelSmall?.copyWith(color: BfPalette.ink)),
              ),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(ex.cues[i], style: t.bodyMedium?.copyWith(color: BfPalette.ink))),
            ]),
          ).animate(delay: Motion.stagger(i)).fadeIn(duration: Motion.of(context, Motion.medium)),
      ]),
    );
  }
}
