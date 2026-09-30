import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/favorites.dart';
import '../../app/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../match/widgets/match_widgets.dart';
import '../search/recent.dart';
import '../share/share_screen.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  int? _season;
  int? _league; // null = all competitions

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(playerCurrentSeasonProvider(widget.id));
    return Scaffold(
      body: AsyncView(
        value: current,
        onRetry: () => ref.invalidate(playerSeasonsProvider(widget.id)),
        loading: const _PlayerSkeleton(),
        builder: (cur) {
          final season = _season ?? cur;
          final async = ref.watch(playerProvider((widget.id, season)));
          return AsyncView(
            value: async,
            loading: const _PlayerSkeleton(),
            onRetry: () => ref.invalidate(playerProvider((widget.id, season))),
            builder: (fresh) {
              recordRecent(ref, SearchHit(kind: SearchKind.player, id: widget.id, title: fresh.data.profile.name, subtitle: fresh.data.mainTeam?.name, image: fresh.data.profile.photo));
              return _PlayerBody(
                pws: fresh.data,
                fresh: fresh,
                season: season,
                league: _league,
                onSeason: (s) => setState(() {
                  _season = s;
                  _league = null;
                }),
                onLeague: (l) => setState(() => _league = l),
              );
            },
          );
        },
      ),
    );
  }
}

class _PlayerBody extends ConsumerWidget {
  const _PlayerBody({required this.pws, required this.fresh, required this.season, required this.league, required this.onSeason, required this.onLeague});
  final PlayerWithSeasons pws;
  final Fresh<PlayerWithSeasons> fresh;
  final int season;
  final int? league;
  final ValueChanged<int> onSeason;
  final ValueChanged<int?> onLeague;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final p = pws.profile;
    final team = pws.mainTeam;
    final seasons = ref.watch(playerSeasonsProvider(p.id)).value ?? [season];
    final lines = league == null ? pws.seasons : pws.seasons.where((s) => s.league.id == league).toList();
    final stats = PlayerStatLine.sum(lines.map((s) => s.stats));
    final top = MediaQuery.paddingOf(context).top;

    final sections = <Widget>[
      _SeasonPicker(seasons: seasons.reversed.toList(), season: season, onSeason: onSeason),
      if (pws.seasons.length > 1)
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: Space.gutter), children: [
            ChoiceChipPill(label: 'All competitions', selected: league == null, onTap: () => onLeague(null)),
            for (final l in {for (final s in pws.seasons) s.league.id: s.league}.values) ...[const SizedBox(width: 8), ChoiceChipPill(label: l.name, selected: league == l.id, onTap: () => onLeague(l.id), leading: LeagueLogo(league: l, size: 18))],
          ]),
        ),
      FreshnessBanner(fresh: fresh),
      SectionHeader(season == (seasons.isEmpty ? season : seasons.last) ? 'Current season' : 'Season ${seasonLabel(season)}'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: Space.gutter), child: _SeasonStats(stats: stats, group: p.group, provider: ref.watch(repositoryProvider).providerName)),
      const SectionHeader('Last 5 matches'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: Space.gutter), child: _RecentForm(playerId: p.id)),
      const SectionHeader('Career'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: Space.gutter), child: _Career(playerId: p.id)),
      const SectionHeader('Transfers'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: Space.gutter), child: _Transfers(playerId: p.id)),
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0),
        child: Row(children: [
          Expanded(child: PillButton(label: 'Compare', icon: Icons.compare_arrows_rounded, onTap: () => context.push('/compare?a=${p.id}'))),
          const SizedBox(width: 10),
          Expanded(child: PillButton(label: 'Player card', primary: false, icon: Icons.ios_share_rounded, onTap: () => context.push('/share', extra: ShareRequest.player(p.id, season)))),
        ]),
      ),
    ];

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Stack(children: [
          // Big faint shirt number behind the header (editorial touch).
          if (p.number != null)
            Positioned(
              right: -10,
              top: top + 30,
              child: Text('${p.number}', style: AppType.display(170, weight: 900, width: 125, color: c.text.withValues(alpha: 0.05), spacing: -8)).animate().fadeIn(duration: Motion.slow).slideX(begin: 0.1),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(Space.gutter, top + 8, Space.gutter, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => context.canPop() ? context.pop() : context.go('/home')),
                const Spacer(),
                FollowButton(favorite: Favorite(kind: FavKind.player, id: p.id, name: p.name, image: p.photo, subtitle: team?.name, teamId: team?.id)),
              ]),
              const SizedBox(height: Space.lg),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                PlayerAvatar(name: p.name, photo: p.photo, size: 92, ring: c.accent, heroTag: 'player-${p.id}'),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (p.firstname != null && p.lastname != null) ...[
                      Text(p.firstname!, style: AppType.body(15, weight: 500, color: c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(p.lastname!.toUpperCase(), style: AppType.display(30, color: c.text), maxLines: 2),
                    ] else
                      Text(p.name.toUpperCase(), style: AppType.display(28, color: c.text), maxLines: 2),
                  ]).animate().fadeIn(duration: Motion.slow).slideX(begin: 0.06, curve: Motion.emphasized),
                ),
              ]),
              const SizedBox(height: Space.md),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (team != null)
                  Pressable(
                    onTap: () => context.push('/team/${team.id}'),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                      decoration: BoxDecoration(color: c.surface2, borderRadius: Radii.pillAll),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [TeamCrest(team: team, size: 20), const SizedBox(width: 6), Text(team.name, style: AppType.body(13, weight: 600, color: c.text))]),
                    ),
                  ),
                for (final t in [
                  if (p.position != null) positionGroupOf(p.position).label,
                  if (p.number != null) '#${p.number}',
                  if (p.age != null) '${p.age} yrs',
                  ?p.nationality,
                  ?p.height,
                ])
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: c.surface2, borderRadius: Radii.pillAll), child: Text(t, style: AppType.body(13, weight: 550, color: c.text))),
              ]),
              if (p.injured == true) Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [Icon(Icons.healing_rounded, size: 16, color: c.reported), const SizedBox(width: 6), Text('Currently injured (provider report)', style: AppType.body(13, color: c.reported))])),
            ]),
          ),
        ]),
      ),
      SliverList.list(children: [for (var i = 0; i < sections.length; i++) sections[i].animate(delay: Motion.staggerFor(i)).fadeIn(duration: Motion.base).slideY(begin: 0.05)]),
      const SliverToBoxAdapter(child: SizedBox(height: 60)),
    ]);
  }
}

