import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/application/app_actions.dart';
import '../../../../core/router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/progress_ring.dart';
import '../../../../core/widgets/skill_icons.dart';
import '../../../timer/application/timer_providers.dart';
import '../../application/skill_providers.dart';

/// Starts a timer for [skillId] (or opens the running one) and shows the
/// full-screen timer.
Future<void> startOrOpenTimer(BuildContext context, WidgetRef ref, int skillId) async {
  final running = ref.read(activeTimerProvider).value;
  final router = GoRouter.of(context);
  if (running == null) {
    final ok = await guarded(context, () async {
      await ref.read(appActionsProvider).startTimer(skillId);
      return true;
    });
    if (ok != true) return;
  } else if (running.skill.id != skillId) {
    if (context.mounted) {
      showSnack(context, 'Stop the ${running.skill.name} timer first.');
    }
  }
  await router.push(Routes.timer());
}

/// Compact grid tile for Home ("Your plan" cards in the reference).
class SkillTile extends ConsumerWidget {
  const SkillTile({super.key, required this.stats, this.tall = false});

  final SkillStats stats;
  final bool tall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stats.skill;
    final color = Color(s.colorValue);
    final level = stats.level;
    return GLCard(
      color: color,
      padding: const EdgeInsets.all(Space.md),
      onTap: () => context.push(Routes.skill(s.id)),
      semanticLabel:
          '${s.name}, ${level.current.name}, ${Fmt.hours(stats.totalSec)} hours total',
      child: SizedBox(
        height: tall ? 200 : 150,
        child: Stack(
          children: [
            Positioned(
              right: -6,
              bottom: 18,
              child: Opacity(
                opacity: 0.95,
                child: AppImage(level.current.badgeAsset, width: tall ? 84 : 64),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: TagChip(level.current.name, dense: true)),
                    const Spacer(),
                    CircleIconButton(
                      icon: PhosphorIconsFill.play,
                      tooltip: 'Start ${s.name} timer',
                      size: 34,
                      background: Palette.ink,
                      foreground: color,
                      onPressed: () => startOrOpenTimer(context, ref, s.id),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                Text(
                  s.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title.copyWith(color: Palette.ink, fontSize: 19),
                ),
                const Spacer(),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: Fmt.hours(stats.totalSec),
                      style: AppText.numeral.copyWith(color: Palette.ink, fontSize: 24),
                    ),
                    TextSpan(
                      text: ' h',
                      style: AppText.body.copyWith(color: Palette.ink, fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
                Text(
                  stats.weekSec > 0
                      ? '${Fmt.duration(stats.weekSec)} this week'
                      : 'Not yet this week',
                  style: AppText.caption.copyWith(color: Palette.ink.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: Space.xs),
                ProgressBar(value: level.fraction, height: 6, color: Palette.ink),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Wide card for the Skills tab: ring with badge, level, hours and target.
class SkillListCard extends ConsumerWidget {
  const SkillListCard({super.key, required this.stats, this.archived = false, this.dragHandle});

  final SkillStats stats;
  final bool archived;
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stats.skill;
    final color = archived ? context.gl.card : Color(s.colorValue);
    final fg = archived ? context.gl.text : Palette.ink;
    final level = stats.level;
    return GLCard(
      color: color,
      border: archived,
      padding: const EdgeInsets.all(Space.md),
      onTap: () => context.push(Routes.skill(s.id)),
      semanticLabel: '${s.name}, ${level.current.name}, '
          '${Fmt.hours(stats.totalSec)} of ${Fmt.number(s.targetHours.round())} hours',
      child: Row(
        children: [
          ProgressRing(
            value: level.fraction,
            size: 78,
            stroke: 7,
            color: fg,
            child: AppImage(level.current.badgeAsset, width: 44, height: 44),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(SkillIcons.of(s.iconKey), size: 16, color: fg),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title.copyWith(color: fg, fontSize: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  level.isMax
                      ? '${level.current.name} · the summit'
                      : '${level.current.name} · ${Fmt.hours(level.secondsToNext)} h to ${level.next!.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: fg.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: Space.xs),
                ProgressBar(value: stats.targetFraction, height: 6, color: fg),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${Fmt.hours(stats.totalSec)} / ${Fmt.number(s.targetHours.round())} h',
                      style: AppText.caption.copyWith(color: fg, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (stats.streak.current > 0)
                      TagChip(
                        '${stats.streak.current}d',
                        icon: PhosphorIconsFill.fire,
                        dense: true,
                        color: archived ? Palette.limeSoft : null,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (dragHandle != null) ...[const SizedBox(width: Space.xs), dragHandle!],
        ],
      ),
    );
  }
}
