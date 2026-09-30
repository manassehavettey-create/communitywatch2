import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/favorites.dart';
import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/utils/format.dart';
import '../../core/utils/fuzzy.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../shell/app_shell.dart';
import 'recent.dart';

/// Remote search (teams + players), typo-tolerant: if the provider finds
/// nothing for the exact text, retry with a shorter prefix and rank the
/// results locally with fuzzy matching (e.g. "mbape" → "Mbappé").
final remoteSearchProvider = FutureProvider.autoDispose.family<List<SearchHit>, String>((ref, q) async {
  final repo = ref.watch(repositoryProvider);
  Future<List<SearchHit>> run(String text) async {
    final r = await Future.wait([repo.searchTeams(text), repo.searchPlayers(text)]);
    return [...r[0].data, ...r[1].data];
  }

  var hits = await run(q);
  if (hits.isEmpty && q.length >= 5 && !repo.isDemo) {
    hits = await run(q.substring(0, 4));
  }
  return [for (final h in hits) h.withScore(Fuzzy.score(q, h.title))].where((h) => h.score > 0.3 || repo.isDemo).toList()
    ..sort((a, b) => b.score.compareTo(a.score));
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _q = '';
  String _remoteQ = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _q = v.trim());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _remoteQ = _q.length >= 3 ? _q : '');
    });
  }

  void _open(SearchHit h) {
    final s = ref.read(localStoreProvider);
    if (_q.isNotEmpty) {
      final qs = [_q, ...(s.readList('recent_queries') ?? const []).map((e) => '$e').where((e) => e.toLowerCase() != _q.toLowerCase())].take(8).toList();
      s.write('recent_queries', qs);
    }
    recordRecent(ref, h);
    context.push(switch (h.kind) { SearchKind.player => '/player/${h.id}', SearchKind.team => '/team/${h.id}', SearchKind.league => '/league/${h.id}', SearchKind.match => '/match/${h.id}?h=search' });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Search', style: context.text.displaySmall),
              const SizedBox(height: Space.md),
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Players, teams, competitions, matches',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _q.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _ctrl.clear();
                            _onChanged('');
                          },
                        ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.base,
              child: _q.isEmpty ? _Suggestions(key: const ValueKey('s'), onOpen: _open, onQuery: (q) {
                _ctrl.text = q;
                _onChanged(q);
                setState(() => _remoteQ = q.length >= 3 ? q : '');
              }) : _Results(key: const ValueKey('r'), q: _q, remoteQ: _remoteQ, onOpen: _open),
            ),
          ),
        ]),
      ),
      backgroundColor: c.bg,
    );
  }
}

