import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/phosphor_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/day_key.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/day_strip.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/states.dart';
import '../../log/application/log_providers.dart';
import '../../log/data/entry_repository.dart';
import '../../skills/application/skill_providers.dart';
import '../../skills/presentation/widgets/skill_cards.dart';
import '../../timer/application/timer_providers.dart';
import '../../timer/presentation/timer_screen.dart';
import '../application/dashboard_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DayKey? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final dashboard = ref.watch(dashboardProvider);
    final skills = ref.watch(skillsOverviewProvider);
    final timer = ref.watch(activeTimerProvider).value;
    final selected = _selectedDay ?? today;

    return Scaffold(
      body: RefreshIndicator(
        color: context.gl.text,
        onRefresh: () async {
          ref.read(todayProvider.notifier).refresh();
          ref.invalidate(dashboardProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(today: today)),
            if (timer != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
                  child: FadeSlideIn(child: TimerBanner(view: timer)),
                ),
              ),
            SliverToBoxAdapter(
              child: AsyncView(
                value: dashboard,
                onRetry: () => ref.invalidate(dashboardProvider),
                data: (d) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeSlideIn(child: _WeekHero(dashboard: d, skills: skills.value ?? const [])),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
                      child: DayStrip(
                        days: d.weekDays,
                        selected: selected,
                        today: today,
                        hasActivity: (day) =>
                            (d.weekDaily[day] ?? 0) > 0 || (d.entryCountByDay[day] ?? 0) > 0,
                        onSelect: (day) {
                          ref.read(hapticsProvider).tap();
                          setState(() => _selectedDay = day);
                        },
                      ),
                    ),
                    _DaySummary(day: selected, today: today, dashboard: d),
                    FadeSlideIn(index: 1, child: _Streaks(dashboard: d)),
                  ],
                ),
              ),
            ),
            SectionHeader(
              'Your skills',
              actionLabel: 'See all',
              onAction: () => context.go(Routes.skills),
            ).sliver,
            SliverToBoxAdapter(
              child: AsyncView(
                value: skills,
                loadingHeight: 160,
                onRetry: () => ref.invalidate(skillsOverviewProvider),
                data: (list) => list.isEmpty ? const _NoSkills() : _SkillGrid(skills: list),
              ),
            ),
            SectionHeader(
              "Today's log",
              actionLabel: 'Open log',
              onAction: () => context.go(Routes.log),
            ).sliver,
            SliverToBoxAdapter(child: _TodayLog(today: today)),
            const SliverToBoxAdapter(child: SizedBox(height: Space.dockClearance + Space.lg)),
          ],
        ),
      ),
    );
  }
}

extension on Widget {
  Widget get sliver => SliverToBoxAdapter(child: this);
}

class _Header extends StatelessWidget {
  const _Header({required this.today});

  final DayKey today;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 5
        ? 'Burning the midnight oil'
        : hour < 12
            ? 'Good morning'
            : hour < 18
                ? 'Good afternoon'
                : 'Good evening';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        MediaQuery.paddingOf(context).top + Space.md,
        Space.gutter,
        Space.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Palette.lime, shape: BoxShape.circle),
            child: const AppImage(AppAssets.splashLogo),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: context.text.titleMedium),
                Text(
                  'Today ${Fmt.shortDate(today)}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          CircleIconButton(
            icon: PhosphorIconsRegular.gear,
            tooltip: 'Settings',
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
    );
  }
}

class _WeekHero extends StatelessWidget {
  const _WeekHero({required this.dashboard, required this.skills});

  final Dashboard dashboard;
  final List<SkillStats> skills;