class _SeasonPicker extends StatelessWidget {
  const _SeasonPicker({required this.seasons, required this.season, required this.onSeason});
  final List<int> seasons;
  final int season;
  final ValueChanged<int> onSeason;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
          itemCount: seasons.length.clamp(0, 8),
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ChoiceChipPill(label: seasonLabel(seasons[i]), selected: seasons[i] == season, onTap: () => onSeason(seasons[i])),
        ),
      );
}

/// Position-adaptive season statistics (spec §13).
class _SeasonStats extends StatelessWidget {
  const _SeasonStats({required this.stats, required this.group, required this.provider});
  final PlayerStatLine stats;
  final PositionGroup group;
  final String provider;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    String n(num? v, {int d = 0}) => v == null ? '—' : (d == 0 ? '${v.round()}' : v.toStringAsFixed(d));
    final tiles = <(String, String?, bool)>[
      ('Apps', s.appearances == null ? null : n(s.appearances), false),
      ('Minutes', s.minutes == null ? null : n(s.minutes), false),
      ('Rating', s.rating == null ? null : n(s.rating, d: 2), true),
      ...switch (group) {
        PositionGroup.goalkeeper => [
            ('Clean sheets', s.cleanSheets == null ? null : n(s.cleanSheets), false),
            ('Saves', s.saves == null ? null : n(s.saves), false),
            ('Conceded', s.conceded == null ? null : n(s.conceded), false),
            ('Pass accuracy', s.passAccuracy == null ? null : '${s.passAccuracy!.round()}%', false),
          ],
        PositionGroup.defender => [
            ('Tackles', s.tackles == null ? null : n(s.tackles), false),
            ('Interceptions', s.interceptions == null ? null : n(s.interceptions), false),
            ('Duels won', s.duelsWon == null ? null : '${s.duelsWon}/${s.duels ?? '—'}', false),
            ('Pass accuracy', s.passAccuracy == null ? null : '${s.passAccuracy!.round()}%', false),
            ('Goals', s.goals == null ? null : n(s.goals), false),
            ('Assists', s.assists == null ? null : n(s.assists), false),
          ],
        PositionGroup.midfielder => [
            ('Goals', s.goals == null ? null : n(s.goals), false),
            ('Assists', s.assists == null ? null : n(s.assists), false),
            ('Key passes', s.keyPasses == null ? null : n(s.keyPasses), false),
            ('Pass accuracy', s.passAccuracy == null ? null : '${s.passAccuracy!.round()}%', false),
            ('Dribbles', s.dribblesWon == null ? null : '${s.dribblesWon}/${s.dribbles ?? '—'}', false),
            ('Tackles', s.tackles == null ? null : n(s.tackles), false),
            ('xA', s.xa == null ? null : n(s.xa, d: 2), false),
          ],
        _ => [
            ('Goals', s.goals == null ? null : n(s.goals), false),
            ('Assists', s.assists == null ? null : n(s.assists), false),
            ('Shots (on target)', s.shots == null ? null : '${s.shots} (${s.shotsOn ?? '—'})', false),
            ('xG', s.xg == null ? null : n(s.xg, d: 2), false),
            ('Key passes', s.keyPasses == null ? null : n(s.keyPasses), false),
            ('Dribbles', s.dribblesWon == null ? null : '${s.dribblesWon}/${s.dribbles ?? '—'}', false),
            ('xA', s.xa == null ? null : n(s.xa, d: 2), false),
          ],
      },
      ('Duels', group == PositionGroup.defender || s.duels == null ? null : '${s.duelsWon ?? '—'}/${s.duels}', false),
      ('Cards', s.yellow == null && s.red == null ? null : '${s.yellow ?? 0}Y · ${s.red ?? 0}R', false),
    ];
    final avail = tiles.where((t) => t.$2 != null).toList();
    final missing = tiles.where((t) => t.$2 == null && t.$1 != 'Duels').map((t) => t.$1).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      StatGrid(tiles: [for (final t in avail) StatTile(label: t.$1, value: t.$2!, highlight: t.$3)]),
      if (missing.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: NotProvided(missing.join(', '), provider: provider)),
    ]);
  }
}

