import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/assets.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/page.dart';
import '../../domain/catalog/achievements.dart';
import '../../domain/engine/achievement_evaluator.dart';

final _statsProvider = FutureProvider.autoDispose<AchievementStats>((ref) {
  // Recompute when workouts / records / measurements change.
  ref.watch(workoutsProvider);
  ref.watch(recordHistoryProvider);
  ref.watch(measurementsProvider);
  ref.watch(challengesProvider);
  return ref.watch(trainingServiceProvider).achievementStats();
});

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(unlockedAchievementsProvider).value ?? const {};
    final stats = ref.watch(_statsProvider).value;
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final fmt = DateFormat('d MMM yyyy');
    final sorted = [...kAchievements]..sort((a, b) {
        final ua = unlocked.containsKey(a.id) ? 0 : 1;
        final ub = unlocked.containsKey(b.id) ? 0 : 1;
        return ua - ub;
      });
    return BfPage(
      title: 'Achievements',
      children: [
        Text('${unlocked.length} of ${kAchievements.length} unlocked', style: t.headlineSmall),
        const SizedBox(height: 4),
        Text('Every badge is earned by real actions — nothing to buy, nothing to fake.', style: t.bodyMedium?.copyWith(color: c.textMuted)),
        const SizedBox(height: Space.lg),
        if (unlocked.isEmpty)
          const EmptyState(image: Img.emptyAchievements, title: 'Your first badge is one workout away', message: 'Finish any workout to unlock FIRST REP.', imageHeight: 110),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: Space.md, crossAxisSpacing: Space.sm, childAspectRatio: 0.72),
          itemCount: sorted.length,
          itemBuilder: (context, i) {
            final a = sorted[i];
            final at = unlocked[a.id];
            final progress = stats == null ? 0 : achievementProgress(a.id, stats);
            return Pressable(
              onTap: () => showBfSheet(context, builder: (ctx) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
                  child: Column(children: [
                    MedalBadge(def: a, unlocked: at != null, size: 140, glow: at != null),
                    const SizedBox(height: Space.md),
                    Text(a.title, style: Theme.of(ctx).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(a.description, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodyMedium),
                    const SizedBox(height: Space.md),
                    if (at != null)
                      Text('Unlocked ${fmt.format(at.toLocal())}', style: Theme.of(ctx).textTheme.labelMedium?.copyWith(color: ctx.bf.accentText))
                    else if (a.target > 1)
                      Text('${progress.clamp(0, a.target)} / ${a.target}', style: Theme.of(ctx).textTheme.labelMedium),
                  ]),
                );
              }),
              borderRadius: Radii.tile,
              child: Column(children: [
                MedalBadge(def: a, unlocked: at != null, size: 80),
                const SizedBox(height: 6),
                Text(a.title, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: t.labelSmall?.copyWith(color: at != null ? c.text : c.textFaint)),
                if (at == null && a.target > 1) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: Radii.pillAll,
                    child: LinearProgressIndicator(value: (progress / a.target).clamp(0.0, 1.0), minHeight: 4),
                  ),
                ],
              ]),
            ).enter(context, index: i);
          },
        ),
      ],
    );
  }
}
