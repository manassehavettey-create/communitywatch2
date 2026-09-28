import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/phosphor_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/hours_chart.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/segmented_pills.dart';
import '../../../core/widgets/skill_icons.dart';
import '../../../core/widgets/states.dart';
import '../../log/data/entry_repository.dart';
import '../application/insights_providers.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  InsightPeriod _period = InsightPeriod.week;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(insightsProvider(_period));
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: TabHeader(bold: 'Insights', italic: 'at a glance')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: SegmentedPills<InsightPeriod>(
                values: InsightPeriod.values,
                selected: _period,
                labelOf: (p) => p.label,
                onChanged: (p) {
                  ref.read(hapticsProvider).tap();
                  setState(() => _period = p);
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AsyncView(
              value: data,
              onRetry: () => ref.invalidate(insightsProvider(_period)),
              data: (d) => AnimatedSwitcher(
                duration: Motion.medium,
                child: _Content(key: ValueKey(_period), data: d),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: Space.dockClearance + Space.lg)),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final gl = context.gl;
    final periodWord = switch (d.period) {
      InsightPeriod.week => 'week',
      InsightPeriod.month => 'month',
      InsightPeriod.year => 'year',
    };
    final change = Fmt.percentChange(d.seconds, d.prevSeconds);
    final gratitude = d.counts[EntryType.gratitude] ?? 0;
    final wins = d.counts[EntryType.win] ?? 0;
    final rangeLabel = '${Fmt.shortDate(d.from)} – ${Fmt.shortDate(d.to)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: FadeSlideIn(
                    child: GLCard(
                      color: Palette.lime,
                      semanticLabel: 'Practised ${Fmt.duration(d.seconds)} this $periodWord, $change versus last $periodWord',
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(PhosphorIconsBold.trendUp, size: 16, color: Palette.ink),
                                const SizedBox(width: 4),
                                Text('Practice', style: AppText.caption.copyWith(color: Palette.ink, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: Space.sm),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(change, style: AppText.display.copyWith(color: Palette.ink, fontSize: 36)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'vs last $periodWord',
                              style: AppText.caption.copyWith(color: Palette.ink.withValues(alpha: 0.7)),
                            ),
                            const Spacer(),
                            Text(
                              Fmt.duration(d.seconds),
                              style: AppText.subtitle.copyWith(color: Palette.ink),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: FadeSlideIn(
                    index: 1,
                    child: GLCard(
                      color: Palette.inkCard,
                      semanticLabel: '$gratitude gratitude entries and $wins wins this $periodWord',
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Journal', style: AppText.caption.copyWith(color: Palette.white.withValues(alpha: 0.7), fontWeight: FontWeight.w700)),
                            const SizedBox(height: Space.sm),
                            Text('${gratitude + wins}', style: AppText.display.copyWith(color: Palette.white, fontSize: 36)),
                            const SizedBox(height: 4),
                            Text('entries', style: AppText.caption.copyWith(color: Palette.white.withValues(alpha: 0.7))),
                            const SizedBox(height: Space.md),
                            _Legend(color: Palette.butter, label: 'Gratitude', value: gratitude),
                            const SizedBox(height: 4),
                            _Legend(color: Palette.blush, label: 'Wins', value: wins),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
          child: GLCard(
            border: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Overview', style: context.text.titleMedium)),
                    Text(rangeLabel, style: context.text.bodySmall),
                  ],
                ),
                const SizedBox(height: 2),
                Text(Fmt.duration(d.seconds), style: AppText.numeral.copyWith(color: gl.text, fontSize: 26)),
                const SizedBox(height: Space.md),
                HoursBarChart(
                  bars: [for (final b in d.buckets) ChartBar(b.label, b.seconds, highlight: b.highlight)],
                  barColor: gl.inverse,
                  highlightColor: Palette.limeDeep,
                  height: 190,
                ),
              ],
            ),
          ),
        ),
        if (d.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: Space.xl),
            child: EmptyState(
              image: AppAssets.emptyInsights,
              title: 'Nothing here yet',
              message: 'Log practice or a journal entry and your trends will appear.',
              compact: true,
            ),
          ),
        if (d.bySkill.isNotEmpty) ...[
          const SectionHeader('By skill'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: GLCard(
              border: true,
              child: Column(
                children: [
                  for (var i = 0; i < d.bySkill.length; i++) ...[
                    if (i > 0) const SizedBox(height: Space.md),
                    _SkillBar(share: d.bySkill[i], max: d.bySkill.first.seconds, total: d.seconds),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SectionHeader('Streaks'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Row(
            children: [
              Expanded(
                child: _StreakRing(
                  label: 'Practice',
                  current: d.practiceStreak.current,
                  best: d.practiceStreak.longest,
                  color: Palette.lavender,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _StreakRing(
                  label: 'Journal',
                  current: d.logStreak.current,
                  best: d.logStreak.longest,
                  color: Palette.apricot,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
          child: Text(
            '${Fmt.plural(d.activeDays, 'active day')} · ${Fmt.plural(d.sessions, 'session')} this $periodWord',
            style: context.text.bodySmall,
          ),
        ),
        if (d.topTags.isNotEmpty) ...[
          const SectionHeader('Top tags'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < d.topTags.length; i++)
                  TagChip(
                    '#${d.topTags[i].name} · ${d.topTags[i].count}',
                    color: Palette.skillColors[i % Palette.skillColors.length],
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.xl),
        const _RecapPromo(),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: AppText.caption.copyWith(color: Palette.white.withValues(alpha: 0.8))),
        ),
        Text('$value', style: AppText.caption.copyWith(color: Palette.white, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _SkillBar extends StatelessWidget {
  const _SkillBar({required this.share, required this.max, required this.total});

  final SkillShare share;
  final int max;
  final int total;

  @override
  Widget build(BuildContext context) {
    final color = Color(share.skill.colorValue);
    final pct = total == 0 ? 0 : (share.seconds / total * 100).round();
    return Semantics(
      label: '${share.skill.name}: ${Fmt.duration(share.seconds)}, $pct percent',
      child: ExcludeSemantics(
        child: Row(
          children: [
            SkillAvatar(skill: share.skill, size: 36),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          share.skill.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(Fmt.duration(share.seconds), style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ProgressBar(value: max == 0 ? 0 : share.seconds / max, height: 10, color: color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakRing extends StatelessWidget {
  const _StreakRing({required this.label, required this.current, required this.best, required this.color});

  final String label;
  final int current;
  final int best;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GLCard(
      color: color,
      semanticLabel: '$label streak $current days, best $best',
      child: ExcludeSemantics(
        child: Row(
          children: [
            ProgressRing(
              value: best == 0 ? 0 : current / best,
              size: 56,
              stroke: 6,
              color: Palette.ink,
              child: const AppImage(AppAssets.streakFlame, width: 26, height: 26),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.caption.copyWith(color: Palette.ink, fontWeight: FontWeight.w700)),
                  Text('${current}d', style: AppText.numeral.copyWith(color: Palette.ink, fontSize: 24)),
                  Text('best ${best}d', style: AppText.caption.copyWith(color: Palette.ink.withValues(alpha: 0.7))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecapPromo extends StatelessWidget {
  const _RecapPromo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: GLCard(
        color: Palette.electric,
        radius: Radii.hero,
        padding: EdgeInsets.zero,
        clip: true,
        onTap: () => context.push(Routes.recap()),
        semanticLabel: 'Monthly recap: look how far you have come',
        child: SizedBox(
          height: 180,
          child: Stack(
            children: [
              const Positioned(
                right: -30,
                bottom: -20,
                child: AppImage(AppAssets.recapMountain, width: 210),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MONTHLY RECAP',
                      style: AppText.caption.copyWith(
                        color: Palette.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      'LOOK HOW\nFAR YOU\'VE\nCOME.',
                      style: AppText.display.copyWith(color: Palette.white, fontSize: 30, height: 0.95),
                    ),
                    const Spacer(),
                    const Icon(PhosphorIconsBold.arrowUpRight, color: Palette.lime),
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
