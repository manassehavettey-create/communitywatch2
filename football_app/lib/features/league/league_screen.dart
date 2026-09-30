import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/favorites.dart';
import '../../app/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../search/recent.dart';
import '../share/share_screen.dart';
import 'standings_view.dart';

const _leagueTabs = ['Table', 'Fixtures', 'Results', 'Top scorers', 'Assists', 'Player ratings', 'Team stats'];

class LeagueScreen extends ConsumerStatefulWidget {
  const LeagueScreen({super.key, required this.id, this.initialTab});
  final int id;
  final String? initialTab;
  @override
  ConsumerState<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends ConsumerState<LeagueScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: _leagueTabs.length, vsync: this, initialIndex: _leagueTabs.indexWhere((t) => t.toLowerCase() == widget.initialTab).clamp(0, _leagueTabs.length - 1));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final info = ref.watch(leagueInfoProvider(widget.id));
    final season = ref.watch(leagueSeasonProvider(widget.id)).value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView(
          value: info,
          onRetry: () => ref.invalidate(leagueInfoProvider(widget.id)),
          builder: (lg) {
            if (lg == null) return const ErrorState(error: DataException(DataErrorKind.notFound, 'Competition not found.'));
            recordRecent(ref, SearchHit(kind: SearchKind.league, id: lg.ref.id, title: lg.ref.name, subtitle: lg.ref.country, image: lg.ref.logo));
            final seasonInfo = lg.seasons.where((s) => s.year == season).firstOrNull;
            return NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, 8, Space.gutter, Space.sm),
                    child: Column(children: [
                      Row(children: [
                        CircleIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => context.canPop() ? context.pop() : context.go('/leagues')),
                        const Spacer(),
                        CircleIconButton(icon: Icons.ios_share_rounded, tooltip: 'Share table', onTap: () => context.push('/share', extra: ShareRequest.table(lg.ref.id))),
                        const SizedBox(width: 8),
                        FollowButton(favorite: Favorite(kind: FavKind.league, id: lg.ref.id, name: lg.ref.name, image: lg.ref.logo, subtitle: lg.ref.country)),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.isDark ? Colors.white : c.surface, borderRadius: Radii.lgAll), child: LeagueLogo(league: lg.ref, size: 44)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(lg.ref.name.toUpperCase(), style: AppType.display(24, color: c.text), maxLines: 2),
                            Text([lg.ref.country, if (season != null) seasonLabel(season, start: seasonInfo?.start, end: seasonInfo?.end)].whereType<String>().join(' · '), style: AppType.body(13, color: c.textMuted)),
                          ]),
                        ),
                      ]).animate().fadeIn(duration: Motion.slow).slideY(begin: 0.1),
                    ]),
                  ),
                ),
                SliverPersistentHeader(pinned: true, delegate: _TabsDelegate(tabs: _tabs, color: c.bg)),
              ],
              body: TabBarView(controller: _tabs, children: [
                _TableTab(leagueId: widget.id),
                _MatchesTab(leagueId: widget.id, results: false),
                _MatchesTab(leagueId: widget.id, results: true),
                _LeadersTab(leagueId: widget.id, kind: _Leader.goals),
                _LeadersTab(leagueId: widget.id, kind: _Leader.assists),
                _LeadersTab(leagueId: widget.id, kind: _Leader.rating),
                _TeamStatsTab(leagueId: widget.id),
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  _TabsDelegate({required this.tabs, required this.color});
  final TabController tabs;
  final Color color;
  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: color, child: PillTabBar(controller: tabs, tabs: _leagueTabs));
  @override
  bool shouldRebuild(_TabsDelegate old) => old.color != color;
}

class _TableTab extends ConsumerWidget {
  const _TableTab({required this.leagueId});
  final int leagueId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(standingsProvider(leagueId)),
      onRetry: () => ref.invalidate(standingsProvider(leagueId)),
      builder: (fresh) {
        final t = fresh.data;
        if (t == null || t.groups.isEmpty) return ListView(children: const [EmptyState(art: EmptyArt.matches, title: 'No table for this competition', message: 'Knockout competitions and some leagues have no standings with the provider.', compact: true)]);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(standingsProvider(leagueId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 60),
            children: [
              FreshnessBanner(fresh: fresh, padding: const EdgeInsets.only(bottom: 8)),
              for (final g in t.groups) ...[
                if (t.groups.length > 1 && g.name != null) Padding(padding: const EdgeInsets.only(top: Space.md, bottom: 8), child: Text(g.name!, style: context.text.titleMedium)),
                StandingsView(rows: g.rows),
              ],
              const SizedBox(height: Space.md),
              ZoneLegend(table: t),
            ],
          ),
        );
      },
    );
  }
}

