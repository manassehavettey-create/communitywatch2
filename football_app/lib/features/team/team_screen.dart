import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/favorites.dart';
import '../../app/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../domain/form.dart';
import '../league/standings_view.dart';
import '../player/player_screen.dart';
import '../search/recent.dart';

const _teamTabs = ['Overview', 'Fixtures', 'Results', 'Squad', 'Stats', 'Transfers'];

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: _teamTabs.length, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(teamProvider(widget.id));
    return Scaffold(
      body: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(teamProvider(widget.id)),
        builder: (fresh) {
          final t = fresh.data;
          recordRecent(ref, SearchHit(kind: SearchKind.team, id: t.ref.id, title: t.ref.name, subtitle: t.country, image: t.ref.logo));
          return SafeArea(
            bottom: false,
            child: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(child: _TeamHeader(team: t)),
              SliverPersistentHeader(pinned: true, delegate: _Tabs(tabs: _tabs, color: context.colors.bg)),
            ],
            body: TabBarView(controller: _tabs, children: [
              _Overview(team: t, openTab: _tabs.animateTo),
              _MatchesList(teamId: t.ref.id, upcoming: true),
              _MatchesList(teamId: t.ref.id, upcoming: false),
              _Squad(teamId: t.ref.id),
              _Stats(teamId: t.ref.id),
              _TeamTransfers(teamId: t.ref.id),
            ]),
          ));
        },
      ),
    );
  }
}

class _Tabs extends SliverPersistentHeaderDelegate {
  _Tabs({required this.tabs, required this.color});
  final TabController tabs;
  final Color color;
  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: color, child: PillTabBar(controller: tabs, tabs: _teamTabs));
  @override
  bool shouldRebuild(_Tabs old) => old.color != color;
}

