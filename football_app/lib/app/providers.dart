import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cache/cache_store.dart';
import '../core/network/api_client.dart';
import '../core/network/request_budget.dart';
import '../core/utils/format.dart';
import '../data/api_football/api_football_repository.dart';
import '../data/demo/demo_repository.dart';
import '../data/football_repository.dart';
import '../data/models/models.dart';
import 'env.dart';
import 'polling.dart';
import 'settings.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────

final cacheStoreProvider = Provider<CacheStore>((ref) => throw UnimplementedError('Overridden in main()'));

final budgetProvider = Provider<RequestBudget>((ref) {
  final store = ref.read(localStoreProvider);
  final j = store.readMap('budget');
  final b = RequestBudget(
    dailyLimit: (j?['limit'] as num?)?.toInt(),
    remaining: (j?['remaining'] as num?)?.toInt(),
    updatedAt: j?['at'] == null ? null : DateTime.fromMillisecondsSinceEpoch((j!['at'] as num).toInt()),
  );
  b.saver = ref.read(settingsProvider).dataSaver;
  ref.listen(settingsProvider.select((s) => s.dataSaver), (_, v) => b.saver = v);
  void persist() => store.write('budget', {'limit': b.dailyLimit, 'remaining': b.remaining, 'at': b.updatedAt.millisecondsSinceEpoch});
  b.addListener(persist);
  ref.onDispose(() => b.removeListener(persist));
  return b;
});

class BudgetState {
  const BudgetState({this.limit, this.remaining, required this.paused});
  final int? limit;
  final int? remaining;
  final bool paused;
}

class BudgetNotifier extends Notifier<BudgetState> {
  @override
  BudgetState build() {
    final b = ref.watch(budgetProvider);
    void l() => state = _read(b);
    b.addListener(l);
    ref.onDispose(() => b.removeListener(l));
    return _read(b);
  }

  BudgetState _read(RequestBudget b) => BudgetState(limit: b.dailyLimit, remaining: b.effectiveRemaining, paused: b.livePaused);
}

final budgetStateProvider = NotifierProvider<BudgetNotifier, BudgetState>(BudgetNotifier.new);

/// The single switch point between providers. UI code only ever sees
/// [FootballRepository].
final repositoryProvider = Provider<FootballRepository>((ref) {
  final demo = ref.watch(settingsProvider.select((s) => s.useDemo));
  if (demo) return DemoRepository();
  return ApiFootballRepository(
    client: ApiFootballClient(apiKey: Env.apiKey, budget: ref.watch(budgetProvider)),
    store: ref.watch(cacheStoreProvider),
  );
});

final capabilitiesProvider = Provider<ProviderCapabilities>((ref) => ref.watch(repositoryProvider).capabilities);

Duration? _demoInterval(FootballRepository r) => r.isDemo ? const Duration(seconds: 8) : null;

// ── Live & matches ─────────────────────────────────────────────────────────

final liveMatchesProvider = StreamProvider.autoDispose<Fresh<List<Match>>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return pollingStream(
    ref,
    load: (force) => repo.liveMatches(force: force),
    shouldPoll: (_) => true,
    budget: ref.watch(budgetProvider),
    fixedInterval: _demoInterval(repo),
    // Nothing live: check back less often (kick-offs are rarely missed by
    // more than a couple of minutes).
    intervalMultiplier: (v) => v.isEmpty ? 4 : 1,
  );
});

/// Matches for a day. For today, live scores from [liveMatchesProvider] are
/// merged in so the list updates without refetching it.
class DayMatches extends AsyncNotifier<Fresh<List<Match>>> {
  DayMatches(this.day);
  final DateTime day;
  DateTime? _lastForced;

  bool get _isToday => sameDay(day, DateTime.now());

  @override
  Future<Fresh<List<Match>>> build() async {
    ref.cacheFor(const Duration(minutes: 3));
    final repo = ref.watch(repositoryProvider);
    final base = await repo.matchesOn(day);
    if (_isToday) {
      ref.listen(liveMatchesProvider, (_, next) {
        final live = next.value;
        final cur = state.value;
        if (live == null || cur == null) return;
        state = AsyncData(_merge(cur, live));
      });
    }
    final live = _isToday ? ref.read(liveMatchesProvider).value : null;
    return live == null ? base : _merge(base, live);
  }

