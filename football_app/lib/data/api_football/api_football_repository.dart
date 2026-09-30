import '../../core/cache/cache_store.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/format.dart';
import '../football_repository.dart';
import '../models/models.dart';
import 'parser.dart';

/// API-Football v3 implementation of [FootballRepository].
///
/// Budget strategy (free tier = 100 requests/day):
/// * `fixtures?live=all` serves every live surface in one call.
/// * Match detail uses `fixtures?id=` which already embeds events, lineups,
///   statistics and player lines — one call per match screen.
/// * Season-wide lists (`fixtures?team=&season=`) replace `last/next` queries
///   and are reused for form, fixtures, results and briefings.
/// * Everything is cached with a TTL tuned to how often it changes.
class ApiFootballRepository implements FootballRepository {
  ApiFootballRepository({required ApiFootballClient client, required CacheStore store, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _fetcher = CachedFetcher(store, client.get, clock: clock);

  /// For tests: inject a fetcher directly.
  ApiFootballRepository.withFetcher(this._fetcher, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final CachedFetcher _fetcher;
  final DateTime Function() _clock;

  @override
  String get providerName => 'API-Football';

  @override
  bool get isDemo => false;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        xg: true, // reported as `expected_goals` for covered competitions
        xa: false,
        momentum: false,
        shotMap: false,
        heatmap: false,
        passMap: false,
        touches: false,
        commentary: false,
        reportedTransfers: false,
        predictedLineups: false,
        news: false,
      );

  Future<Fresh<T>> _get<T>(String path, Map<String, String> q, Duration ttl, T Function(String body) parse, {bool force = false}) async {
    final f = await _fetcher.get(path, q, ttl: ttl, force: force);
    return Fresh(parse(f.body), fetchedAt: f.fetchedAt, stale: f.stale);
  }

  List<Match> _fixtures(String body) => ApiFootballParser.response(body).map(ApiFootballParser.fixture).toList();

  // ── Matches ──────────────────────────────────────────────────────────────
  @override
  Future<Fresh<List<Match>>> liveMatches({bool force = false}) =>
      _get('/fixtures', {'live': 'all'}, const Duration(seconds: 15), _fixtures, force: force);

  @override
  Future<Fresh<List<Match>>> matchesOn(DateTime day, {bool force = false}) {
    final today = dateOnly(_clock());
    final d = dateOnly(day);
    final ttl = d.isBefore(today.subtract(const Duration(days: 1)))
        ? const Duration(hours: 12)
        : d.isAfter(today)
            ? const Duration(hours: 1)
            : const Duration(minutes: 10);
    return _get('/fixtures', {'date': isoDate(d), 'timezone': 'UTC'}, ttl, _fixtures, force: force);
  }

  @override
  Future<Fresh<Match>> match(int id, {bool force = false}) async {
    Match parse(String b) {
      final list = _fixtures(b);
      if (list.isEmpty) throw const DataException(DataErrorKind.notFound, 'Match not found.');
      return list.first;
    }

    final q = {'id': '$id'};
    // Read through a long TTL first; then decide freshness by match state:
    // finished matches never change, scheduled ones change rarely, live ones
    // are refreshed on every poll.
    final cached = await _get('/fixtures', q, const Duration(days: 30), parse);
    final age = _clock().difference(cached.fetchedAt);
    final st = cached.data.status;
    if (cached.stale || st.isFinished || age < const Duration(seconds: 10)) return cached;
    if (!force && st.isScheduled && cached.data.kickoff.isAfter(_clock()) && age < const Duration(minutes: 10)) return cached;
    if (!force && st.isLive && age < const Duration(seconds: 15)) return cached;
    return _get('/fixtures', q, Duration.zero, parse, force: true);
  }

  @override
  Future<Fresh<List<Match>>> matchesByIds(List<int> ids) async {
    if (ids.isEmpty) return Fresh(const [], fetchedAt: _clock());
    // API limit: 20 ids per call.
    final chunks = <List<int>>[];
    for (var i = 0; i < ids.length; i += 20) {
      chunks.add(ids.sublist(i, (i + 20).clamp(0, ids.length)));
    }
    final out = <Match>[];
    var stale = false;
    DateTime at = _clock();
    for (final c in chunks) {
      final r = await _get('/fixtures', {'ids': c.join('-')}, const Duration(days: 30), _fixtures);
      out.addAll(r.data);
      stale |= r.stale;
      at = r.fetchedAt;
    }
    return Fresh(out, fetchedAt: at, stale: stale);
  }

  @override
  Future<Fresh<MatchAnalytics?>> analytics(int matchId, {bool force = false}) async => Fresh(null, fetchedAt: _clock());

  @override
  Future<Fresh<List<Match>>> headToHead(int teamA, int teamB) {
    final a = teamA < teamB ? teamA : teamB;
    final b = teamA < teamB ? teamB : teamA;
    return _get('/fixtures/headtohead', {'h2h': '$a-$b'}, const Duration(hours: 12), (body) {
      final list = _fixtures(body).where((m) => m.status.isFinished).toList()..sort((x, y) => y.kickoff.compareTo(x.kickoff));
      return list;
    });
  }

  @override
  Future<Fresh<List<Injury>>> injuries(int matchId) =>
      _get('/injuries', {'fixture': '$matchId'}, const Duration(hours: 1), (b) => ApiFootballParser.response(b).map(ApiFootballParser.injury).toList());

  @override
  Future<Fresh<Prediction?>> prediction(int matchId) =>
      _get('/predictions', {'fixture': '$matchId'}, const Duration(hours: 6), ApiFootballParser.prediction);

  // ── Competitions ─────────────────────────────────────────────────────────
  @override
  Future<Fresh<List<LeagueInfo>>> leagues() =>
      _get('/leagues', {'current': 'true'}, const Duration(days: 7), (b) => ApiFootballParser.response(b).map(ApiFootballParser.leagueInfo).toList());

  @override
  Future<Fresh<LeagueInfo?>> league(int id) async {
    // Reuse the catalogue if it is cached; otherwise fetch the single league.
    final r = await _get('/leagues', {'id': '$id'}, const Duration(days: 3), (b) {
      final list = ApiFootballParser.response(b).map(ApiFootballParser.leagueInfo).toList();
      return list.isEmpty ? null : list.first;
    });
    return r;
  }

  @override
  Future<Fresh<StandingsTable?>> standings(int leagueId, int season) =>
      _get('/standings', {'league': '$leagueId', 'season': '$season'}, const Duration(minutes: 30), ApiFootballParser.standings);

  @override
  Future<Fresh<List<Match>>> leagueMatches(int leagueId, int season) =>
      _get('/fixtures', {'league': '$leagueId', 'season': '$season'}, const Duration(minutes: 30), _fixtures);

  @override
  Future<Fresh<List<PlayerWithSeasons>>> topScorers(int leagueId, int season) => _get('/players/topscorers', {'league': '$leagueId', 'season': '$season'},
      const Duration(hours: 6), (b) => ApiFootballParser.response(b).map(ApiFootballParser.playerWithSeasons).toList());

  @override
  Future<Fresh<List<PlayerWithSeasons>>> topAssists(int leagueId, int season) => _get('/players/topassists', {'league': '$leagueId', 'season': '$season'},
      const Duration(hours: 6), (b) => ApiFootballParser.response(b).map(ApiFootballParser.playerWithSeasons).toList());

  @override
  Future<Fresh<List<TeamRef>>> leagueTeams(int leagueId, int season) => _get('/teams', {'league': '$leagueId', 'season': '$season'}, const Duration(days: 7),
      (b) => ApiFootballParser.response(b).map((t) => ApiFootballParser.teamInfo(t).ref).toList());

  // ── Teams ────────────────────────────────────────────────────────────────
  @override
  Future<Fresh<TeamInfo>> team(int id) => _get('/teams', {'id': '$id'}, const Duration(days: 7), (b) {
        final r = ApiFootballParser.response(b);
        if (r.isEmpty) throw const DataException(DataErrorKind.notFound, 'Team not found.');
        return ApiFootballParser.teamInfo(r.first);
      });

  @override
  Future<Fresh<List<LeagueInfo>>> teamLeagues(int teamId) => _get('/leagues', {'team': '$teamId', 'current': 'true'}, const Duration(days: 3),
      (b) => ApiFootballParser.response(b).map(ApiFootballParser.leagueInfo).toList());

  @override
  Future<Fresh<List<Match>>> teamMatches(int teamId, int season) =>
      _get('/fixtures', {'team': '$teamId', 'season': '$season'}, const Duration(minutes: 30), (b) => _fixtures(b)..sort((a, c) => a.kickoff.compareTo(c.kickoff)));

  @override
  Future<Fresh<TeamSeasonStats?>> teamStats(int teamId, int leagueId, int season) =>
      _get('/teams/statistics', {'team': '$teamId', 'league': '$leagueId', 'season': '$season'}, const Duration(hours: 6), ApiFootballParser.teamStats);

  @override
  Future<Fresh<List<SquadPlayer>>> squad(int teamId) => _get('/players/squads', {'team': '$teamId'}, const Duration(days: 1), (b) {
        final r = ApiFootballParser.response(b);
        if (r.isEmpty) return <SquadPlayer>[];
        return ApiFootballParser.l(ApiFootballParser.m(r.first)['players']).map(ApiFootballParser.squadPlayer).toList();
      });

  @override
  Future<Fresh<List<Transfer>>> teamTransfers(int teamId) =>
      _get('/transfers', {'team': '$teamId'}, const Duration(days: 1), (b) => ApiFootballParser.transfers(ApiFootballParser.response(b)));

  // ── Players ──────────────────────────────────────────────────────────────
  @override
  Future<Fresh<PlayerWithSeasons>> player(int id, int season) => _get('/players', {'id': '$id', 'season': '$season'}, const Duration(hours: 6), (b) {
        final r = ApiFootballParser.response(b);
        if (r.isEmpty) throw const DataException(DataErrorKind.notFound, 'No data for this player in the selected season.');
        return ApiFootballParser.playerWithSeasons(r.first);
      });

  @override
  Future<Fresh<List<int>>> playerSeasons(int id) => _get('/players/seasons', {'player': '$id'}, const Duration(days: 3),
      (b) => ApiFootballParser.response(b).map(ApiFootballParser.i).whereType<int>().toList()..sort());

  @override
  Future<Fresh<List<CareerEntry>>> playerCareer(int id) => _get('/players/teams', {'player': '$id'}, const Duration(days: 7), (b) {
        return ApiFootballParser.response(b).map((x) {
          final m = ApiFootballParser.m(x);
          final seasons = ApiFootballParser.l(m['seasons']).map(ApiFootballParser.i).whereType<int>().toList()..sort((a, c) => c.compareTo(a));
          return CareerEntry(team: ApiFootballParser.team(m['team']), seasons: seasons);
        }).toList();
      });

  @override
  Future<Fresh<List<Transfer>>> playerTransfers(int id) =>
      _get('/transfers', {'player': '$id'}, const Duration(days: 3), (b) => ApiFootballParser.transfers(ApiFootballParser.response(b)));

  // ── Search ───────────────────────────────────────────────────────────────
  @override
  Future<Fresh<List<SearchHit>>> searchTeams(String query) =>
      _get('/teams', {'search': query}, const Duration(days: 3), (b) => ApiFootballParser.response(b).map((x) {
            final t = ApiFootballParser.teamInfo(x);
            return SearchHit(kind: SearchKind.team, id: t.ref.id, title: t.ref.name, subtitle: t.country, image: t.ref.logo);
          }).toList());

  @override
  Future<Fresh<List<SearchHit>>> searchPlayers(String query) =>
      _get('/players/profiles', {'search': query}, const Duration(days: 3), (b) => ApiFootballParser.response(b).map((x) {
            final p = ApiFootballParser.profile(ApiFootballParser.m(x)['player']);
            return SearchHit(
              kind: SearchKind.player,
              id: p.id,
              title: p.name,
              subtitle: [p.position, p.nationality].whereType<String>().join(' · '),
              image: p.photo,
            );
          }).toList());
}
