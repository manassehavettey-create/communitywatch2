import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../domain/catalog/achievements.dart';
import '../../domain/catalog/exercises.dart';
import '../../domain/engine/adaptive_engine.dart';
import '../../domain/engine/records.dart';
import '../exercise/exercise_figure.dart';

Future<void> _celebrate(BuildContext context, Widget Function(BuildContext) builder) {
  Haptics.heavy();
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.75),
    transitionDuration: Motion.of(context, Motion.slow),
    pageBuilder: (ctx, _, _) => builder(ctx),
    transitionBuilder: (ctx, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: a, curve: Motion.emphasized)), child: child),
    ),
  );
}

class _CelebrationFrame extends StatelessWidget {
  const _CelebrationFrame({required this.overline, required this.title, required this.hero, required this.body, required this.color});
  final String overline;
  final String title;
  final Widget hero;
  final Widget body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        Positioned.fill(child: ParticleBurst(colors: [color, BfPalette.paper, BfPalette.lavender, BfPalette.lime])),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              hero,
              const SizedBox(height: Space.xl),
              Text(overline.toUpperCase(), style: BfType.overline(color)).animate(delay: 350.ms).fadeIn(),
              const SizedBox(height: Space.xs),
              Text(title, textAlign: TextAlign.center, style: t.headlineLarge?.copyWith(color: Colors.white))
                  .animate(delay: 450.ms)
                  .fadeIn()
                  .moveY(begin: 10, end: 0),
              const SizedBox(height: Space.md),
              body.animate(delay: 600.ms).fadeIn(),
              const SizedBox(height: Space.xl),
              BfButton(label: 'Continue', expand: false, onPressed: () => Navigator.pop(context)).animate(delay: 900.ms).fadeIn(),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// PR celebration: previous vs current with an animated counter.
Future<void> showPrCelebration(BuildContext context, PrEvent pr) => _celebrate(
      context,
      (ctx) {
        final ex = exerciseById(pr.exerciseId);
        return _CelebrationFrame(
          overline: 'Personal record',
          title: ex.name,
          color: BfPalette.ember,
          hero: Glow(
            color: BfPalette.ember,
            radius: 110,
            child: Container(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(color: BfPalette.ember, shape: BoxShape.circle),
              child: const Icon(BfIcons.trophy, size: 72, color: BfPalette.ink),
            ),
          ).pop(ctx),
          body: Row(mainAxisSize: MainAxisSize.min, children: [
            Column(children: [
              Text('Previous', style: Theme.of(ctx).textTheme.labelSmall?.copyWith(color: Colors.white70)),
              Text(formatRecord(pr.previous ?? 0, pr.metric), style: BfType.number(34, color: Colors.white70)),
            ]),
            const Padding(padding: EdgeInsets.symmetric(horizontal: Space.lg), child: Icon(BfIcons.forward, color: Colors.white)),
            Column(children: [
              Text('Now', style: Theme.of(ctx).textTheme.labelSmall?.copyWith(color: BfPalette.ember)),
              pr.metric == RecordMetric.maxHold
                  ? Text(formatRecord(pr.current, pr.metric), style: BfType.number(48, color: BfPalette.lime))
                  : CountUp(value: pr.current.toDouble(), style: BfType.number(48, color: BfPalette.lime)),
            ]),
          ]),
        );
      },
    );

/// Skill-tree unlock: the new variation animating in.
Future<void> showUnlockCelebration(BuildContext context, ProgressionEvent e) => _celebrate(
      context,
      (ctx) {
        final ex = exerciseById(e.toExerciseId);
        return _CelebrationFrame(
          overline: 'Level up — skill unlocked',
          title: ex.name,
          color: BfPalette.lime,
          hero: Container(
            width: 260,
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(color: BfPalette.lime, borderRadius: Radii.cardLarge),
            child: ExerciseFigure(demo: ex.demo, color: BfPalette.ink),
          ).pop(ctx),
          body: Text(ex.summary, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
        );
      },
    );

/// Achievement unlock: badge reveal with glow.
Future<void> showAchievementCelebration(BuildContext context, AchievementDef a) => _celebrate(
      context,
      (ctx) {
        final color = switch (a.tier) {
          MedalTier.lavender => BfPalette.lavender,
          MedalTier.lime => BfPalette.lime,
          MedalTier.ember => BfPalette.ember,
        };
        return _CelebrationFrame(
          overline: 'Achievement unlocked',
          title: a.title,
          color: color,
          hero: MedalBadge(def: a, unlocked: true, size: 170, glow: true)
              .animate()
              .scale(begin: const Offset(0.3, 0.3), end: const Offset(1, 1), curve: Motion.gentleSpring, duration: Motion.of(ctx, Motion.slower))
              .rotate(begin: -0.08, end: 0, duration: Motion.of(ctx, Motion.slower), curve: Motion.gentleSpring),
          body: Text(a.description, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(color: Colors.white70)),
        );
      },
    );
