import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/app_actions.dart';
import '../../../core/db/database.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/phosphor_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/day_key.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/hours_chart.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/segmented_pills.dart';
import '../../../core/widgets/skill_icons.dart';
import '../../../core/widgets/states.dart';
import '../../log/data/entry_repository.dart';
import '../application/skill_providers.dart';
import '../domain/levels.dart';
import 'session_sheet.dart';
import 'widgets/skill_cards.dart';

class SkillDetailScreen extends ConsumerWidget {
  const SkillDetailScreen({super.key, required this.skillId});

  final int skillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(skillDetailProvider(skillId));
    return Scaffold(
      body: AsyncView(
        value: detail,
        onRetry: () => ref.invalidate(skillDetailProvider(skillId)),
        data: (d) {
          if (d == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyState(
                    image: AppAssets.emptySearch,
                    title: 'Skill not found',
                    message: 'It may have been deleted.',
                    compact: true,
                  ),
                  TextButton(
                    onPressed: () => context.go(Routes.skills),
                    child: const Text('Back to skills'),
                  ),
                ],
              ),
            );
          }
          return _Body(detail: d);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});

  final SkillDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = detail.skill;
    final color = Color(s.colorValue);
    final stats = detail.stats;
    final level = stats.level;
    final archived = s.archivedAt != null;
    final today = ref.watch(todayProvider);
    final top = MediaQuery.paddingOf(context).top;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(Radii.hero + 8),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              top + Space.sm,
              Space.gutter,
              Space.xl,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleIconButton(
                      icon: PhosphorIconsBold.arrowLeft,
                      tooltip: 'Back',
                      background: Palette.white,
                      foreground: Palette.ink,
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(Routes.skills),
                    ),
                    Expanded(
                      child: Text(
                        s.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.subtitle.copyWith(color: Palette.ink),
                      ),
                    ),
                    _Menu(detail: detail),
                  ],
                ),
                const SizedBox(height: Space.lg),
                ProgressRing(
                  value: level.fraction,
                  size: 200,
                  stroke: 14,
                  color: Palette.ink,
                  trackColor: Palette.white.withValues(alpha: 0.45),
                  semanticLabel: 'Progress to next level',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppImage(level.current.badgeAsset, width: 88, height: 88),
                      Text(
                        level.current.name.toUpperCase(),
                        style: AppText.caption.copyWith(
                          color: Palette.ink,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: Fmt.hours(stats.totalSec),
                        style: AppText.display.copyWith(
                          color: Palette.ink,
                          fontSize: 56,
                        ),
                      ),
                      TextSpan(
                        text: ' hours',
                        style: AppText.displayItalic.copyWith(
                          color: Palette.ink,
                          fontSize: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.xxs),
                Text(
                  level.isMax
                      ? 'Master level reached. Legendary.'
                      : '${Fmt.hours(level.secondsToNext)} h to ${level.next!.name}',
                  style: AppText.body.copyWith(
                    color: Palette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (s.description != null) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    s.description!,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(
                      color: Palette.ink.withValues(alpha: 0.75),
                    ),
                  ),
                ],
                const SizedBox(height: Space.lg),
                Row(
                  children: [
                    Expanded(
                      child: PillButton(
                        label: archived ? 'Archived' : 'Start timer',
                        icon: PhosphorIconsFill.play,
                        expand: true,
                        background: Palette.ink,
                        foreground: color,
                        onPressed: archived
                            ? null
                            : () => startOrOpenTimer(context, ref, s.id),
                      ),
                    ),
                    const SizedBox(width: Space.xs),
                    Expanded(
                      child: PillButton(
                        label: 'Log time',
                        icon: PhosphorIconsBold.plus,
                        expand: true,
                        background: Palette.white.withValues(alpha: 0.6),
                        foreground: Palette.ink,
                        onPressed: () =>
                            showSessionSheet(context, skillId: s.id),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.lg,
            Space.gutter,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Streak',
                    value: '${stats.streak.current}d',
                    caption: 'Best ${stats.streak.longest}d',
                    leading: const AppImage(
                      AppAssets.streakFlame,
                      width: 22,
                      height: 22,
                    ),
                  ),
                ),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: StatTile(
                    label: 'This week',
                    value: Fmt.duration(stats.weekSec),
                    caption: stats.weekSec > 0 ? 'keep it up' : 'not yet',
                  ),
                ),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: StatTile(
                    label: 'Sessions',
                    value: Fmt.number(detail.sessions.length),
                    caption: '${Fmt.duration(detail.avgSessionSec)} avg',
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _Charts(detail: detail, today: today),
        ),
        SliverToBoxAdapter(child: _Milestones(detail: detail)),
        SliverToBoxAdapter(child: _Target(stats: stats)),
        const SliverToBoxAdapter(child: SectionHeader('Sessions')),
        if (detail.sessions.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: GLCard(
                border: true,
                child: Text(
                  'No sessions yet. Start the timer or log time you already put in.',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.gl.muted,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            sliver: SliverList.separated(
              itemCount: detail.sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.xs),
              itemBuilder: (_, i) =>
                  _SessionRow(session: detail.sessions[i], today: today),
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.paddingOf(context).bottom + Space.xxl,
          ),
        ),
      ],
    );
  }
}

class _Menu extends ConsumerWidget {
  const _Menu({required this.detail});

  final SkillDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = detail.skill;
    final archived = s.archivedAt != null;
    return PopupMenuButton<String>(
      tooltip: 'More',
      position: PopupMenuPosition.under,
      shape: const RoundedRectangleBorder(borderRadius: Radii.cardSmallR),
      onSelected: (v) => _onSelected(context, ref, v),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit skill')),
        PopupMenuItem(value: 'win', child: Text('Log a win for ${s.name}')),
        PopupMenuItem(
          value: 'archive',
          child: Text(archived ? 'Unarchive' : 'Archive'),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Palette.danger)),
        ),
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Palette.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          PhosphorIconsBold.dotsThree,
          color: Palette.ink,
          size: 20,
        ),
      ),
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    String v,
  ) async {
    final s = detail.skill;
    final actions = ref.read(appActionsProvider);
    switch (v) {
      case 'edit':
        unawaited(context.push(Routes.editSkill(s.id)));
      case 'win':
        unawaited(
          context.push(Routes.newEntry(type: EntryType.win, skillId: s.id)),
        );
      case 'archive':
        final archiving = s.archivedAt == null;
        await guarded(
          context,
          () => actions.setArchived(s.id, archived: archiving),
        );
        if (context.mounted) {
          showSnack(
            context,
            archiving ? '${s.name} archived' : '${s.name} is back',
          );
        }
      case 'delete':
        await _delete(context, ref);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final s = detail.skill;
    final count = detail.sessions.length;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${s.name}?'),
        content: Text(
          count == 0
              ? 'This skill has no sessions yet.'
              : 'This permanently deletes ${Fmt.plural(count, 'session')} '
                    '(${Fmt.hours(detail.stats.totalSec)} h) and its milestones. '
                    'Journal entries linked to it are kept.\n\n'
                    'Archive instead to keep the history.',
        ),
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (count > 0 && s.archivedAt == null)
            TextButton(
              onPressed: () => Navigator.pop(context, 'archive'),
              child: const Text('Archive'),
            ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Palette.danger,
              foregroundColor: Palette.white,
            ),
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    final actions = ref.read(appActionsProvider);
    final router = GoRouter.of(context);
    if (choice == 'archive') {
      await guarded(context, () => actions.setArchived(s.id, archived: true));
      return;
    }
    final ok = await guarded(context, () async {
      await actions.deleteSkill(s.id);
      return true;
    });
    if (ok == true) router.go(Routes.skills);
  }
}