  Fresh<List<Match>> _merge(Fresh<List<Match>> dayList, Fresh<List<Match>> live) {
    final byId = {for (final m in live.data) m.id: m};
    final merged = [for (final m in dayList.data) byId[m.id] != null ? m.mergeLive(byId[m.id]!) : m];
    // A match we showed as live has left the live feed → it has finished;
    // refresh the day list once (throttled) to get its final state.
    final orphan = merged.any((m) => m.status.isLive && !byId.containsKey(m.id)) && live.fetchedAt.isAfter(dayList.fetchedAt) && !live.stale;
    if (orphan && (_lastForced == null || DateTime.now().difference(_lastForced!) > const Duration(minutes: 2))) {
      _lastForced = DateTime.now();
      scheduleMicrotask(() async {
        try {
          final fresh = await ref.read(repositoryProvider).matchesOn(day, force: true);
          if (ref.mounted) state = AsyncData(_merge(fresh, ref.read(liveMatchesProvider).value ?? live));
        } catch (_) {}
      });
    }
    return Fresh(merged, fetchedAt: live.fetchedAt.isAfter(dayList.fetchedAt) ? live.fetchedAt : dayList.fetchedAt, stale: dayList.stale || live.stale, provenance: dayList.provenance);
  }
}

final dayMatchesProvider = AsyncNotifierProvider.autoDispose.family<DayMatches, Fresh<List<Match>>, DateTime>(DayMatches.new);

final matchProvider = StreamProvider.autoDispose.family<Fresh<Match>, int>((ref, id) {
  ref.cacheFor(const Duration(minutes: 2));
  final repo = ref.watch(repositoryProvider);
  return pollingStream(
    ref,
    load: (force) => repo.match(id, force: force),
    shouldPoll: (m) => m.status.isLive || (m.status.isScheduled && m.kickoff.difference(DateTime.now()) < const Duration(minutes: 20)),
    budget: ref.watch(budgetProvider),
    fixedInterval: _demoInterval(repo),
    intervalMultiplier: (m) => m.status.isScheduled ? 3 : 1,
  );
});

final analyticsProvider = StreamProvider.autoDispose.family<Fresh<MatchAnalytics?>, int>((ref, id) {
  final repo = ref.watch(repositoryProvider);
  final caps = repo.capabilities;
  if (!caps.momentum && !caps.anyPitchData) return Stream.value(Fresh(null, fetchedAt: DateTime.now()));
  final live = ref.watch(matchProvider(id).select((m) => m.value?.data.status.isLive ?? false));
  return pollingStream(
    ref,
    load: (force) => repo.analytics(id, force: force),
    shouldPoll: (_) => live,
    budget: ref.watch(budgetProvider),
    fixedInterval: _demoInterval(repo),
  );
});

final h2hProvider = FutureProvider.autoDispose.family<Fresh<List<Match>>, (int, int)>((ref, ids) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(repositoryProvider).headToHead(ids.$1, ids.$2);
});

final injuriesProvider = FutureProvider.autoDispose.family<Fresh<List<Injury>>, int>((ref, id) => ref.watch(repositoryProvider).injuries(id));
final predictionProvider = FutureProvider.autoDispose.family<Fresh<Prediction?>, int>((ref, id) => ref.watch(repositoryProvider).prediction(id));

// ── Competitions ───────────────────────────────────────────────────────────

final leaguesCatalogProvider = FutureProvider<Fresh<List<LeagueInfo>>>((ref) => ref.watch(repositoryProvider).leagues());

final leagueInfoProvider = FutureProvider.autoDispose.family<LeagueInfo?, int>((ref, id) async {
  ref.cacheFor(const Duration(minutes: 10));
  final catalog = ref.watch(leaguesCatalogProvider).value;
  final hit = catalog?.data.where((l) => l.ref.id == id).firstOrNull;
  if (hit != null) return hit;
  return (await ref.watch(repositoryProvider).league(id)).data;
});

