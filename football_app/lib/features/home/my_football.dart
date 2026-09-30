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
import 'home_screen.dart';

/// "MY FOOTBALL" (spec §3, §35): followed teams, players and competitions,
/// each with a one-line live/next/last status.
class MyFootballSection extends ConsumerWidget {
  const MyFootballSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(activeFavoritesProvider);
    final ordered = [...favs.where((f) => f.kind == FavKind.team), ...favs.where((f) => f.kind == FavKind.player), ...favs.where((f) => f.kind == FavKind.league)];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader('My football', action: favs.isEmpty ? null : 'Manage', onAction: () => context.push('/settings/teams')),
      if (favs.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: AppCard(
            onTap: () => context.go('/search'),
            child: Row(children: [
              ClipRRect(borderRadius: Radii.mdAll, child: const SizedBox.square(dimension: 64, child: ArtImage('assets/images/empty_favorites.jpg'))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Make it yours', style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Text('Follow teams, players and competitions to personalise Home, ordering and alerts.', style: AppType.body(13, color: context.colors.textMuted)),
                ]),
              ),
              Icon(Icons.add_circle_rounded, color: context.colors.accentInk, size: 30),
            ]),
          ),
        )
      else
        SizedBox(
          height: 142,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            scrollDirection: Axis.horizontal,
            itemCount: ordered.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
            itemBuilder: (context, i) {
              final f = ordered[i];
              final tile = switch (f.kind) {
                FavKind.team => _TeamTile(fav: f),
                FavKind.player => _PlayerTile(fav: f),
                FavKind.league => _LeagueTile(fav: f),
              };
              return tile.animate(delay: Motion.staggerFor(i)).fadeIn(duration: Motion.base).scale(begin: const Offset(0.94, 0.94), curve: Motion.spring, duration: Motion.slow);
            },
          ),
        ),
    ]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.leading, required this.title, required this.line, required this.onTap, this.live = false, this.sub});
  final Widget leading;
  final String title;
  final Widget line;
  final String? sub;
  final VoidCallback onTap;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 172,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: Radii.xlAll, border: Border.all(color: live ? c.live.withValues(alpha: 0.4) : c.hairline)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          leading,
          const Spacer(),
          Text(title, style: AppType.body(14.5, weight: 650, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          line,
          if (sub != null) Text(sub!, style: AppType.body(11.5, color: c.textFaint), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _TeamTile extends ConsumerWidget {
  const _TeamTile({required this.fav});
  final Favorite fav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final team = TeamRef(id: fav.id, name: fav.name, logo: fav.image);
    final live = ref.watch(liveMatchesProvider).value?.data.where((m) => m.involves(fav.id)).firstOrNull;
    final ms = ref.watch(teamMatchesProvider(fav.id));
    Widget line;
    String? sub;
    if (live != null) {
      final mine = live.isHome(fav.id) ? live.homeGoals : live.awayGoals;
      final theirs = live.isHome(fav.id) ? live.awayGoals : live.homeGoals;
      line = Row(children: [
        LiveDot(size: 5, color: c.live),
        Text('LIVE — $mine:$theirs', style: AppType.numeric(13, weight: 700, color: c.live)),
        Text('  ${live.status.minuteLabel}', style: AppType.body(12, color: c.textMuted)),
      ]);
      sub = 'vs ${(live.isHome(fav.id) ? live.away : live.home).name}';
    } else if (ms.value != null) {
      final list = ms.value!.data;
      final next = list.where((m) => m.status.isScheduled && m.kickoff.isAfter(DateTime.now())).firstOrNull;
      final form = recentForm(list, fav.id, count: 5);
      if (next != null) {
        line = Text('${dayLabel(next.kickoff)} ${kickoffTime(next.kickoff)}', style: AppType.numeric(13, weight: 650, color: c.accentInk));
        sub = 'vs ${(next.isHome(fav.id) ? next.away : next.home).name}';
      } else if (form.isNotEmpty) {
        final last = form.last.match;
        line = Text('${form.last.result.letter} ${last.homeGoals}–${last.awayGoals}', style: AppType.numeric(13, weight: 700, color: c.text));
        sub = 'vs ${(last.isHome(fav.id) ? last.away : last.home).name}';
      } else {
        line = Text('No fixtures listed', style: AppType.body(12.5, color: c.textMuted));
      }
      if (form.isNotEmpty && next != null) sub = '$sub · ${form.map((e) => e.result.letter).join(' ')}';
    } else if (ms.hasError) {
      line = Text('Unavailable', style: AppType.body(12.5, color: c.textMuted));
    } else {
      line = const Skeleton(height: 12, width: 90);
    }
    return _Tile(leading: TeamCrest(team: team, size: 36), title: fav.name, line: line, sub: sub, live: live != null, onTap: () => openFavorite(context, fav));
  }
}

class _PlayerTile extends ConsumerWidget {
  const _PlayerTile({required this.fav});
  final Favorite fav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    // Live: count goals/assists from the live event feed (no extra calls).
    final live = fav.teamId == null ? null : ref.watch(liveMatchesProvider).value?.data.where((m) => m.involves(fav.teamId!)).firstOrNull;
    Widget line;
    String? sub;
    if (live != null && live.events != null) {
      final g = live.events!.where((e) => e.isGoal && e.kind != EventKind.ownGoal && e.playerId == fav.id).length;
      final a = live.events!.where((e) => e.kind == EventKind.goal && e.relatedId == fav.id).length;
      line = Row(children: [LiveDot(size: 5, color: c.live), Flexible(child: Text('$g goal${g == 1 ? '' : 's'} · $a assist${a == 1 ? '' : 's'}', style: AppType.body(12.5, weight: 650, color: c.text)))]);
      sub = "${live.home.short} ${live.homeGoals}–${live.awayGoals} ${live.away.short} · ${live.status.minuteLabel}";
    } else {
      final recent = ref.watch(playerRecentProvider((fav.id, 1)));
      final e = recent.value?.firstOrNull;
      if (e != null) {
        final s = e.line.stats;
        final parts = <String>[
          if ((s.goals ?? 0) > 0) '${s.goals} goal${s.goals == 1 ? '' : 's'}',
          if ((s.assists ?? 0) > 0) '${s.assists} assist${s.assists == 1 ? '' : 's'}',
          if ((s.goals ?? 0) == 0 && (s.assists ?? 0) == 0) '${s.minutes ?? 0} min',
        ];
        line = Row(children: [
          Flexible(child: Text(parts.join(' · '), style: AppType.body(12.5, weight: 600, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (s.rating != null) ...[const SizedBox(width: 6), RatingBadge(rating: s.rating, size: 10.5)],
        ]);
        sub = 'Last: ${e.match.home.short} ${e.match.homeGoals}–${e.match.awayGoals} ${e.match.away.short}';
      } else if (recent.isLoading) {
        line = const Skeleton(height: 12, width: 90);
      } else {
        line = Text(fav.subtitle ?? 'Player', style: AppType.body(12.5, color: c.textMuted), maxLines: 1);
      }
    }
    return _Tile(leading: PlayerAvatar(name: fav.name, photo: fav.image, size: 36), title: fav.name, line: line, sub: sub, live: live != null, onTap: () => openFavorite(context, fav));
  }
}

class _LeagueTile extends ConsumerWidget {
  const _LeagueTile({required this.fav});
  final Favorite fav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final table = ref.watch(standingsProvider(fav.id));
    final today = ref.watch(dayMatchesProvider(dateOnly(DateTime.now()))).value?.data.where((m) => m.league.id == fav.id).toList() ?? const [];
    final round = today.map((m) => m.league.round).whereType<String>().firstOrNull;
    final md = round == null ? null : RegExp(r'(\d+)$').firstMatch(round)?.group(1);
    Widget line;
    String? sub;
    final rows = table.value?.data?.groups.firstOrNull?.rows;
    if (md != null) {
      line = Text('Matchday $md', style: AppType.body(12.5, weight: 650, color: c.accentInk));
    } else if (rows != null && rows.isNotEmpty) {
      line = Text('After ${rows.map((r) => r.played).fold(0, (a, b) => a > b ? a : b)} games', style: AppType.body(12.5, weight: 600, color: c.text));
    } else {
      line = Text(fav.subtitle ?? 'Competition', style: AppType.body(12.5, color: c.textMuted));
    }
    if (rows != null && rows.isNotEmpty) sub = 'Leader: ${rows.first.team.name}';
    return _Tile(
      leading: LeagueLogo(league: LeagueRef(id: fav.id, name: fav.name, logo: fav.image), size: 36),
      title: fav.name,
      line: line,
      sub: sub,
      live: today.any((m) => m.status.isLive),
      onTap: () => openFavorite(context, fav),
    );
  }
}