enum _ChartRange { week, months }

class _Charts extends StatefulWidget {
  const _Charts({required this.detail, required this.today});

  final SkillDetail detail;
  final DayKey today;

  @override
  State<_Charts> createState() => _ChartsState();
}

class _ChartsState extends State<_Charts> {
  _ChartRange _range = _ChartRange.week;
  int _offset = 0; // weeks or 6-month windows back from now

  @override
  Widget build(BuildContext context) {
    final daily = widget.detail.daily;
    final today = widget.today;
    late final List<ChartBar> bars;
    late final String title;

    if (_range == _ChartRange.week) {
      final start = Days.add(Days.weekStart(today), -7 * _offset);
      bars = [
        for (var i = 0; i < 7; i++)
          () {
            final d = Days.add(start, i);
            return ChartBar(
              Fmt.weekdayShort(d).substring(0, 2),
              daily[d] ?? 0,
              highlight: d == today,
            );
          }(),
      ];
      title = _offset == 0
          ? 'This week'
          : '${Fmt.shortDate(start)} – ${Fmt.shortDate(Days.add(start, 6))}';
    } else {
      final end = Days.addMonths(Days.monthStart(today), -6 * _offset);
      bars = [
        for (var m = 5; m >= 0; m--)
          () {
            final start = Days.addMonths(end, -m);
            final last = Days.monthEnd(start);
            var sum = 0;
            daily.forEach((d, s) {
              if (d >= start && d <= last) sum += s;
            });
            return ChartBar(
              Fmt.monthShort(start),
              sum,
              highlight: today >= start && today <= last,
            );
          }(),
      ];
      title =
          '${Fmt.monthYear(Days.addMonths(end, -5))} – ${Fmt.monthShort(end)}';
    }
    final total = bars.fold<int>(0, (a, b) => a + b.seconds);
    final earliest = daily.keys.isEmpty
        ? today
        : daily.keys.reduce((a, b) => a < b ? a : b);
    final canGoBack = _range == _ChartRange.week
        ? Days.add(Days.weekStart(today), -7 * _offset) > earliest
        : Days.addMonths(Days.monthStart(today), -6 * _offset - 5) > earliest;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.md,
        Space.gutter,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: const BoxDecoration(
          color: Palette.inkCard,
          borderRadius: Radii.cardR,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.caption.copyWith(
                          color: Palette.white.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        Fmt.duration(total),
                        style: AppText.numeral.copyWith(
                          color: Palette.white,
                          fontSize: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                CircleIconButton(
                  icon: PhosphorIconsBold.caretLeft,
                  tooltip: 'Earlier',
                  size: 36,
                  background: Palette.white.withValues(alpha: 0.1),
                  foreground: Palette.white,
                  onPressed: canGoBack ? () => setState(() => _offset++) : null,
                ),
                const SizedBox(width: 6),
                CircleIconButton(
                  icon: PhosphorIconsBold.caretRight,
                  tooltip: 'Later',
                  size: 36,
                  background: Palette.white.withValues(alpha: 0.1),
                  foreground: Palette.white,
                  onPressed: _offset > 0
                      ? () => setState(() => _offset--)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            HoursBarChart(
              bars: bars,
              height: 170,
              barColor: Palette.lime,
              highlightColor: Palette.white,
              trackColor: Palette.white.withValues(alpha: 0.06),
              labelColor: Palette.white.withValues(alpha: 0.6),
              tooltipColor: Palette.white,
              tooltipTextColor: Palette.ink,
            ),
            const SizedBox(height: Space.md),
            SegmentedPills<_ChartRange>(
              values: _ChartRange.values,
              selected: _range,
              labelOf: (r) => r == _ChartRange.week ? 'Weekly' : 'Monthly',
              onChanged: (r) => setState(() {
                _range = r;
                _offset = 0;
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _Milestones extends StatelessWidget {
  const _Milestones({required this.detail});

  final SkillDetail detail;

  @override
  Widget build(BuildContext context) {
    final reached = {for (final m in detail.milestones) m.hours: m};
    final gl = context.gl;
    final color = Color(detail.skill.colorValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Milestones'),
        SizedBox(
          height: 96,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            scrollDirection: Axis.horizontal,
            itemCount: Levels.milestoneHours.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
            itemBuilder: (_, i) {
              final h = Levels.milestoneHours[i];
              final m = reached[h];
              final level = Levels.levelAtExactly(h);
              return Semantics(
                label:
                    '$h hours ${level == null ? '' : '(${level.name})'} '
                    '${m == null ? 'not reached yet' : 'reached ${Fmt.shortDate(m.dayKey)}'}',
                child: ExcludeSemantics(
                  child: Container(
                    width: 84,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: m != null ? color : gl.surface,
                      borderRadius: Radii.cardSmallR,
                      border: m != null ? null : Border.all(color: gl.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          m != null
                              ? PhosphorIconsFill.sealCheck
                              : PhosphorIconsRegular.lockSimple,
                          size: 18,
                          color: m != null ? Palette.ink : gl.muted,
                        ),
                        const Spacer(),
                        Text(
                          '${Fmt.number(h)}h',
                          style: AppText.subtitle.copyWith(
                            color: m != null ? Palette.ink : gl.text,
                          ),
                        ),
                        Text(
                          level?.name ??
                              (m != null
                                  ? Fmt.shortDate(m.dayKey)
                                  : 'Milestone'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                            fontSize: 11,
                            color: m != null
                                ? Palette.ink.withValues(alpha: 0.7)
                                : gl.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Target extends StatelessWidget {
  const _Target({required this.stats});

  final SkillStats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats.skill;
    final remaining = (s.targetHours * 3600 - stats.totalSec).clamp(
      0,
      double.infinity,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.md,
        Space.gutter,
        0,
      ),
      child: GLCard(
        color: Palette.limeSoft,
        child: Row(
          children: [
            SkillAvatar(skill: s, size: 48, inverted: true),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Goal: ${Fmt.number(s.targetHours.round())} hours',
                    style: AppText.subtitle.copyWith(color: Palette.ink),
                  ),
                  const SizedBox(height: 6),
                  ProgressBar(value: stats.targetFraction, color: Palette.ink),
                  const SizedBox(height: 6),
                  Text(
                    remaining == 0
                        ? 'Goal complete. Time for a bigger one?'
                        : '${(stats.targetFraction * 100).toStringAsFixed(stats.targetFraction < 0.1 ? 1 : 0)}% · ${Fmt.hours(remaining)} h to go',
                    style: AppText.caption.copyWith(
                      color: Palette.ink.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow({required this.session, required this.today});

  final SessionRow session;
  final DayKey today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gl = context.gl;
    final s = session;
    return Dismissible(
      key: ValueKey('session-${s.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.lg),
        decoration: const BoxDecoration(
          color: Palette.danger,
          borderRadius: Radii.cardSmallR,
        ),
        child: const Icon(PhosphorIconsBold.trash, color: Palette.white),
      ),
      confirmDismiss: (_) => confirm(
        context,
        title: 'Delete this session?',
        message: '${Fmt.duration(s.durationSec)} on ${Fmt.shortDate(s.dayKey)}',
        confirmLabel: 'Delete',
        destructive: true,
      ),
      onDismissed: (_) async {
        final actions = ref.read(appActionsProvider);
        await guarded(context, () => actions.deleteSession(s));
        if (context.mounted) {
          showSnack(
            context,
            'Session deleted',
            actionLabel: 'Undo',
            onAction: () => actions.restoreSession(s),
          );
        }
      },
      child: GLCard(
        radius: Radii.cardSmall,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        border: true,
        onTap: () => showSessionSheet(context, existing: s),
        semanticLabel:
            '${Fmt.duration(s.durationSec)}, ${Fmt.dayLabel(s.dayKey, today)}. Tap to edit',
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: gl.canvas,
                shape: BoxShape.circle,
              ),
              child: Icon(
                s.source == 'timer'
                    ? PhosphorIconsRegular.timer
                    : PhosphorIconsRegular.pencilSimple,
                size: 18,
                color: gl.text,
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fmt.dayLabel(s.dayKey, today),
                    style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (s.note != null)
                    Text(
                      s.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    )
                  else
                    Text(
                      s.source == 'timer'
                          ? 'Timer · started ${Fmt.time(s.startedAt)}'
                          : 'Logged manually',
                      style: context.text.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: Space.xs),
            Text(Fmt.duration(s.durationSec), style: AppText.subtitle),
          ],
        ),
      ),
    );
  }
}
