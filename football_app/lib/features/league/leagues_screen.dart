import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/favorites.dart';
import '../../app/personalization.dart';
import '../../app/providers.dart';
import '../../core/utils/fuzzy.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../shell/app_shell.dart';

/// Leagues tab: followed competitions, popular ones, then everything the
/// provider covers grouped by country (one cached catalogue call).
class LeaguesScreen extends ConsumerStatefulWidget {
  const LeaguesScreen({super.key});
  @override
  ConsumerState<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends ConsumerState<LeaguesScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final catalog = ref.watch(leaguesCatalogProvider);
    final followed = ref.watch(followedLeagueIdsProvider);
    return Scaffold(
      body: AsyncView(
        value: catalog,
        onRetry: () => ref.invalidate(leaguesCatalogProvider),
        builder: (fresh) {
          final all = fresh.data;
          final byId = {for (final l in all) l.ref.id: l};
          final mine = followed.map((id) => byId[id]).whereType<LeagueInfo>().toList();
          final popular = popularLeagueIds.map((id) => byId[id]).whereType<LeagueInfo>().where((l) => !followed.contains(l.ref.id)).take(10).toList();
          final filtered = _q.isEmpty ? null : Fuzzy.rank(_q, all, (l) => '${l.ref.name} ${l.ref.country ?? ''}', limit: 60);
          final countries = groupBy(all, (LeagueInfo l) => l.ref.country ?? 'International');
          final countryNames = countries.keys.toList()..sort((a, b) => a == 'World' ? -1 : (b == 'World' ? 1 : a.compareTo(b)));

          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.sm),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Leagues', style: context.text.displaySmall),
                    const SizedBox(height: Space.md),
                    TextField(onChanged: (v) => setState(() => _q = v.trim()), decoration: const InputDecoration(hintText: 'Find a competition or country', prefixIcon: Icon(Icons.search_rounded))),
                  ]),
                ),
              ),
            ),
            if (filtered != null)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                sliver: SliverList.builder(itemCount: filtered.length, itemBuilder: (_, i) => _LeagueRow(league: filtered[i])),
              )
            else ...[
              if (mine.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SectionHeader('Following')),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 124,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      scrollDirection: Axis.horizontal,
                      itemCount: mine.length,
                      separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                      itemBuilder: (_, i) => _LeagueCard(league: mine[i]).animate(delay: Motion.staggerFor(i)).fadeIn().scale(begin: const Offset(0.92, 0.92), curve: Motion.spring),
                    ),
                  ),
                ),
              ],
              if (popular.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SectionHeader('Popular')),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  sliver: SliverList.builder(itemCount: popular.length, itemBuilder: (_, i) => _LeagueRow(league: popular[i]).animate(delay: Motion.staggerFor(i)).fadeIn().slideY(begin: 0.1)),
                ),
              ],
              const SliverToBoxAdapter(child: SectionHeader('All competitions')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                sliver: SliverList.builder(
                  itemCount: countryNames.length,
                  itemBuilder: (_, i) {
                    final name = countryNames[i];
                    final list = countries[name]!;
                    return Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: list.first.ref.flag == null ? Icon(Icons.public_rounded, color: c.textMuted) : LeagueLogo(league: LeagueRef(id: 0, name: name, logo: list.first.ref.flag), size: 24),
                        title: Text(name, style: AppType.body(15, weight: 600, color: c.text)),
                        trailing: Text('${list.length}', style: AppType.numeric(13, weight: 600, color: c.textFaint)),
                        children: [for (final l in list) _LeagueRow(league: l)],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: navClearance)),
          ]);
        },
      ),
    );
  }
}

class _LeagueRow extends StatelessWidget {
  const _LeagueRow({required this.league});
  final LeagueInfo league;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () => context.push('/league/${league.ref.id}'),
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          LeagueLogo(league: league.ref, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(league.ref.name, style: AppType.body(15, weight: 600, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text([league.ref.country, league.type].whereType<String>().join(' · '), style: AppType.body(12.5, color: c.textMuted)),
            ]),
          ),
          FollowButton(favorite: Favorite(kind: FavKind.league, id: league.ref.id, name: league.ref.name, image: league.ref.logo, subtitle: league.ref.country), size: 36),
        ]),
      ),
    );
  }
}

class _LeagueCard extends StatelessWidget {
  const _LeagueCard({required this.league});
  final LeagueInfo league;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () => context.push('/league/${league.ref.id}'),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: Radii.xlAll, border: Border.all(color: c.hairline)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LeagueLogo(league: league.ref, size: 34),
          const Spacer(),
          Text(league.ref.name, style: AppType.body(14, weight: 650, color: c.text), maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(league.ref.country ?? '', style: AppType.body(12, color: c.textMuted), maxLines: 1),
        ]),
      ),
    );
  }
}
