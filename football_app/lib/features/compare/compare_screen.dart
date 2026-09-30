import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../search/player_picker.dart';

enum ComparePeriod {
  current('Current season'),
  previous('Previous season'),
  career('Career'),
  competition('Competition'),
  last5('Last 5 matches'),
  last10('Last 10 matches');

  const ComparePeriod(this.label);
  final String label;
}

class CompareSide {
  const CompareSide({required this.profile, required this.stats, required this.team, required this.periodLabel});
  final PlayerProfile profile;
  final PlayerStatLine stats;
  final TeamRef? team;
  final String periodLabel;
}

typedef _CompareKey = (int player, ComparePeriod period, int? league);

/// Loads one side of a comparison for the chosen period.
final compareSideProvider = FutureProvider.autoDispose.family<CompareSide, _CompareKey>((ref, key) async {
  final (id, period, league) = key;
  final repo = ref.watch(repositoryProvider);
  final current = await ref.watch(playerCurrentSeasonProvider(id).future);
  final cur = (await ref.watch(playerProvider((id, current)).future)).data;
  switch (period) {
    case ComparePeriod.current:
      return CompareSide(profile: cur.profile, stats: cur.total, team: cur.mainTeam, periodLabel: '${seasonLabel(current)} · all competitions');
    case ComparePeriod.previous:
      final prev = (await repo.player(id, current - 1)).data;
      return CompareSide(profile: cur.profile, stats: prev.total, team: prev.mainTeam, periodLabel: '${seasonLabel(current - 1)} · all competitions');
    case ComparePeriod.competition:
      final lines = cur.seasons.where((s) => s.league.id == league).toList();
      final name = lines.firstOrNull?.league.name ?? 'Selected competition';
      return CompareSide(profile: cur.profile, stats: PlayerStatLine.sum(lines.map((l) => l.stats)), team: cur.mainTeam, periodLabel: '${seasonLabel(current)} · $name');
    case ComparePeriod.career:
      final seasons = await ref.watch(playerSeasonsProvider(id).future);
      final all = <PlayerStatLine>[];
      for (final s in seasons) {
        try {
          all.add((await repo.player(id, s)).data.total);
        } on DataException catch (e) {
          if (e.kind != DataErrorKind.notFound) rethrow;
        }
      }
      return CompareSide(profile: cur.profile, stats: PlayerStatLine.sum(all), team: cur.mainTeam, periodLabel: 'Career · ${seasons.isEmpty ? '' : '${seasons.first}–${seasons.last}'} (${all.length} seasons)');
    case ComparePeriod.last5:
    case ComparePeriod.last10:
      final n = period == ComparePeriod.last5 ? 5 : 10;
      final recent = await ref.watch(playerRecentProvider((id, n)).future);
      final label = recent.isEmpty ? 'Last $n matches' : 'Last ${recent.length} matches · ${shortDate(recent.first.match.kickoff)} – ${shortDate(recent.last.match.kickoff)}';
      return CompareSide(profile: cur.profile, stats: PlayerStatLine.sum(recent.map((e) => e.line.stats)), team: cur.mainTeam, periodLabel: label);
  }
});

