import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../data/services/training_service.dart';
import '../../domain/catalog/exercises.dart';
import '../../domain/engine/adaptive_engine.dart';
import '../../domain/engine/player.dart';
import '../../domain/engine/records.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/workout.dart';
import '../achievements/celebrations.dart';
import 'player_controller.dart';

class CompletionScreen extends ConsumerStatefulWidget {
  const CompletionScreen({super.key});
  @override
  ConsumerState<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends ConsumerState<CompletionScreen> {
  PlayerSnapshot? _snap;
  Rating? _rating;
  bool _saving = false;
  CompletionOutcome? _outcome;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var s = ref.read(playerProvider) ?? await ref.read(playerProvider.notifier).load();
    if (s != null && !s.isFinished) s = s.finishEarly(ref.read(clockProvider).now());
    if (mounted) setState(() => _snap = s);
  }

  Future<void> _save() async {
    final s = _snap;
    final r = _rating;
    if (s == null || r == null) return;
    setState(() => _saving = true);
    try {
      final outcome = await ref
          .read(trainingServiceProvider)
          .completeWorkout(s, r, recoveryCheckId: ref.read(playerProvider.notifier).recoveryId);
      ref.read(playerProvider.notifier).clear();
      ref.read(syncProvider.notifier).syncNow();
      setState(() => _outcome = outcome);
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      for (final pr in outcome.prs.take(3)) {
        await showPrCelebration(context, pr);
        if (!mounted) return;
      }
      for (final u in outcome.unlocks.take(2)) {
        await showUnlockCelebration(context, u);
        if (!mounted) return;
      }
      for (final a in outcome.achievements) {
        await showAchievementCelebration(context, a);
        if (!mounted) return;
      }
    } catch (e) {
      setState(() => _error = 'Couldn\'t save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _snap;
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    if (s == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final now = ref.read(clockProvider).now();
    final out = _outcome;
    final minutes = (out?.durationSec ?? s.elapsed(now).inSeconds) / 60;
    final sets = s.results.where((r) => !r.skipped && r.blockKind != BlockKind.warmup && r.blockKind != BlockKind.cooldown).length;

    return PopScope(
      canPop: out != null,
      child: Scaffold(
        body: Stack(children: [
          if (out != null) const Positioned.fill(child: ParticleBurst(count: 60)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.xxxl),
              children: [
                Center(
                  child: Glow(
                    color: c.primary,
                    radius: 90,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                      child: const Icon(BfIcons.check, size: 60, color: BfPalette.ink),
                    ),
                  ).pop(context),
                ),
                const SizedBox(height: Space.lg),
                Text(out == null ? 'Workout complete' : 'Saved. Forged.', textAlign: TextAlign.center, style: t.displaySmall)
                    .enter(context, index: 1),
                const SizedBox(height: 4),
                Text(s.plan.title, textAlign: TextAlign.center, style: t.titleMedium?.copyWith(color: c.textMuted))
                    .enter(context, index: 2),
                const SizedBox(height: Space.xl),
                Row(children: [
                  Expanded(child: StatTile(label: 'Minutes', value: CountUp(value: minutes, decimals: minutes < 10 ? 1 : 0))),
                  const SizedBox(width: Space.sm),
                  Expanded(child: StatTile(label: 'Sets', value: CountUp(value: sets.toDouble()))),
                  const SizedBox(width: Space.sm),
                  Expanded(child: StatTile(label: 'Reps', color: c.primary, value: CountUp(value: s.totalReps.toDouble()))),
                ]).enter(context, index: 3),
                const SizedBox(height: Space.xl),
                if (out == null) ...[
                  Text('How did today\'s workout feel?', style: t.headlineSmall).enter(context, index: 4),
                  const SizedBox(height: 4),
                  Text('Your answer and your actual reps decide your next session.', style: t.bodySmall).enter(context, index: 4),
                  const SizedBox(height: Space.md),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: Space.sm,
                    crossAxisSpacing: Space.sm,
                    childAspectRatio: 1.45,
                    children: [
                      for (var i = 0; i < Rating.values.length; i++)
                        _RatingCard(
                          rating: Rating.values[i],
                          selected: _rating == Rating.values[i],
                          onTap: _saving ? null : () => setState(() => _rating = Rating.values[i]),
                        ).enter(context, index: 5 + i),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  if (_error != null) Text(_error!, style: t.bodyMedium?.copyWith(color: c.danger)),
                  BfButton(label: 'Save workout', loading: _saving, onPressed: _rating == null ? null : _save),
                ] else
                  _Results(outcome: out),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.rating, required this.selected, required this.onTap});
  final Rating rating;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final (color, icon, line) = switch (rating) {
      Rating.tooEasy => (c.primary, BfIcons.bolt, 'Give me more'),
      Rating.good => (c.secondary, BfIcons.check, 'Just right'),
      Rating.hard => (c.ember, BfIcons.flame, 'Pushed me'),
      Rating.brutal => (BfPalette.coral, Icons.whatshot_rounded, 'Too much today'),
    };
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.card,
      scale: 0.94,
      semanticLabel: rating.label,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.medium),
        curve: Motion.gentleSpring,
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: selected ? color : c.surface,
          borderRadius: Radii.card,
          border: Border.all(color: selected ? Colors.transparent : color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedScale(
            scale: selected ? 1.25 : 1,
            duration: Motion.of(context, Motion.medium),
            curve: Motion.spring,
            alignment: Alignment.topLeft,
            child: Icon(icon, color: selected ? BfPalette.ink : color, size: 26),
          ),
          const Spacer(),
          Text(rating.label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: selected ? BfPalette.ink : c.text)),
          Text(line,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: selected ? BfPalette.ink.withValues(alpha: 0.7) : c.textMuted)),
        ]),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.outcome});
  final CompletionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final changes = outcome.progression.where((e) => e.type != ProgressionType.skipped).toList();
    var i = 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (outcome.prs.isNotEmpty) ...[
        Text('New records', style: t.headlineSmall).enter(context, index: i++),
        const SizedBox(height: Space.sm),
        for (final pr in outcome.prs)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: BfCard(
              color: c.ember,
              child: Row(children: [
                const Icon(BfIcons.trophy, color: BfPalette.ink),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(exerciseById(pr.exerciseId).name, style: t.titleSmall?.copyWith(color: BfPalette.ink))),
                Text('${formatRecord(pr.previous!, pr.metric)} → ${formatRecord(pr.current, pr.metric)}',
                    style: BfType.number(18, color: BfPalette.ink)),
              ]),
            ),
          ).enter(context, index: i++),
        const SizedBox(height: Space.lg),
      ],
      Text('Next time', style: t.headlineSmall).enter(context, index: i++),
      const SizedBox(height: Space.sm),
      if (changes.isEmpty) Text('Recovery sessions don\'t change your plan — they help it work.', style: t.bodyMedium),
      for (final e in changes)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.xs),
          child: BfCard(
            padding: const EdgeInsets.all(Space.md),
            child: Row(children: [
              Icon(
                switch (e.type) {
                  ProgressionType.unlocked => BfIcons.unlock,
                  ProgressionType.repsUp || ProgressionType.setAdded => BfIcons.up,
                  ProgressionType.reduced || ProgressionType.regressed => BfIcons.down,
                  _ => BfIcons.flat,
                },
                color: switch (e.type) {
                  ProgressionType.unlocked => c.primary,
                  ProgressionType.repsUp || ProgressionType.setAdded => c.success,
                  ProgressionType.reduced || ProgressionType.regressed => c.warning,
                  _ => c.textMuted,
                },
              ),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(e.message, style: t.bodyMedium)),
            ]),
          ),
        ).enter(context, index: i++),
      if (outcome.achievements.isNotEmpty) ...[
        const SizedBox(height: Space.lg),
        Text('Unlocked', style: t.headlineSmall),
        const SizedBox(height: Space.sm),
        Wrap(spacing: Space.md, runSpacing: Space.md, children: [
          for (final a in outcome.achievements)
            Column(children: [
              MedalBadge(def: a, unlocked: true, size: 72),
              const SizedBox(height: 4),
              Text(a.title, style: t.labelSmall),
            ]),
        ]),
      ],
      const SizedBox(height: Space.lg),
      if (outcome.journeyAfter.countedWeeks > outcome.journeyBefore.countedWeeks)
        BfCard(
          color: c.secondary,
          child: Text('Week ${outcome.journeyBefore.currentWeek} of your journey now counts ✓',
              style: t.titleSmall?.copyWith(color: BfPalette.ink)),
        ).pop(context),
      const SizedBox(height: Space.xl),
      BfButton(label: 'Done', onPressed: () => context.go('/home')),
    ]);
  }
}