/// Last 5 ratings as animated bars; tap for that match's performance.
class _RecentForm extends ConsumerWidget {
  const _RecentForm({required this.playerId});
  final int playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(playerRecentProvider((playerId, 5)));
    return switch (async) {
      AsyncValue(:final value?) when value.isEmpty => Text('No recent appearances on record.', style: AppType.body(14, color: c.textMuted)),
      AsyncValue(:final value?) => AppCard(
          child: SizedBox(
            height: 170,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < value.length; i++)
                Expanded(
                  child: Pressable(
                    onTap: () => showPerformanceSheet(context, value[i].match, value[i].line),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(value[i].line.stats.rating?.toStringAsFixed(1) ?? '—', style: AppType.numeric(14, color: c.text)),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: ((value[i].line.stats.rating ?? 5) - 5).clamp(0.3, 5) / 5),
                        duration: Motion.draw + Motion.staggerFor(i) * 2,
                        curve: Motion.emphasized,
                        builder: (_, t, _) => Container(
                          height: 90 * t,
                          width: 26,
                          decoration: BoxDecoration(
                            color: value[i].line.stats.rating == null ? c.surface3 : RatingBadge.colorFor(value[i].line.stats.rating!, c),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TeamCrest(team: value[i].match.isHome(value[i].line.teamId) ? value[i].match.away : value[i].match.home, size: 20),
                      const SizedBox(height: 2),
                      Text(shortDate(value[i].match.kickoff), style: AppType.body(10.5, color: c.textFaint)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      AsyncValue(:final error?) => ErrorState(error: error, compact: true),
      _ => const Skeleton(height: 170, radius: Radii.xl),
    };
  }
}

class _Career extends ConsumerWidget {
  const _Career({required this.playerId});
  final int playerId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(playerCareerProvider(playerId));
    return switch (async) {
      AsyncValue(:final value?) when value.data.isEmpty => Text('No career history from the provider.', style: AppType.body(14, color: c.textMuted)),
      AsyncValue(:final value?) => Column(children: [
          for (final e in value.data.where((e) => !e.isNational)) _CareerRow(entry: e, playerId: playerId),
          if (value.data.any((e) => e.isNational)) ...[
            Padding(padding: const EdgeInsets.only(top: Space.md, bottom: 6), child: Align(alignment: Alignment.centerLeft, child: Overline('International'))),
            for (final e in value.data.where((e) => e.isNational)) _CareerRow(entry: e, playerId: playerId),
          ],
        ]),
      AsyncValue(:final error?) => ErrorState(error: error, compact: true),
      _ => const Skeleton(height: 120, radius: Radii.xl),
    };
  }
}

class _CareerRow extends ConsumerStatefulWidget {
  const _CareerRow({required this.entry, required this.playerId});
  final CareerEntry entry;
  final int playerId;
  @override
  ConsumerState<_CareerRow> createState() => _CareerRowState();
}

class _CareerRowState extends ConsumerState<_CareerRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = widget.entry;
    final range = e.seasons.isEmpty ? '' : (e.seasons.length == 1 ? seasonLabel(e.seasons.first) : '${e.seasons.last}–${e.seasons.first + 1}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () => setState(() => _open = !_open),
        child: Column(children: [
          Row(children: [
            TeamCrest(team: e.team, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.team.name, style: context.text.titleSmall),
                Text('$range · ${e.seasons.length} season${e.seasons.length == 1 ? '' : 's'}', style: AppType.body(12.5, color: c.textMuted)),
              ]),
            ),
            AnimatedRotation(turns: _open ? 0.5 : 0, duration: Motion.base, child: Icon(Icons.expand_more_rounded, color: c.textMuted)),
          ]),
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.emphasized,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(children: [for (final s in e.seasons.take(6)) _SeasonLine(playerId: widget.playerId, season: s, teamId: e.team.id)]),
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Lazily loads one season's stats for the career list.
class _SeasonLine extends ConsumerWidget {
  const _SeasonLine({required this.playerId, required this.season, required this.teamId});
  final int playerId;
  final int season;
  final int teamId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(playerProvider((playerId, season)));
    final lines = async.value?.data.seasons.where((s) => s.team.id == teamId).toList() ?? const [];
    final s = PlayerStatLine.sum(lines.map((l) => l.stats));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: 64, child: Text(seasonLabel(season), style: AppType.numeric(13, weight: 650, color: c.text))),
        Expanded(
          child: async.isLoading
              ? const Skeleton(height: 12)
              : Text(
                  lines.isEmpty ? 'No stats' : '${s.appearances ?? 0} apps · ${s.goals ?? 0} G · ${s.assists ?? 0} A${lines.map((l) => l.league.name).toSet().length > 1 ? ' · ${lines.map((l) => l.league.name).toSet().length} competitions' : ''}',
                  style: AppType.body(12.5, color: c.textMuted),
                ),
        ),
        if (s.rating != null) RatingBadge(rating: s.rating, size: 11),
      ]),
    );
  }
}