class _MatchesTab extends ConsumerStatefulWidget {
  const _MatchesTab({required this.leagueId, required this.results});
  final int leagueId;
  final bool results;
  @override
  ConsumerState<_MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends ConsumerState<_MatchesTab> {
  int _rounds = 2;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AsyncView(
      value: ref.watch(leagueMatchesProvider(widget.leagueId)),
      onRetry: () => ref.invalidate(leagueMatchesProvider(widget.leagueId)),
      builder: (fresh) {
        var list = fresh.data.where((m) => widget.results ? m.status.isFinished : !m.status.isFinished).toList();
        list.sort((a, b) => widget.results ? b.kickoff.compareTo(a.kickoff) : a.kickoff.compareTo(b.kickoff));
        if (list.isEmpty) return ListView(children: [EmptyState(art: EmptyArt.matches, title: widget.results ? 'No results yet' : 'No fixtures left', message: widget.results ? 'Results appear after matches are played.' : 'The provider lists no upcoming fixtures.', compact: true)]);
        final byRound = groupBy(list, (Match m) => m.league.round ?? dayLabel(m.kickoff));
        final keys = byRound.keys.take(_rounds).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 60),
          children: [
            for (final k in keys) ...[
              Padding(padding: const EdgeInsets.only(top: Space.lg, bottom: Space.sm), child: Text(k.replaceAll('Regular Season - ', 'Matchday '), style: context.text.titleMedium)),
              for (final m in byRound[k]!) Padding(padding: const EdgeInsets.only(bottom: 6), child: MatchRow(match: m, scope: 'lg${m.id}', showDate: true)),
            ],
            if (byRound.length > _rounds)
              Padding(
                padding: const EdgeInsets.only(top: Space.md),
                child: PillButton(label: 'Show more', primary: false, expand: true, onTap: () => setState(() => _rounds += 3)),
              ),
            if (!widget.results) Padding(padding: const EdgeInsets.only(top: Space.md), child: Text('Times shown in your local time zone.', style: AppType.body(11.5, color: c.textFaint))),
          ],
        );
      },
    );
  }
}

enum _Leader { goals, assists, rating }