/// Season to show for a competition: the user's override (Data Preferences)
/// or the provider's current season.
final leagueSeasonProvider = FutureProvider.autoDispose.family<int, int>((ref, leagueId) async {
  final override = ref.watch(settingsProvider.select((s) => s.seasonOverride));
  if (override != null) return override;
  final info = await ref.watch(leagueInfoProvider(leagueId).future);
  final s = info?.currentSeason?.year;
  if (s == null) throw const DataException(DataErrorKind.notFound, 'No season information for this competition.');
  return s;
});

final standingsProvider = FutureProvider.autoDispose.family<Fresh<StandingsTable?>, int>((ref, leagueId) async {
  ref.cacheFor(const Duration(minutes: 5));
  final season = await ref.watch(leagueSeasonProvider(leagueId).future);
  return ref.watch(repositoryProvider).standings(leagueId, season);
});

final leagueMatchesProvider = FutureProvider.autoDispose.family<Fresh<List<Match>>, int>((ref, leagueId) async {
  ref.cacheFor(const Duration(minutes: 5));
  final season = await ref.watch(leagueSeasonProvider(leagueId).future);
  return ref.watch(repositoryProvider).leagueMatches(leagueId, season);
});

final topScorersProvider = FutureProvider.autoDispose.family<Fresh<List<PlayerWithSeasons>>, int>((ref, leagueId) async {
  ref.cacheFor(const Duration(minutes: 5));
  final season = await ref.watch(leagueSeasonProvider(leagueId).future);
  return ref.watch(repositoryProvider).topScorers(leagueId, season);
});

final topAssistsProvider = FutureProvider.autoDispose.family<Fresh<List<PlayerWithSeasons>>, int>((ref, leagueId) async {
  ref.cacheFor(const Duration(minutes: 5));
  final season = await ref.watch(leagueSeasonProvider(leagueId).future);
  return ref.watch(repositoryProvider).topAssists(leagueId, season);
});

final leagueTeamsProvider = FutureProvider.autoDispose.family<Fresh<List<TeamRef>>, int>((ref, leagueId) async {
  final season = await ref.watch(leagueSeasonProvider(leagueId).future);
  return ref.watch(repositoryProvider).leagueTeams(leagueId, season);
});

// ── Teams ──────────────────────────────────────────────────────────────────

final teamProvider = FutureProvider.autoDispose.family<Fresh<TeamInfo>, int>((ref, id) {
  ref.cacheFor(const Duration(minutes: 10));
  return ref.watch(repositoryProvider).team(id);
});

final teamLeaguesProvider = FutureProvider.autoDispose.family<List<LeagueInfo>, int>((ref, id) async {
  ref.cacheFor(const Duration(minutes: 10));
  return (await ref.watch(repositoryProvider).teamLeagues(id)).data;
});

/// The team's domestic league (provider data: league type + country).
final teamPrimaryLeagueProvider = FutureProvider.autoDispose.family<LeagueInfo?, int>((ref, id) async {
  final leagues = await ref.watch(teamLeaguesProvider(id).future);
  if (leagues.isEmpty) return null;
  final team = (await ref.watch(teamProvider(id).future)).data;
  final domestic = leagues.where((l) => !l.isCup && (team.country == null || l.ref.country == team.country)).toList();
  return domestic.firstOrNull ?? leagues.where((l) => !l.isCup).firstOrNull ?? leagues.first;
});

final teamSeasonProvider = FutureProvider.autoDispose.family<int, int>((ref, id) async {
  final override = ref.watch(settingsProvider.select((s) => s.seasonOverride));
  if (override != null) return override;
  final lg = await ref.watch(teamPrimaryLeagueProvider(id).future);
  final s = lg?.currentSeason?.year;
  if (s == null) throw const DataException(DataErrorKind.notFound, 'No current season found for this team.');
  return s;
});