  @override
  Widget build(BuildContext context) {
    final d = dashboard;
    SkillStats? top;
    for (final s in skills) {
      if (s.weekSec > 0 && (top == null || s.weekSec > top.weekSec)) top = s;
    }
    final change = Fmt.percentChange(d.weekSec, d.lastWeekSec);
    final hours = d.weekSec ~/ 3600;
    final minutes = (d.weekSec % 3600) ~/ 60;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: GLCard(
        color: Palette.lime,
        radius: Radii.hero,
        padding: EdgeInsets.zero,
        clip: true,
        onTap: () => context.go(Routes.insights),
        semanticLabel: 'This week: ${Fmt.duration(d.weekSec)} practised, $change versus last week',
        child: SizedBox(
          height: 188,
          child: Stack(
            children: [
              const Positioned(
                right: -36,
                top: -18,
                bottom: -40,
                child: AppImage(AppAssets.heroShapes, width: 200),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This week',
                      style: AppText.caption.copyWith(color: Palette.ink, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '$hours', style: AppText.display.copyWith(color: Palette.ink, fontSize: 52)),
                        TextSpan(text: 'h ', style: AppText.displayItalic.copyWith(color: Palette.ink, fontSize: 30)),
                        TextSpan(text: '$minutes', style: AppText.display.copyWith(color: Palette.ink, fontSize: 52)),
                        TextSpan(text: 'm', style: AppText.displayItalic.copyWith(color: Palette.ink, fontSize: 30)),
                      ]),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        TagChip(
                          '$change vs last week',
                          color: Palette.ink,
                          foreground: Palette.lime,
                          icon: PhosphorIconsBold.trendUp,
                        ),
                        if (top != null)
                          TagChip('Top: ${top.skill.name}', color: Palette.white.withValues(alpha: 0.7)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.day, required this.today, required this.dashboard});

  final DayKey day;
  final DayKey today;
  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final sec = dashboard.weekDaily[day] ?? 0;
    final sessions = dashboard.sessionCountByDay[day] ?? 0;
    final entries = dashboard.entryCountByDay[day] ?? 0;
    final text = sessions == 0 && entries == 0
        ? (day == today ? 'Nothing logged yet today — small steps count.' : 'A rest day.')
        : [
            if (sessions > 0) '${Fmt.duration(sec)} across ${Fmt.plural(sessions, 'session')}',
            if (entries > 0) Fmt.plural(entries, 'entry', 'entries'),
          ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
      child: AnimatedSwitcher(
        duration: Motion.fast,
        child: Row(
          key: ValueKey('$day-$text'),
          children: [
            Text(
              '${Fmt.dayLabel(day, today)}  ',
              style: AppText.caption.copyWith(fontWeight: FontWeight.w800, color: context.gl.text),
            ),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Streaks extends StatelessWidget {
  const _Streaks({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final p = dashboard.practiceStreak;
    final l = dashboard.logStreak;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              label: 'Practice streak',
              value: Fmt.plural(p.current, 'day'),
              caption: p.current > 0 && !p.activeToday ? 'Practise today to keep it' : 'Best ${p.longest}',
              color: Palette.inkCard,
              foreground: Palette.white,
              leading: const AppImage(AppAssets.streakFlame, width: 28, height: 28),
              onTap: () => context.go(Routes.insights),
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: StatTile(
              label: 'Journal streak',
              value: Fmt.plural(l.current, 'day'),
              caption: l.current > 0 && !l.activeToday ? 'Log today to keep it' : 'Best ${l.longest}',
              color: Palette.blush,
              foreground: Palette.ink,
              leading: const AppImage(AppAssets.trophy, width: 28, height: 28),
              onTap: () => context.go(Routes.log),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSkills extends StatelessWidget {
  const _NoSkills();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: GLCard(
        color: Palette.lavender,
        onTap: () => context.push(Routes.newSkill),
        child: Row(
          children: [
            const AppImage(AppAssets.emptySkills, width: 96, height: 72),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add your first skill', style: AppText.subtitle.copyWith(color: Palette.ink)),
                  Text(
                    'Track hours toward mastery.',
                    style: AppText.caption.copyWith(color: Palette.ink.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            const Icon(PhosphorIconsBold.arrowRight, color: Palette.ink),
          ],
        ),
      ),
    );
  }
}

/// Asymmetric two-column grid: the first tile is tall, like "Your plan".
class _SkillGrid extends StatelessWidget {
  const _SkillGrid({required this.skills});

  final List<SkillStats> skills;

  @override
  Widget build(BuildContext context) {
    final shown = skills.take(4).toList();
    if (shown.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        child: SkillTile(stats: shown.first),
      );
    }
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < shown.length; i++) {
      final tile = FadeSlideIn(
        index: i + 2,
        child: SkillTile(stats: shown[i], tall: i == 0),
      );
      (i.isEven ? left : right).add(tile);
    }
    Widget col(List<Widget> items) => Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: Space.sm),
              items[i],
            ],
          ],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: col(left)),
          const SizedBox(width: Space.sm),
          Expanded(child: col(right)),
        ],
      ),
    );
  }
}

class _TodayLog extends ConsumerWidget {
  const _TodayLog({required this.today});

  final DayKey today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(todayEntriesProvider);
    return AsyncView(
      value: entries,
      loadingHeight: 120,
      data: (list) {
        if (list.isEmpty) return _Prompt(today: today);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: _StackedEntries(entries: list.take(3).toList(), total: list.length),
        );
      },
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.today});

  final DayKey today;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: GLCard(
        color: Palette.butter,
        radius: Radii.hero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    promptForDay(today),
                    style: AppText.title.copyWith(color: Palette.ink),
                  ),
                ),
                const AppImage(AppAssets.emptyLog, width: 84, height: 64),
              ],
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'Gratitude',
                    icon: PhosphorIconsFill.heart,
                    height: 48,
                    expand: true,
                    background: Palette.ink,
                    foreground: Palette.butter,
                    onPressed: () => context.push(Routes.newEntry()),
                  ),
                ),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: PillButton(
                    label: 'A win',
                    icon: PhosphorIconsFill.trophy,
                    height: 48,
                    expand: true,
                    background: Palette.white.withValues(alpha: 0.7),
                    foreground: Palette.ink,
                    onPressed: () => context.push(Routes.newEntry(type: EntryType.win)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fanned stack of today's entries ("Events with Friends" reference).
class _StackedEntries extends StatelessWidget {
  const _StackedEntries({required this.entries, required this.total});

  final List<EntryView> entries;
  final int total;

  @override
  Widget build(BuildContext context) {
    const peek = 14.0;
    final n = entries.length;
    return Pressable(
      onTap: () => context.go(Routes.log),
      semanticLabel: '${Fmt.plural(total, 'entry', 'entries')} today. Open log',
      child: Padding(
        padding: EdgeInsets.only(top: peek * (n - 1)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = n - 1; i >= 1; i--)
              Positioned(
                left: 12.0 * i,
                right: 12.0 * i,
                top: -peek * i,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: _colorFor(entries[i]).withValues(alpha: 0.9),
                    borderRadius: Radii.cardR,
                  ),
                ),
              ),
            ExcludeSemantics(child: _EntryFace(view: entries.first, total: total)),
          ],
        ),
      ),
    );
  }
}

Color _colorFor(EntryView v) => v.type == EntryType.win ? Palette.blush : Palette.butter;

class _EntryFace extends StatelessWidget {
  const _EntryFace({required this.view, required this.total});

  final EntryView view;
  final int total;

  @override
  Widget build(BuildContext context) {
    final e = view.entry;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: _colorFor(view), borderRadius: Radii.cardR),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TagChip(
                view.type.label,
                icon: view.type == EntryType.win ? PhosphorIconsFill.trophy : PhosphorIconsFill.heart,
              ),
              const Spacer(),
              if (e.mood != null) Text(e.mood!, style: const TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            e.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppText.subtitle.copyWith(color: Palette.ink, fontWeight: FontWeight.w600),
          ),
          if (total > 1) ...[
            const SizedBox(height: Space.sm),
            Text(
              '+${total - 1} more today',
              style: AppText.caption.copyWith(color: Palette.ink.withValues(alpha: 0.7), fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}