class _TeamHeader extends ConsumerWidget {
  const _TeamHeader({required this.team});
  final TeamInfo team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final league = ref.watch(teamPrimaryLeagueProvider(team.ref.id)).value;
    final table = league == null ? null : ref.watch(standingsProvider(league.ref.id)).value?.data;
    final row = table?.rowFor(team.ref.id);
    return Container(
      decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -1.2), radius: 1.3, colors: [c.accent.withValues(alpha: 0.10), c.bg])),
      padding: const EdgeInsets.fromLTRB(Space.gutter, 8, Space.gutter, Space.md),
      child: Column(children: [
        Row(children: [
          CircleIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => context.canPop() ? context.pop() : context.go('/home')),
          const Spacer(),
          FollowButton(favorite: Favorite(kind: FavKind.team, id: team.ref.id, name: team.ref.name, image: team.ref.logo, subtitle: league?.ref.name ?? team.country)),
        ]),
        TeamCrest(team: team.ref, size: 96).animate().scale(begin: const Offset(0.8, 0.8), curve: Motion.spring, duration: Motion.slow),
        const SizedBox(height: 12),
        Text(team.ref.name.toUpperCase(), textAlign: TextAlign.center, style: AppType.display(28, color: c.text)),
        const SizedBox(height: 6),
        Text([team.country, if (team.founded != null) 'Founded ${team.founded}'].whereType<String>().join(' · '), style: AppType.body(13, color: c.textMuted)),
        if (league != null) ...[
          const SizedBox(height: 12),
          Pressable(
            onTap: () => context.push('/league/${league.ref.id}'),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
              decoration: BoxDecoration(color: c.surface2, borderRadius: Radii.pillAll),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                LeagueLogo(league: league.ref, size: 20),
                const SizedBox(width: 8),
                Text(league.ref.name, style: AppType.body(13, weight: 600, color: c.text)),
                if (row != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: c.accent, borderRadius: Radii.pillAll),
                    child: Text(ordinal(row.rank), style: AppType.numeric(12.5, weight: 800, color: c.onAccent)),
                  ),
                  const SizedBox(width: 6),
                  Text('${row.points} pts', style: AppType.body(12.5, color: c.textMuted)),
                ],
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Overview extends ConsumerStatefulWidget {
  const _Overview({required this.team, required this.openTab});
  final TeamInfo team;
  final void Function(int) openTab;
  @override
  ConsumerState<_Overview> createState() => _OverviewState();
}

class _OverviewState extends ConsumerState<_Overview> {
  int _formN = 5;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final id = widget.team.ref.id;
    final ms = ref.watch(teamMatchesProvider(id));
    final league = ref.watch(teamPrimaryLeagueProvider(id)).value;
    return AsyncView(
      value: ms,
      onRetry: () => ref.invalidate(teamMatchesProvider(id)),
      builder: (fresh) {
        final all = fresh.data;
        final live = ref.watch(liveMatchesProvider).value?.data.where((m) => m.involves(id)).firstOrNull;
        final next = all.where((m) => m.status.isScheduled && m.kickoff.isAfter(DateTime.now())).firstOrNull;
        final form = recentForm(all, id, count: _formN);
        final sum = summarizeForm(form, id);
        final finishedCount = all.where((m) => m.status.isFinished).length;
        final sections = <Widget>[
          FreshnessBanner(fresh: fresh, padding: EdgeInsets.zero),
          if (live != null) ...[const SectionHeader('Live now', padding: EdgeInsets.only(top: Space.md, bottom: Space.sm)), LiveMatchCard(match: live, featured: true, scope: 'team', width: double.infinity)],
          if (next != null) ...[
            const SectionHeader('Next match', padding: EdgeInsets.only(top: Space.md, bottom: Space.sm)),
            MatchRow(match: next, scope: 'tnext', showLeague: true, showDate: true, highlightTeamId: id),
          ],
          SectionHeader(
            'Form',
            padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final n in [5, 10, 20])
                if (n == 5 || finishedCount >= n - 4) Padding(padding: const EdgeInsets.only(left: 6), child: ChoiceChipPill(label: '$n', selected: _formN == n, onTap: () => setState(() => _formN = n))),
            ]),
          ),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FormStrip(key: ValueKey(_formN), results: form.map((e) => e.result).toList(), size: _formN > 10 ? 20 : 28, onTapIndex: (i) => context.push('/match/${form[i].match.id}')),
              const SizedBox(height: 12),
              Text('Last ${form.length}: ${sum.wins}W ${sum.draws}D ${sum.losses}L · ${sum.points} pts · goals ${sum.goalsFor}–${sum.goalsAgainst}', style: AppType.body(13, color: c.textMuted)),
              if (form.length < _formN) Text('Only ${form.length} results available this season.', style: AppType.body(12, color: c.textFaint)),
            ]),
          ),
          if (league != null) ...[
            SectionHeader('Table', padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm), action: 'Full table', onAction: () => context.push('/league/${league.ref.id}')),
            _TableSnippet(leagueId: league.ref.id, teamId: id),
          ],
          SectionHeader('Recent results', padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm), action: 'All', onAction: () => widget.openTab(2)),
          for (final e in form.reversed.take(3)) Padding(padding: const EdgeInsets.only(bottom: 6), child: MatchRow(match: e.match, scope: 'tr', showDate: true, highlightTeamId: id)),
          if (widget.team.venueName != null) ...[
            const SectionHeader('Stadium', padding: EdgeInsets.only(top: Space.xl, bottom: Space.sm)),
            AppCard(
              child: Row(children: [
                Icon(Icons.stadium_rounded, color: c.accentInk),
                const SizedBox(width: 12),
                Expanded(child: Text([widget.team.venueName, widget.team.venueCity].whereType<String>().join(', '), style: AppType.body(14, weight: 600, color: c.text))),
                if (widget.team.venueCapacity != null) Text('${widget.team.venueCapacity} seats', style: AppType.body(12.5, color: c.textMuted)),
              ]),
            ),
          ],
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 60),
          children: [for (var i = 0; i < sections.length; i++) sections[i].animate(delay: Motion.staggerFor(i)).fadeIn(duration: Motion.base)],
        );
      },
    );
  }
}