class _LeadersTab extends ConsumerWidget {
  const _LeadersTab({required this.leagueId, required this.kind});
  final int leagueId;
  final _Leader kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final provider = ref.watch(repositoryProvider).providerName;
    final AsyncValue<List<PlayerWithSeasons>> data = switch (kind) {
      _Leader.goals => ref.watch(topScorersProvider(leagueId)).whenData((f) => f.data),
      _Leader.assists => ref.watch(topAssistsProvider(leagueId)).whenData((f) => f.data),
      _Leader.rating => () {
          final a = ref.watch(topScorersProvider(leagueId));
          final b = ref.watch(topAssistsProvider(leagueId));
          if (a.hasError) return AsyncValue<List<PlayerWithSeasons>>.error(a.error!, a.stackTrace ?? StackTrace.current);
          if (!a.hasValue || !b.hasValue) return const AsyncValue<List<PlayerWithSeasons>>.loading();
          final map = {for (final p in [...a.value!.data, ...b.value!.data]) p.profile.id: p};
          return AsyncValue.data(map.values.where((p) => p.seasons.any((s) => s.league.id == leagueId && s.stats.rating != null)).toList());
        }(),
    };
    return AsyncView(
      value: data,
      builder: (list) {
        PlayerStatLine line(PlayerWithSeasons p) => PlayerStatLine.sum(p.seasons.where((s) => s.league.id == leagueId).map((s) => s.stats));
        final sorted = [...list];
        if (kind == _Leader.rating) sorted.sort((a, b) => (line(b).rating ?? 0).compareTo(line(a).rating ?? 0));
        if (sorted.isEmpty) return ListView(children: const [EmptyState(art: EmptyArt.search, title: 'No leaders yet', message: 'Leaderboards appear once the provider publishes them.', compact: true)]);
        final maxV = switch (kind) { _Leader.goals => line(sorted.first).goals ?? 1, _Leader.assists => line(sorted.first).assists ?? 1, _Leader.rating => 10 };
        return ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 60),
          children: [
            if (kind == _Leader.rating) Padding(padding: const EdgeInsets.only(bottom: Space.sm), child: Text('Average $provider match rating, among the competition\'s top scorers and assist providers.', style: AppType.body(12.5, color: c.textMuted))),
            for (var i = 0; i < sorted.length; i++)
              () {
                final p = sorted[i];
                final s = line(p);
                final v = switch (kind) { _Leader.goals => s.goals ?? 0, _Leader.assists => s.assists ?? 0, _Leader.rating => s.rating ?? 0 };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AppCard(
                    onTap: () => context.push('/player/${p.profile.id}'),
                    padding: const EdgeInsets.all(12),
                    color: i == 0 ? null : c.surface,
                    gradient: i == 0 ? LinearGradient(colors: [c.accent, Color.lerp(c.accent, c.mint, 0.4)!]) : null,
                    child: Row(children: [
                      SizedBox(width: 26, child: Text('${i + 1}', style: AppType.numeric(18, color: i == 0 ? c.onAccent : c.textFaint))),
                      PlayerAvatar(name: p.profile.name, photo: p.profile.photo, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.profile.name, style: AppType.body(14.5, weight: 650, color: i == 0 ? c.onAccent : c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Row(children: [
                            if (p.mainTeam != null) ...[TeamCrest(team: p.mainTeam!, size: 14), const SizedBox(width: 5)],
                            Flexible(
                              child: Text(
                                '${p.mainTeam?.name ?? ''} · ${s.appearances ?? 0} apps · ${s.minutes ?? 0}\'${kind == _Leader.goals ? ' · ${s.assists ?? 0} A' : kind == _Leader.assists ? ' · ${s.goals ?? 0} G' : ''}',
                                style: AppType.body(12, color: i == 0 ? c.onAccent.withValues(alpha: 0.7) : c.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: (v / maxV).clamp(0.0, 1.0)),
                            duration: Motion.draw + Motion.staggerFor(i),
                            curve: Motion.emphasized,
                            builder: (_, t, _) => ClipRRect(borderRadius: Radii.pillAll, child: LinearProgressIndicator(value: t, minHeight: 4, backgroundColor: (i == 0 ? c.onAccent : c.surface3).withValues(alpha: 0.2), color: i == 0 ? c.onAccent : c.accent)),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Text(kind == _Leader.rating ? v.toStringAsFixed(2) : '${v.round()}', style: AppType.numeric(24, color: i == 0 ? c.onAccent : c.text)),
                    ]),
                  ),
                ).animate(delay: Motion.staggerFor(i)).fadeIn(duration: Motion.base).slideX(begin: 0.05);
              }(),
          ],
        );
      },
    );
  }
}

class _TeamStatsTab extends ConsumerWidget {
  const _TeamStatsTab({required this.leagueId});
  final int leagueId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return AsyncView(
      value: ref.watch(standingsProvider(leagueId)),
      builder: (fresh) {
        final rows = fresh.data?.groups.expand((g) => g.rows).toList() ?? const <StandingRow>[];
        if (rows.isEmpty) return ListView(children: const [EmptyState(art: EmptyArt.matches, title: 'No team statistics', message: 'Team statistics are derived from the league table, which isn\'t available.', compact: true)]);
        Widget board(String title, List<StandingRow> sorted, num Function(StandingRow) v, {String Function(num)? fmt}) {
          final top = sorted.take(5).toList();
          final maxV = top.map(v).fold<num>(0, (a, b) => a > b ? a : b);
          return Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: context.text.titleMedium),
                const SizedBox(height: 10),
                for (var i = 0; i < top.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      TeamCrest(team: top[i].team, size: 22),
                      const SizedBox(width: 10),
                      SizedBox(width: 110, child: Text(top[i].team.name, style: AppType.body(13, weight: 560, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: maxV == 0 ? 0 : v(top[i]) / maxV),
                          duration: Motion.draw + Motion.staggerFor(i),
                          curve: Motion.emphasized,
                          builder: (_, t, _) => Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: t.clamp(0.02, 1.0), child: Container(height: 10, decoration: BoxDecoration(color: i == 0 ? c.accent : c.surface3, borderRadius: Radii.pillAll)))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(fmt?.call(v(top[i])) ?? '${v(top[i])}', style: AppType.numeric(14, color: c.text)),
                    ]),
                  ),
              ]),
            ),
          );
        }

        double perGame(int v, StandingRow r) => r.played == 0 ? 0 : v / r.played;
        return ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 60),
          children: [
            board('Most goals scored', [...rows]..sort((a, b) => b.goalsFor.compareTo(a.goalsFor)), (r) => r.goalsFor),
            board('Fewest goals conceded', [...rows]..sort((a, b) => a.goalsAgainst.compareTo(b.goalsAgainst)), (r) => r.goalsAgainst),
            board('Goals per game', [...rows]..sort((a, b) => perGame(b.goalsFor, b).compareTo(perGame(a.goalsFor, a))), (r) => perGame(r.goalsFor, r), fmt: (v) => v.toStringAsFixed(2)),
            board('Most wins', [...rows]..sort((a, b) => b.win.compareTo(a.win)), (r) => r.win),
            Text('Calculated from the official league table.', style: AppType.body(11.5, color: c.textFaint)),
          ],
        );
      },
    );
  }
}
