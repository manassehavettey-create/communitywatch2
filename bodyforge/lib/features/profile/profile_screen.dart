import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/auth.dart';
import '../../app/config.dart';
import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/assets.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../domain/catalog/achievements.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/exercise.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider).value;
    final auth = ref.watch(authProvider);
    final units = ref.watch(settingsProvider).units;
    final workouts = ref.watch(workoutsProvider).value ?? const [];
    final unlocked = ref.watch(unlockedAchievementsProvider).value ?? const {};
    final history = ref.watch(recordHistoryProvider).value ?? const [];
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final initials = p.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    var i = 0;
    Widget e(Widget w) => w.enter(context, index: i++);

    Widget row(IconData icon, String title, String value, String route) => Padding(
          padding: const EdgeInsets.only(bottom: Space.xs),
          child: BfCard(
            padding: const EdgeInsets.all(Space.md),
            onTap: () => context.push(route),
            child: Row(children: [
              Icon(icon, color: c.primary),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: t.titleSmall),
                  Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                ]),
              ),
              const Icon(BfIcons.chevronRight),
            ]),
          ),
        );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 120),
          children: [
            e(Row(children: [
              Text('Profile', style: t.displaySmall),
              const Spacer(),
              CircleIconButton(icon: BfIcons.settings, tooltip: 'Settings', onTap: () => context.push('/settings')),
            ])),
            const SizedBox(height: Space.md),
            e(BfCard(
              color: c.secondary,
              rings: true,
              child: Row(children: [
                Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: BfPalette.ink, shape: BoxShape.circle),
                  child: Text(initials, style: BfType.number(24, color: BfPalette.lavender, weight: FontWeight.w700)),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, style: t.headlineSmall?.copyWith(color: BfPalette.ink)),
                    Text('${p.level.label} · since ${DateFormat('MMM yyyy').format(p.journeyStart.toLocalDateTime())}',
                        style: t.bodySmall?.copyWith(color: BfPalette.ink.withValues(alpha: 0.7))),
                    const SizedBox(height: 4),
                    Text(
                      auth.isCloud ? 'Backed up · ${auth.email ?? ''}' : 'Saved on this phone',
                      style: t.labelSmall?.copyWith(color: BfPalette.ink.withValues(alpha: 0.7)),
                    ),
                  ]),
                ),
              ]),
            )),
            const SizedBox(height: Space.sm),
            e(Row(children: [
              Expanded(child: StatTile(label: 'Workouts', value: CountUp(value: workouts.length.toDouble()))),
              const SizedBox(width: Space.sm),
              Expanded(child: StatTile(label: 'PRs', value: CountUp(value: history.where((h) => h.previous != null).length.toDouble()))),
              const SizedBox(width: Space.sm),
              Expanded(child: StatTile(label: 'Badges', value: Text('${unlocked.length}/${kAchievements.length}'))),
            ])),
            if (!auth.isCloud && AppConfig.cloudEnabled) ...[
              const SizedBox(height: Space.sm),
              e(BfCard(
                color: c.primary,
                onTap: () => context.push('/auth?mode=signup'),
                child: Row(children: [
                  const Icon(BfIcons.cloud, color: BfPalette.ink),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text('Create a free account to back up and sync your progress',
                        style: t.titleSmall?.copyWith(color: BfPalette.ink)),
                  ),
                  const Icon(BfIcons.chevronRight, color: BfPalette.ink),
                ]),
              )),
            ],
            const SizedBox(height: Space.lg),
            e(row(BfIcons.flag, 'Goals', p.goals.map((g) => g.label).join(', '), '/edit/goals')),
            e(row(BfIcons.bolt, 'Fitness information',
                '${p.level.label} · ${p.experience.label} · ${Units.height(p.heightCm, units)} · ${Units.formatMeasurement(MeasurementType.weight, p.weightKg, units)}',
                '/edit/fitness')),
            e(row(BfIcons.calendar, 'Preferences',
                '${p.daysPerWeek} days/week · ${p.sessionMinutes} min · ${p.environment.label} · ${p.style.label}', '/edit/preferences')),
            e(row(BfIcons.heart, 'Body & limitations', _limits(p.limitations), '/edit/body')),
            const SizedBox(height: Space.md),
            e(BfCard(
              onTap: () => context.push('/achievements'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Achievements', style: t.titleMedium),
                  const Spacer(),
                  const Icon(BfIcons.chevronRight),
                ]),
                const SizedBox(height: Space.sm),
                if (unlocked.isEmpty)
                  Row(children: [
                    const SizedBox(width: 48, height: 48, child: AppImage(Img.emptyAchievements)),
                    const SizedBox(width: Space.sm),
                    Expanded(child: Text('Your first badge is one workout away.', style: t.bodySmall)),
                  ])
                else
                  Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                    for (final id in unlocked.keys.take(8))
                      if (kAchievementById[id] != null) MedalBadge(def: kAchievementById[id]!, unlocked: true, size: 50),
                  ]),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  String _limits(Limitations l) {
    final parts = <String>[
      if (l.noJumping) 'No jumping',
      if (l.avoidFloor) 'Limited floor work',
      if (l.kneeSensitive) 'Sensitive knees',
      if (l.wristSensitive) 'Sensitive wrists',
    ];
    return parts.isEmpty ? 'No limitations' : parts.join(' · ');
  }
}