class _TableSnippet extends ConsumerWidget {
  const _TableSnippet({required this.leagueId, required this.teamId});
  final int leagueId;
  final int teamId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(standingsProvider(leagueId));
    return switch (async) {
      AsyncValue(value: Fresh(data: final t?)) => () {
          final group = t.groups.firstWhere((g) => g.rows.any((r) => r.team.id == teamId), orElse: () => t.groups.first);
          final i = group.rows.indexWhere((r) => r.team.id == teamId);
          final start = (i - 2).clamp(0, (group.rows.length - 5).clamp(0, 999));
          return StandingsView(rows: group.rows.sublist(start, (start + 5).clamp(0, group.rows.length)), highlightTeamId: teamId, compact: true);
        }(),
      AsyncValue(hasValue: true) => const NotProvided('League table'),
      AsyncValue(:final error?) => ErrorState(error: error, compact: true),
      _ => const Skeleton(height: 200, radius: Radii.xl),
    };
  }
}

class _MatchesList extends ConsumerWidget {
  const _MatchesList({required this.teamId, required this.upcoming});
  final int teamId;
  final bool upcoming;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(teamMatchesProvider(teamId)),
      onRetry: () => ref.invalidate(teamMatchesProvider(teamId)),
      builder: (fresh) {
        final list = upcoming ? fresh.data.where((m) => !m.status.isFinished && m.status.phase != MatchPhase.cancelled).toList() : (fresh.data.where((m) => m.status.isFinished).toList().reversed.toList());
        if (list.isEmpty) return ListView(children: [EmptyState(art: EmptyArt.matches, title: upcoming ? 'No fixtures' : 'No results yet', message: upcoming ? 'No upcoming fixtures listed for this season.' : 'Results will appear here once matches are played.', compact: true)]);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 60),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final row = MatchRow(match: list[i], scope: 'tl$i', showLeague: true, showDate: true, highlightTeamId: teamId, trailing: upcoming ? null : _ResultPill(result: list[i].resultFor(teamId)));
            return i < 10 ? row.animate(delay: Motion.staggerFor(i)).fadeIn(duration: Motion.base).slideY(begin: 0.1) : row;
          },
        );
      },
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({this.result});
  final String? result;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (result == null) return const SizedBox.shrink();
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: result == 'W' ? c.win : (result == 'L' ? c.loss : c.surface3), borderRadius: BorderRadius.circular(8)),
      child: Text(result!, style: AppType.display(12, color: result == 'D' ? c.text : c.onAccent)),
    );
  }
}

class _Squad extends ConsumerWidget {
  const _Squad({required this.teamId});
  final int teamId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return AsyncView(
      value: ref.watch(squadProvider(teamId)),
      onRetry: () => ref.invalidate(squadProvider(teamId)),
      builder: (fresh) {
        final groups = [PositionGroup.goalkeeper, PositionGroup.defender, PositionGroup.midfielder, PositionGroup.forward, PositionGroup.unknown];
        if (fresh.data.isEmpty) return ListView(children: const [EmptyState(art: EmptyArt.search, title: 'No squad list', message: 'The provider has no squad for this team.', compact: true)]);
        return ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 60),
          children: [
            for (final g in groups)
              if (fresh.data.any((p) => p.group == g)) ...[
                SectionHeader(g.plural, padding: const EdgeInsets.only(top: Space.lg, bottom: Space.sm)),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [
                    for (final p in fresh.data.where((p) => p.group == g).toList()..sort((a, b) => (a.number ?? 99).compareTo(b.number ?? 99)))
                      ListTile(
                        onTap: () => context.push('/player/${p.id}'),
                        leading: PlayerAvatar(name: p.name, photo: p.photo, size: 40),
                        title: Text(p.name, style: AppType.body(14.5, weight: 600, color: c.text)),
                        subtitle: Text([g.label, if (p.age != null) '${p.age} yrs'].join(' · '), style: AppType.body(12.5, color: c.textMuted)),
                        trailing: Text(p.number == null ? '' : '#${p.number}', style: AppType.numeric(16, color: c.textMuted)),
                      ),
                  ]),
                ),
              ],
          ],
        );
      },
    );
  }
}