class _Suggestions extends ConsumerWidget {
  const _Suggestions({super.key, required this.onOpen, required this.onQuery});
  final ValueChanged<SearchHit> onOpen;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final recent = ref.watch(recentProvider);
    final queries = (ref.watch(localStoreProvider).readList('recent_queries') ?? const []).map((e) => '$e').toList();
    final favs = ref.watch(activeFavoritesProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, navClearance),
      children: [
        if (queries.isNotEmpty) ...[
          const SectionHeader('Recent searches', padding: EdgeInsets.only(top: Space.md, bottom: Space.sm)),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final q in queries) ChoiceChipPill(label: q, selected: false, onTap: () => onQuery(q), leading: Icon(Icons.history_rounded, size: 16, color: c.textMuted))]),
        ],
        if (recent.isNotEmpty) ...[
          SectionHeader('Recently viewed', action: 'Clear', onAction: () => ref.read(recentProvider.notifier).clear(), padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm)),
          for (final h in recent.take(8)) _HitRow(hit: h, onTap: () => onOpen(h)),
        ],
        if (favs.isNotEmpty) ...[
          const SectionHeader('Your football', padding: EdgeInsets.only(top: Space.xl, bottom: Space.sm)),
          for (final f in favs)
            _HitRow(
              hit: SearchHit(kind: switch (f.kind) { FavKind.team => SearchKind.team, FavKind.player => SearchKind.player, FavKind.league => SearchKind.league }, id: f.id, title: f.name, subtitle: f.subtitle, image: f.image),
              onTap: () => onOpen(SearchHit(kind: switch (f.kind) { FavKind.team => SearchKind.team, FavKind.player => SearchKind.player, FavKind.league => SearchKind.league }, id: f.id, title: f.name, subtitle: f.subtitle, image: f.image)),
            ),
        ],
        if (queries.isEmpty && recent.isEmpty && favs.isEmpty)
          const EmptyState(art: EmptyArt.search, title: 'Find anything', message: 'Search players, teams, competitions and matches. Small typos are fine.'),
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({super.key, required this.q, required this.remoteQ, required this.onOpen});
  final String q;
  final String remoteQ;
  final ValueChanged<SearchHit> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    // Local, instant: catalogue + recents + favourites + nearby matches.
    final catalog = ref.watch(leaguesCatalogProvider).value?.data ?? const <LeagueInfo>[];
    final recent = ref.watch(recentProvider);
    final today = dateOnly(DateTime.now());
    final days = [for (final d in [-1, 0, 1]) ...?ref.watch(dayMatchesProvider(today.add(Duration(days: d)))).value?.data];

    final leagues = Fuzzy.rank(q, catalog, (l) => '${l.ref.name} ${l.ref.country ?? ''}', limit: 6)
        .map((l) => SearchHit(kind: SearchKind.league, id: l.ref.id, title: l.ref.name, subtitle: [l.ref.country, l.type].whereType<String>().join(' · '), image: l.ref.logo, score: Fuzzy.score(q, l.ref.name)))
        .toList();
    final localEntities = Fuzzy.rank(q, recent, (h) => h.title, limit: 10).map((h) => h.withScore(Fuzzy.score(q, h.title))).toList();
    final matches = Fuzzy.rank(q, days, (m) => '${m.home.name} ${m.away.name} ${m.league.name}', limit: 8);

    final remote = remoteQ.isEmpty ? null : ref.watch(remoteSearchProvider(remoteQ));
    final remoteHits = remote?.value ?? const <SearchHit>[];

    // Merge and de-duplicate.
    final seen = <String>{};
    List<SearchHit> dedupe(Iterable<SearchHit> xs) => [for (final x in xs) if (seen.add('${x.kind}:${x.id}')) x];
    final all = dedupe([...localEntities, ...remoteHits, ...leagues]);
    final players = all.where((h) => h.kind == SearchKind.player).toList()..sort((a, b) => b.score.compareTo(a.score));
    final teams = all.where((h) => h.kind == SearchKind.team).toList()..sort((a, b) => b.score.compareTo(a.score));
    final comps = all.where((h) => h.kind == SearchKind.league).toList()..sort((a, b) => b.score.compareTo(a.score));

    // Matches for the best team hit (next + last), if we have it cached.
    final topTeam = teams.firstOrNull;
    final teamMatches = topTeam == null ? const <Match>[] : (ref.watch(teamMatchesProvider(topTeam.id)).value?.data ?? const <Match>[]);
    final relevant = <Match>[
      ...matches,
      ...teamMatches.where((m) => m.status.isFinished).toList().reversed.take(1),
      ...teamMatches.where((m) => !m.status.isFinished).take(1),
    ];
    final matchList = {for (final m in relevant) m.id: m}.values.toList();

    final sections = <(String, int, List<Widget>)>[
      if (players.isNotEmpty) ('Players', (players.first.score * 100).round(), [for (final h in players.take(6)) _HitRow(hit: h, onTap: () => onOpen(h))]),
      if (teams.isNotEmpty) ('Teams', (teams.first.score * 100).round(), [for (final h in teams.take(6)) _HitRow(hit: h, onTap: () => onOpen(h))]),
      if (matchList.isNotEmpty) ('Matches', 70, [for (final m in matchList.take(5)) Padding(padding: const EdgeInsets.only(bottom: 6), child: MatchRow(match: m, scope: 'sr${m.id}', showLeague: true, showDate: true))]),
      if (comps.isNotEmpty) ('Competitions', (comps.first.score * 100).round() - 5, [for (final h in comps.take(5)) _HitRow(hit: h, onTap: () => onOpen(h))]),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, navClearance),
      children: [
        if (remote?.isLoading ?? false) const LinearProgressIndicator(minHeight: 2),
        if (q.length < 3) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Type 3+ letters to search the full database.', style: AppType.body(12.5, color: c.textFaint))),
        if (remote?.hasError ?? false) ErrorState(error: remote!.error!, compact: true),
        for (final (title, _, children) in sections) ...[
          SectionHeader(title, padding: const EdgeInsets.only(top: Space.lg, bottom: Space.sm)),
          ...children,
        ],
        if (sections.isEmpty && !(remote?.isLoading ?? false) && q.length >= 3)
          EmptyState(art: EmptyArt.search, title: 'No results for "$q"', message: 'Try a shorter name or check the spelling of the club or player.', compact: true),
      ],
    );
  }
}

class _HitRow extends StatelessWidget {
  const _HitRow({required this.hit, required this.onTap});
  final SearchHit hit;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final leading = switch (hit.kind) {
      SearchKind.player => PlayerAvatar(name: hit.title, photo: hit.image, size: 40),
      SearchKind.team => TeamCrest(team: TeamRef(id: hit.id, name: hit.title, logo: hit.image), size: 36),
      SearchKind.league => LeagueLogo(league: LeagueRef(id: hit.id, name: hit.title, logo: hit.image), size: 32),
      SearchKind.match => Icon(Icons.sports_soccer, color: c.textMuted),
    };
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(width: 44, child: Center(child: leading)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hit.title, style: AppType.body(15, weight: 600, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (hit.subtitle != null && hit.subtitle!.isNotEmpty) Text(hit.subtitle!, style: AppType.body(12.5, color: c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textFaint),
        ]),
      ),
    ).animate().fadeIn(duration: Motion.fast);
  }
}
