import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/favorites.dart';
import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../domain/catch_up.dart';
import '../../domain/match_diff.dart';
import '../share/share_screen.dart';
import 'tabs/commentary_tab.dart';
import 'tabs/h2h_tab.dart';
import 'tabs/lineups_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/pitch_tab.dart';
import 'tabs/players_tab.dart';
import 'tabs/stats_tab.dart';
import 'widgets/goal_celebration.dart';

const matchTabs = ['Overview', 'Commentary', 'Stats', 'Lineups', 'Pitch', 'Players', 'H2H'];

class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({super.key, required this.id, this.heroScope = 'x', this.initialTab});
  final int id;
  final String heroScope;
  final String? initialTab;

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: matchTabs.length,
    vsync: this,
    initialIndex: (matchTabs.indexWhere((t) => t.toLowerCase() == widget.initialTab)).clamp(0, matchTabs.length - 1),
  );
  SeenSnapshot? _seenAtOpen;
  bool _catchUpDismissed = false;
  MatchEvent? _celebrateEvent;
  int? _celebrateTeam;

  @override
  void initState() {
    super.initState();
    _seenAtOpen = SeenSnapshot.fromJson(ref.read(localStoreProvider).readMap('seen:${widget.id}'));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _onUpdate(Fresh<Match>? prev, Fresh<Match> next) {
    final m = next.data;
    // Remember what the user has seen (drives "What just happened?").
    if (m.status.isLive || m.status.isFinished) ref.read(localStoreProvider).write('seen:${m.id}', SeenSnapshot.of(m).toJson());
    final side = scoringSide(prev?.data, m);
    if (side != null && !next.stale) {
      final goal = m.goals.where((g) => g.teamId == side || g.kind == EventKind.ownGoal).lastOrNull;
      setState(() {
        _celebrateTeam = side;
        _celebrateEvent = goal;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(matchProvider(widget.id));
    ref.listen(matchProvider(widget.id), (prev, next) {
      final v = next.value;
      if (v != null) _onUpdate(prev?.value, v);
    });

    return Scaffold(
      body: Stack(children: [
        AsyncView(
          value: async,
          onRetry: () => ref.invalidate(matchProvider(widget.id)),
          loading: const _MatchSkeleton(),
          builder: (fresh) => _MatchBody(
            fresh: fresh,
            tabs: _tabs,
            heroScope: widget.heroScope,
            seenAtOpen: _seenAtOpen,
            catchUpDismissed: _catchUpDismissed,
            onDismissCatchUp: () => setState(() => _catchUpDismissed = true),
          ),
        ),
        if (_celebrateTeam != null && async.value != null)
          Positioned.fill(
            child: GoalCelebration(
              key: ValueKey('${_celebrateTeam}_${async.value!.data.homeGoals}_${async.value!.data.awayGoals}'),
              team: async.value!.data.teamById(_celebrateTeam!) ?? async.value!.data.home,
              scorer: _celebrateEvent?.playerName,
              minute: _celebrateEvent?.minuteLabel ?? async.value!.data.status.minuteLabel,
              score: '${async.value!.data.home.short} ${async.value!.data.homeGoals}–${async.value!.data.awayGoals} ${async.value!.data.away.short}',
              onDone: () => setState(() => _celebrateTeam = null),
            ),
          ),
      ]),
    );
  }
}

class _MatchBody extends ConsumerWidget {
  const _MatchBody({required this.fresh, required this.tabs, required this.heroScope, required this.seenAtOpen, required this.catchUpDismissed, required this.onDismissCatchUp});
  final Fresh<Match> fresh;
  final TabController tabs;
  final String heroScope;
  final SeenSnapshot? seenAtOpen;
  final bool catchUpDismissed;
  final VoidCallback onDismissCatchUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final m = fresh.data;
    final top = MediaQuery.paddingOf(context).top;
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverPersistentHeader(pinned: true, delegate: _HeaderDelegate(match: m, top: top, heroScope: heroScope, colors: c, fresh: fresh)),
        SliverPersistentHeader(pinned: true, delegate: _TabsDelegate(tabs: tabs, color: c.bg)),
      ],
      body: TabBarView(controller: tabs, children: [
        OverviewTab(match: m, fresh: fresh, seen: seenAtOpen, catchUpDismissed: catchUpDismissed, onDismissCatchUp: onDismissCatchUp, openTab: (i) => tabs.animateTo(i)),
        CommentaryTab(match: m),
        StatsTab(match: m),
        LineupsTab(match: m),
        PitchTab(match: m),
        PlayersTab(match: m),
        H2HTab(match: m),
      ]),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: color, padding: const EdgeInsets.only(top: 2, bottom: 2), child: PillTabBar(controller: tabs, tabs: matchTabs));
  @override
  bool shouldRebuild(_TabsDelegate old) => old.color != color || old.tabs != tabs;
}

/// Collapsing score header: big crests/score when expanded, a compact score
/// bar when pinned.
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({required this.match, required this.top, required this.heroScope, required this.colors, required this.fresh});
  final Match match;
  final double top;
  final String heroScope;
  final AppColors colors;
  final Fresh<Match> fresh;

  @override
  double get minExtent => top + 64;
  @override
  double get maxExtent => top + 64 + 196 + (fresh.stale ? 40 : 0);

  @override
  bool shouldRebuild(_HeaderDelegate old) => old.match != match || old.colors != colors || old.fresh != fresh;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final c = colors;
    final m = match;
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final live = m.status.isLive;
    final scoreStyle = AppType.numeric(56, color: c.text);

    Widget teamCol(TeamRef team) => Expanded(
          child: Pressable(
            onTap: () => context.push('/team/${team.id}'),
            child: Column(children: [
              TeamCrest(team: team, size: 64, heroTag: crestHero(heroScope, m.id, team.id)),
              const SizedBox(height: 10),
              Text(team.name, style: AppType.body(14.5, weight: 650, color: c.text), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        );

    Widget scorers(int teamId, CrossAxisAlignment align) => Expanded(
          child: Column(crossAxisAlignment: align, children: [
            for (final g in m.goals.where((g) => g.teamId == teamId))
              Text("${pitchName(g.playerName ?? '')} ${g.minuteLabel}${g.kind == EventKind.penaltyGoal ? ' (P)' : g.kind == EventKind.ownGoal ? ' (OG)' : ''}",
                  style: AppType.body(12, color: c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        );

    final status = live
        ? LiveBadge(label: m.status.minuteLabel)
        : Text(
            m.status.isScheduled ? '${dayLabel(m.kickoff)} · ${kickoffTime(m.kickoff)}' : m.status.minuteLabel,
            style: AppType.numeric(13.5, weight: 700, color: m.status.isScheduled ? c.accentInk : c.textMuted),
          );

    return Container(
      color: c.bg,
      child: Stack(children: [
        // Subtle glow behind the score while live.
        if (live)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: (1 - t) * 0.9,
                child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -0.2), radius: 0.9, colors: [c.accent.withValues(alpha: 0.10), Colors.transparent]))),
              ),
            ),
          ),
        // Expanded content.
        Positioned(
          left: 0,
          right: 0,
          top: top + 60,
          child: Opacity(
            opacity: (1 - t * 1.8).clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, -30 * t),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Column(children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    teamCol(m.home),
                    Column(children: [
                      const SizedBox(height: 4),
                      Row(children: [
                        ScoreNumber(value: m.status.isScheduled ? null : m.homeGoals, style: scoreStyle),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('–', style: scoreStyle.copyWith(color: c.textFaint, fontSize: 40))),
                        ScoreNumber(value: m.status.isScheduled ? null : m.awayGoals, style: scoreStyle),
                      ]),
                      const SizedBox(height: 8),
                      status,
                      if (m.penalties.isSet) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Pens ${m.penalties.home}–${m.penalties.away}', style: AppType.body(12, color: c.textMuted))),
                    ]),
                    teamCol(m.away),
                  ]),
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [scorers(m.home.id, CrossAxisAlignment.center), const SizedBox(width: 90), scorers(m.away.id, CrossAxisAlignment.center)]),
                  if (fresh.stale) FreshnessBanner(fresh: fresh, padding: const EdgeInsets.only(top: 8)),
                ]),
              ),
            ),
          ),
        ),
        // Top bar (always visible). Compact score fades in when collapsed.
        Positioned(
          left: 0,
          right: 0,
          top: top,
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              CircleIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => context.canPop() ? context.pop() : context.go('/home')),
              Expanded(
                child: Stack(alignment: Alignment.center, children: [
                  Opacity(
                    opacity: (1 - t * 2).clamp(0, 1),
                    child: Pressable(
                      onTap: () => context.push('/league/${m.league.id}'),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(m.league.name.toUpperCase(), style: AppType.overline(color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (m.league.round != null) Text(m.league.round!.replaceAll('Regular Season - ', 'Matchday '), style: AppType.body(11.5, color: c.textFaint), maxLines: 1),
                      ]),
                    ),
                  ),
                  Opacity(
                    opacity: ((t - 0.5) * 2).clamp(0, 1),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      TeamCrest(team: m.home, size: 24),
                      const SizedBox(width: 8),
                      Text(m.status.isScheduled ? kickoffTime(m.kickoff) : '${m.homeGoals}–${m.awayGoals}', style: AppType.numeric(20, color: c.text)),
                      const SizedBox(width: 8),
                      TeamCrest(team: m.away, size: 24),
                      if (live) ...[const SizedBox(width: 8), Text(m.status.minuteLabel, style: AppType.numeric(12.5, weight: 700, color: c.live))],
                    ]),
                  ),
                ]),
              ),
              CircleIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: 'Share',
                onTap: () => context.push('/share', extra: ShareRequest.match(m.id, moment: m.status.isLive && m.goals.isNotEmpty)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _MatchSkeleton extends StatelessWidget {
  const _MatchSkeleton();
  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Column(children: [
            const SizedBox(height: 60),
            const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Skeleton(height: 64, width: 64, radius: 32), Skeleton(height: 50, width: 110), Skeleton(height: 64, width: 64, radius: 32)]),
            const SizedBox(height: Space.xxl),
            const Skeleton(height: 36, radius: Radii.pill),
            const SizedBox(height: Space.lg),
            for (var i = 0; i < 4; i++) const Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 70, radius: Radii.lg)),
          ]),
        ),
      );
}

/// Follow shortcut used by match sub-screens.
Favorite teamFavorite(TeamRef t, {String? subtitle}) => Favorite(kind: FavKind.team, id: t.id, name: t.name, image: t.logo, subtitle: subtitle);

/// Notification categories quick-check (used by Overview to hint alerts).
bool alertsOnFor(WidgetRef ref, Match m) {
  final favs = ref.watch(activeFavoritesProvider);
  final s = ref.watch(settingsProvider);
  return s.notificationsEnabled && favs.any((f) => f.kind == FavKind.team && m.involves(f.id));
}