class _Stats extends ConsumerWidget {
  const _Stats({required this.teamId});
  final int teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final league = ref.watch(teamPrimaryLeagueProvider(teamId));
    final provider = ref.watch(repositoryProvider).providerName;
    return AsyncView(
      value: league,
      builder: (lg) {
        if (lg == null) return const Center(child: NotProvided('Team statistics'));
        final async = ref.watch(teamStatsProvider((teamId, lg.ref.id)));
        return AsyncView(
          value: async,
          onRetry: () => ref.invalidate(teamStatsProvider((teamId, lg.ref.id))),
          builder: (fresh) {
            final s = fresh.data;
            if (s == null) return ListView(children: const [EmptyState(art: EmptyArt.matches, title: 'No statistics yet', message: 'Season statistics appear once the team has played.', compact: true)]);
            final missing = [if (s.possession == null) 'Possession', if (s.shotsPerGame == null) 'Shots', if (s.xg == null) 'xG', if (s.passAccuracy == null) 'Pass accuracy'];
            return ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 60),
              children: [
                Overline('${lg.ref.name} · ${seasonLabel(s.season)}'),
                const SizedBox(height: Space.sm),
                AppCard(
                  child: Row(children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: PieChart(
                        PieChartData(sectionsSpace: 3, centerSpaceRadius: 36, startDegreeOffset: -90, sections: [
                          PieChartSectionData(value: (s.wins ?? 0).toDouble(), color: c.win, radius: 18, showTitle: false),
                          PieChartSectionData(value: (s.draws ?? 0).toDouble(), color: c.surface3, radius: 18, showTitle: false),
                          PieChartSectionData(value: (s.losses ?? 0).toDouble(), color: c.loss, radius: 18, showTitle: false),
                        ]),
                        duration: Motion.slow,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${s.played ?? 0} played', style: AppType.body(13, color: c.textMuted)),
                        const SizedBox(height: 6),
                        for (final (l, v, col) in [('Wins', s.wins, c.win), ('Draws', s.draws, c.textMuted), ('Losses', s.losses, c.loss)])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: col, shape: BoxShape.circle)), const SizedBox(width: 8), Text(l, style: AppType.body(14, color: c.text)), const Spacer(), Text('${v ?? 0}', style: AppType.numeric(18, color: c.text))]),
                          ),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: Space.sm),
                StatGrid(tiles: [
                  StatTile(label: 'Goals scored', value: '${s.goalsFor ?? '—'}', sub: s.goalsForHome == null ? null : 'H ${s.goalsForHome} · A ${s.goalsForAway}', highlight: true),
                  StatTile(label: 'Goals conceded', value: '${s.goalsAgainst ?? '—'}', sub: s.goalsAgainstHome == null ? null : 'H ${s.goalsAgainstHome} · A ${s.goalsAgainstAway}'),
                  StatTile(label: 'Clean sheets', value: '${s.cleanSheets ?? '—'}'),
                  StatTile(label: 'Failed to score', value: '${s.failedToScore ?? '—'}'),
                  StatTile(label: 'Cards', value: '${s.yellow ?? 0}Y · ${s.red ?? 0}R'),
                  if (s.possession != null) StatTile(label: 'Avg possession', value: '${s.possession!.round()}%'),
                  if (s.shotsPerGame != null) StatTile(label: 'Shots / game', value: s.shotsPerGame!.toStringAsFixed(1)),
                  if (s.xg != null) StatTile(label: 'xG / game', value: s.xg!.toStringAsFixed(2)),
                  if (s.passAccuracy != null) StatTile(label: 'Pass accuracy', value: '${s.passAccuracy!.round()}%'),
                  if (s.penaltiesScored != null) StatTile(label: 'Penalties', value: '${s.penaltiesScored}/${(s.penaltiesScored ?? 0) + (s.penaltiesMissed ?? 0)}'),
                ]),
                if (s.homeRecord != null && s.awayRecord != null) ...[
                  const SectionHeader('Home vs away', padding: EdgeInsets.only(top: Space.xl, bottom: Space.sm)),
                  AppCard(
                    child: Column(children: [
                      StatCompareRow(label: 'Wins', home: s.homeRecord!.$1, away: s.awayRecord!.$1, unit: StatUnit.count),
                      StatCompareRow(label: 'Draws', home: s.homeRecord!.$2, away: s.awayRecord!.$2, unit: StatUnit.count),
                      StatCompareRow(label: 'Losses', home: s.homeRecord!.$3, away: s.awayRecord!.$3, unit: StatUnit.count),
                      if (s.goalsForHome != null) StatCompareRow(label: 'Goals scored', home: s.goalsForHome, away: s.goalsForAway, unit: StatUnit.count),
                      if (s.goalsAgainstHome != null) StatCompareRow(label: 'Goals conceded', home: s.goalsAgainstHome, away: s.goalsAgainstAway, unit: StatUnit.count),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Home', style: AppType.body(12, color: c.textFaint)), Text('Away', style: AppType.body(12, color: c.textFaint))]),
                    ]),
                  ),
                ],
                if (s.cardsByPeriod.isNotEmpty) ...[
                  const SectionHeader('Cards by period', padding: EdgeInsets.only(top: Space.xl, bottom: Space.sm)),
                  AppCard(child: SizedBox(height: 170, child: _CardsChart(periods: s.cardsByPeriod))),
                ],
                if (s.formations.isNotEmpty) ...[
                  const SectionHeader('Formations used', padding: EdgeInsets.only(top: Space.xl, bottom: Space.sm)),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final (f, n) in s.formations) Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: c.surface2, borderRadius: Radii.pillAll), child: Text('$f · $n', style: AppType.numeric(13.5, weight: 650, color: c.text))),
                  ]),
                ],
                if (missing.isNotEmpty) Padding(padding: const EdgeInsets.only(top: Space.lg), child: NotProvided(missing.join(', '), provider: provider)),
              ],
            );
          },
        );
      },
    );
  }
}