class _Transfers extends ConsumerWidget {
  const _Transfers({required this.playerId});
  final int playerId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(playerTransfersProvider(playerId));
    return switch (async) {
      AsyncValue(:final value?) when value.data.isEmpty => Text('No transfers on record.', style: AppType.body(14, color: c.textMuted)),
      AsyncValue(:final value?) => Column(children: [for (final t in value.data.take(6)) TransferTile(transfer: t, showPlayer: false)]),
      AsyncValue(:final error?) => ErrorState(error: error, compact: true),
      _ => const Skeleton(height: 80, radius: Radii.xl),
    };
  }
}

/// Transfer row shared by player, team and Transfers screens.
class TransferTile extends StatelessWidget {
  const TransferTile({super.key, required this.transfer, this.showPlayer = true});
  final Transfer transfer;
  final bool showPlayer;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = transfer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: showPlayer ? () => context.push('/player/${t.player.id}') : null,
        child: Row(children: [
          if (showPlayer) ...[PlayerAvatar(name: t.player.name, photo: t.player.photo, size: 38), const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (showPlayer) Text(t.player.name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                TeamCrest(team: t.from, size: 18),
                const SizedBox(width: 6),
                Flexible(child: Text(t.from.name, style: AppType.body(12.5, color: c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward_rounded, size: 14, color: c.accentInk)),
                TeamCrest(team: t.to, size: 18),
                const SizedBox(width: 6),
                Flexible(child: Text(t.to.name, style: AppType.body(12.5, weight: 650, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (t.fee != null) Text(t.fee!, style: AppType.numeric(13, weight: 700, color: c.text)),
            if (t.date != null) Text(shortDate(t.date!) + (t.date!.year != DateTime.now().year ? ' ${t.date!.year}' : ''), style: AppType.body(11.5, color: c.textFaint)),
          ]),
        ]),
      ),
    );
  }
}

class _PlayerSkeleton extends StatelessWidget {
  const _PlayerSkeleton();
  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 60),
            const Row(children: [Skeleton(height: 92, width: 92, radius: 46), SizedBox(width: 16), Expanded(child: Skeleton(height: 40))]),
            const SizedBox(height: Space.xl),
            for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: Skeleton(height: 96, radius: Radii.lg)),
          ]),
        ),
      );
}