final teamMatchesProvider = FutureProvider.autoDispose.family<Fresh<List<Match>>, int>((ref, id) async {
  ref.cacheFor(const Duration(minutes: 5));
  final season = await ref.watch(teamSeasonProvider(id).future);
  return ref.watch(repositoryProvider).teamMatches(id, season);
});

final teamStatsProvider = FutureProvider.autoDispose.family<Fresh<TeamSeasonStats?>, (int, int)>((ref, key) async {
  final (teamId, leagueId) = key;
  final season = await ref.watch(teamSeasonProvider(teamId).future);
  return ref.watch(repositoryProvider).teamStats(teamId, leagueId, season);
});

final squadProvider = FutureProvider.autoDispose.family<Fresh<List<SquadPlayer>>, int>((ref, id) {
  ref.cacheFor(const Duration(minutes: 10));
  return ref.watch(repositoryProvider).squad(id);
});

final teamTransfersProvider = FutureProvider.autoDispose.family<Fresh<List<Transfer>>, int>((ref, id) => ref.watch(repositoryProvider).teamTransfers(id));

// ── Players ────────────────────────────────────────────────────────────────

final playerSeasonsProvider = FutureProvider.autoDispose.family<List<int>, int>((ref, id) async {
  ref.cacheFor(const Duration(minutes: 10));
  return (await ref.watch(repositoryProvider).playerSeasons(id)).data;
});

/// Latest season with data for a player (or the user's override).
final playerCurrentSeasonProvider = FutureProvider.autoDispose.family<int, int>((ref, id) async {
  final override = ref.watch(settingsProvider.select((s) => s.seasonOverride));
  if (override != null) return override;
  final seasons = await ref.watch(playerSeasonsProvider(id).future);
  if (seasons.isEmpty) throw const DataException(DataErrorKind.notFound, 'No seasons on record for this player.');
  return seasons.last;
});

final playerProvider = FutureProvider.autoDispose.family<Fresh<PlayerWithSeasons>, (int, int)>((ref, key) {
  ref.cacheFor(const Duration(minutes: 10));
  return ref.watch(repositoryProvider).player(key.$1, key.$2);
});

final playerCareerProvider = FutureProvider.autoDispose.family<Fresh<List<CareerEntry>>, int>((ref, id) => ref.watch(repositoryProvider).playerCareer(id));

final playerTransfersProvider = FutureProvider.autoDispose.family<Fresh<List<Transfer>>, int>((ref, id) => ref.watch(repositoryProvider).playerTransfers(id));

class PlayerMatchEntry {
  const PlayerMatchEntry(this.match, this.line);
  final Match match;
  final PlayerMatchLine line;
}

/// The player's last [count] appearances with per-match lines. Uses the
/// team's season fixture list (usually cached) + one batched detail call.
final playerRecentProvider = FutureProvider.autoDispose.family<List<PlayerMatchEntry>, (int, int)>((ref, key) async {
  final (playerId, count) = key;
  ref.cacheFor(const Duration(minutes: 10));
  final repo = ref.watch(repositoryProvider);
  final season = await ref.watch(playerCurrentSeasonProvider(playerId).future);
  final pws = (await ref.watch(playerProvider((playerId, season)).future)).data;
  final team = pws.mainTeam;
  if (team == null) return const [];
  final matches = (await repo.teamMatches(team.id, season)).data.where((m) => m.status.isFinished).toList()..sort((a, b) => b.kickoff.compareTo(a.kickoff));
  final ids = matches.take(count + 6 > 20 ? 20 : count + 6).map((m) => m.id).toList();
  final detailed = (await repo.matchesByIds(ids)).data..sort((a, b) => b.kickoff.compareTo(a.kickoff));
  final out = <PlayerMatchEntry>[];
  for (final m in detailed) {
    final line = m.players?.where((p) => p.player.id == playerId && (p.stats.minutes ?? 0) > 0).firstOrNull;
    if (line != null) out.add(PlayerMatchEntry(m, line));
    if (out.length == count) break;
  }
  return out.reversed.toList();
});