class _CardsChart extends StatelessWidget {
  const _CardsChart({required this.periods});
  final Map<String, (int, int)> periods;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final keys = periods.keys.where((k) => !k.startsWith('91') && !k.startsWith('106')).toList()..sort((a, b) => (int.tryParse(a.split('-').first) ?? 0).compareTo(int.tryParse(b.split('-').first) ?? 0));
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(keys[v.toInt()], style: AppType.body(10.5, color: c.textFaint))))),
        ),
        barGroups: [
          for (var i = 0; i < keys.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: (periods[keys[i]]!.$1 + periods[keys[i]]!.$2).toDouble(),
                width: 16,
                borderRadius: BorderRadius.circular(5),
                rodStackItems: [
                  BarChartRodStackItem(0, periods[keys[i]]!.$1.toDouble(), c.yellowCard),
                  BarChartRodStackItem(periods[keys[i]]!.$1.toDouble(), (periods[keys[i]]!.$1 + periods[keys[i]]!.$2).toDouble(), c.redCard),
                ],
              ),
            ]),
        ],
      ),
      duration: Motion.slow,
    );
  }
}

class _TeamTransfers extends ConsumerWidget {
  const _TeamTransfers({required this.teamId});
  final int teamId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(teamTransfersProvider(teamId)),
      onRetry: () => ref.invalidate(teamTransfersProvider(teamId)),
      builder: (fresh) {
        final ins = fresh.data.where((t) => t.to.id == teamId).toList();
        final outs = fresh.data.where((t) => t.from.id == teamId).toList();
        if (fresh.data.isEmpty) return ListView(children: const [EmptyState(art: EmptyArt.search, title: 'No transfers', message: 'No confirmed transfers on record for this team.', compact: true)]);
        return ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 60),
          children: [
            Row(children: [ProvenanceTag(fresh.provenance == Provenance.demo ? Provenance.demo : Provenance.confirmed, compact: true, source: 'completed transfers only')]),
            if (ins.isNotEmpty) ...[const SectionHeader('Arrivals', padding: EdgeInsets.only(top: Space.lg, bottom: Space.sm)), for (final t in ins.take(15)) TransferTile(transfer: t)],
            if (outs.isNotEmpty) ...[const SectionHeader('Departures', padding: EdgeInsets.only(top: Space.lg, bottom: Space.sm)), for (final t in outs.take(15)) TransferTile(transfer: t)],
          ],
        );
      },
    );
  }
}