/// Player vs player (spec §16).
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key, this.a, this.b});
  final int? a;
  final int? b;
  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  late int? _a = widget.a;
  late int? _b = widget.b;
  ComparePeriod _period = ComparePeriod.current;
  int? _league;

  Future<void> _pick(bool first) async {
    final hit = await pickPlayer(context, title: first ? 'First player' : 'Compare with');
    if (hit == null) return;
    setState(() => first ? _a = hit.id : _b = hit.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = _a == null ? null : ref.watch(compareSideProvider((_a!, _period, _league)));
    final b = _b == null ? null : ref.watch(compareSideProvider((_b!, _period, _league)));
    // Competitions available for "Competition" mode (from player A's season).
    final aSeason = _a == null ? null : ref.watch(playerCurrentSeasonProvider(_a!)).value;
    final aLeagues = (_a == null || aSeason == null) ? const <LeagueRef>[] : (ref.watch(playerProvider((_a!, aSeason))).value?.data.seasons.map((s) => s.league).toList() ?? const <LeagueRef>[]);

    return Scaffold(
      appBar: AppBar(title: const Text('Player comparison')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 60),
        children: [
          Row(children: [
            Expanded(child: _Slot(side: a, color: c.accent, onTap: () => _pick(true), empty: 'Choose player')),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('VS', style: AppType.display(18, color: c.textFaint, italic: true))),
            Expanded(child: _Slot(side: b, color: c.away, onTap: () => _pick(false), empty: 'Add player')),
          ]),
          const SizedBox(height: Space.lg),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in ComparePeriod.values)
              ChoiceChipPill(
                label: p.label,
                selected: _period == p,
                onTap: () => setState(() {
                  _period = p;
                  if (p == ComparePeriod.competition) _league ??= aLeagues.firstOrNull?.id;
                }),
              ),
          ]),
          if (_period == ComparePeriod.competition && aLeagues.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final l in {for (final l in aLeagues) l.id: l}.values)
                  Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChipPill(label: l.name, selected: _league == l.id, onTap: () => setState(() => _league = l.id), leading: LeagueLogo(league: l, size: 18))),
              ]),
            ),
          ],
          if (_period == ComparePeriod.career) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Career totals load every season on record — this can take a moment the first time.', style: AppType.body(12, color: c.textFaint))),
          const SizedBox(height: Space.lg),
          if (a == null || b == null)
            EmptyState(art: EmptyArt.search, title: 'Pick two players', message: 'Compare goals, creativity, defending and ratings over the period you choose.', actionLabel: 'Choose player', onAction: () => _pick(a == null), compact: true)
          else
            switch ((a, b)) {
              (AsyncValue(value: final va?), AsyncValue(value: final vb?)) => _Comparison(a: va, b: vb, period: _period),
              (AsyncValue(error: final e?), _) || (_, AsyncValue(error: final e?)) => ErrorState(error: e, compact: true),
              _ => const SkeletonList(count: 4, padding: EdgeInsets.zero),
            },
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.side, required this.color, required this.onTap, required this.empty});
  final AsyncValue<CompareSide>? side;
  final Color color;
  final VoidCallback onTap;
  final String empty;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = side?.value;
    return AppCard(
      onTap: onTap,
      border: true,
      child: SizedBox(
        height: 138,
        child: s == null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (side?.isLoading ?? false) const CircularProgressIndicator() else Icon(Icons.person_add_alt_1_rounded, color: color, size: 34),
                const SizedBox(height: 10),
                Text(empty, style: AppType.body(14, weight: 600, color: c.text)),
              ])
            : Column(children: [
                PlayerAvatar(name: s.profile.name, photo: s.profile.photo, size: 58, ring: color),
                const SizedBox(height: 8),
                Text(s.profile.name, style: context.text.titleSmall, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (s.team != null) Text(s.team!.name, style: AppType.body(12, color: c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Text('Change', style: AppType.body(11.5, weight: 600, color: color)),
              ]),
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.a, required this.b, required this.period});
  final CompareSide a;
  final CompareSide b;
  final ComparePeriod period;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sa = a.stats, sb = b.stats;
    double per90(int? v, PlayerStatLine s) => (v == null || (s.minutes ?? 0) == 0) ? 0 : v / s.minutes! * 90;
    final axes = <(String, double, double)>[
      ('Goals', per90(sa.goals, sa), per90(sb.goals, sb)),
      ('Assists', per90(sa.assists, sa), per90(sb.assists, sb)),
      ('Shots', per90(sa.shots, sa), per90(sb.shots, sb)),
      ('Key passes', per90(sa.keyPasses, sa), per90(sb.keyPasses, sb)),
      ('Dribbles', per90(sa.dribblesWon, sa), per90(sb.dribblesWon, sb)),
      ('Tackles', per90(sa.tackles, sa), per90(sb.tackles, sb)),
      ('Pass %', sa.passAccuracy ?? 0, sb.passAccuracy ?? 0),
    ];
    double norm(double v, double other) {
      final m = math.max(v, other);
      return m == 0 ? 0 : v / m * 100;
    }

    final rows = <(String, num?, num?, int)>[
      ('Appearances', sa.appearances, sb.appearances, 0),
      ('Minutes', sa.minutes, sb.minutes, 0),
      ('Goals', sa.goals, sb.goals, 0),
      ('Assists', sa.assists, sb.assists, 0),
      ('xG', sa.xg, sb.xg, 2),
      ('xA', sa.xa, sb.xa, 2),
      ('Shots', sa.shots, sb.shots, 0),
      ('Key passes', sa.keyPasses, sb.keyPasses, 0),
      ('Dribbles won', sa.dribblesWon, sb.dribblesWon, 0),
      ('Pass accuracy %', sa.passAccuracy, sb.passAccuracy, 0),
      ('Tackles', sa.tackles, sb.tackles, 0),
      ('Duels won', sa.duelsWon, sb.duelsWon, 0),
      ('Average rating', sa.rating, sb.rating, 2),
    ];
    final shown = rows.where((r) => r.$2 != null || r.$3 != null).toList();
    final missing = rows.where((r) => r.$2 == null && r.$3 == null).map((r) => r.$1).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // The selected period, stated clearly (spec: must be obvious).
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface2, borderRadius: Radii.lgAll),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Overline('Period: ${period.label}'),
          const SizedBox(height: 6),
          Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)), const SizedBox(width: 6), Expanded(child: Text(a.periodLabel, style: AppType.body(12.5, color: c.text)))]),
          const SizedBox(height: 4),
          Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: c.away, shape: BoxShape.circle)), const SizedBox(width: 6), Expanded(child: Text(b.periodLabel, style: AppType.body(12.5, color: c.text)))]),
        ]),
      ),
      const SizedBox(height: Space.md),
      AppCard(
        child: Column(children: [
          SizedBox(
            height: 260,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                dataSets: [
                  RadarDataSet(dataEntries: [for (final x in axes) RadarEntry(value: norm(x.$2, x.$3))], fillColor: c.accent.withValues(alpha: 0.25), borderColor: c.accent, borderWidth: 2, entryRadius: 2.5),
                  RadarDataSet(dataEntries: [for (final x in axes) RadarEntry(value: norm(x.$3, x.$2))], fillColor: c.away.withValues(alpha: 0.22), borderColor: c.away, borderWidth: 2, entryRadius: 2.5),
                  // Invisible anchor so both sets share a 0–100 scale.
                  RadarDataSet(dataEntries: [for (final _ in axes) const RadarEntry(value: 100)], fillColor: Colors.transparent, borderColor: Colors.transparent, borderWidth: 0, entryRadius: 0),
                ],
                getTitle: (i, angle) => RadarChartTitle(text: axes[i].$1),
                titleTextStyle: AppType.body(11.5, weight: 600, color: c.textMuted),
                titlePositionPercentageOffset: 0.14,
                tickCount: 3,
                ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
                tickBorderData: BorderSide(color: c.hairline),
                gridBorderData: BorderSide(color: c.hairline),
                radarBorderData: BorderSide(color: c.hairline),
              ),
              duration: Motion.slow,
              curve: Motion.emphasized,
            ),
          ),
          Text('Per 90 minutes, scaled to the better of the two', style: AppType.body(11.5, color: c.textFaint)),
        ]),
      ).animate().fadeIn(duration: Motion.slow).scale(begin: const Offset(0.96, 0.96), curve: Motion.emphasized),
      const SizedBox(height: Space.md),
      AppCard(
        child: Column(children: [
          for (final r in shown)
            StatCompareRow(label: r.$1, home: r.$2, away: r.$3, unit: r.$4 == 2 ? StatUnit.decimal : StatUnit.count, homeColor: c.accent, awayColor: c.away),
        ]),
      ),
      if (missing.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: NotProvided(missing.join(', '))),
    ]);
  }
}
