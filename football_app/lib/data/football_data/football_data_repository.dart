import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/cache/cache_store.dart';
import '../football_repository.dart';
import '../models/models.dart';

/// football-data.org v4 — free tier covers the current season of 12 major
/// competitions (tables, fixtures, results, scorers, squads). Used as a
/// fallback when the primary provider's plan blocks the current season.
///
/// IDs from this provider live in their own namespace ([offset]) so they can
/// never collide with API-Football IDs; routes stay provider-agnostic.
class FootballDataSource {
  FootballDataSource({required this.apiKey, required CacheStore store, http.Client? client}) : _fetcher = CachedFetcher(store, (p, q) => _get(client ?? http.Client(), apiKey, p, q));

  static const offset = 90000000;
  static bool owns(int id) => id >= offset;

  /// API-Football league id → football-data.org competition code.
  static const codes = {39: 'PL', 140: 'PD', 135: 'SA', 78: 'BL1', 61: 'FL1', 2: 'CL', 88: 'DED', 94: 'PPL', 40: 'ELC', 71: 'BSA', 1: 'WC', 4: 'EC'};
  static final _leagueByCode = {for (final e in codes.entries) e.value: e.key};

  final String apiKey;
  final CachedFetcher _fetcher;

  static Future<String> _get(http.Client c, String key, String path, Map<String, String> q) async {
    http.Response r;
    try {
      r = await c.get(Uri.parse('https://api.football-data.org/v4$path').replace(queryParameters: q.isEmpty ? null : q), headers: {'X-Auth-Token': key}).timeout(const Duration(seconds: 12));
    } catch (_) {
      throw const DataException(DataErrorKind.network, 'No connection to football-data.org.');
    }
    if (r.statusCode == 429) throw const DataException(DataErrorKind.rateLimited, 'football-data.org rate limit (10/min). Retrying shortly.');
    if (r.statusCode == 403) throw const DataException(DataErrorKind.plan, 'Not included in the football-data.org free tier.');
    if (r.statusCode == 404) throw const DataException(DataErrorKind.notFound, 'Not found.');
    if (r.statusCode != 200) throw DataException(DataErrorKind.server, 'football-data.org error ${r.statusCode}.');
    return utf8.decode(r.bodyBytes);
  }

  Future<Fresh<T>> _q<T>(String path, Duration ttl, T Function(Map<String, dynamic>) parse, [Map<String, String> q = const {}]) async {
    final f = await _fetcher.get(path, q, ttl: ttl);
    return Fresh(parse(jsonDecode(f.body) as Map<String, dynamic>), fetchedAt: f.fetchedAt, stale: f.stale);
  }

  // ── mapping ──────────────────────────────────────────────────────────────
  static Map<String, dynamic> _m(dynamic v) => v is Map<String, dynamic> ? v : const {};
  static List<dynamic> _l(dynamic v) => v is List ? v : const [];
  static int? _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

  static TeamRef team(dynamic j) {
    final t = _m(j);
    return TeamRef(id: offset + (_i(t['id']) ?? 0), name: (t['shortName'] ?? t['name'] ?? 'Unknown') as String, logo: t['crest'] as String?);
  }

  static LeagueRef league(dynamic comp, {dynamic area, int? season, String? round}) {
    final c = _m(comp);
    final id = _leagueByCode[c['code']] ?? offset + (_i(c['id']) ?? 0);
    return LeagueRef(id: id, name: (c['name'] ?? '') as String, logo: c['emblem'] as String?, country: _m(area)['name'] as String?, flag: _m(area)['flag'] as String?, season: season, round: round);
  }

  static Match parseMatch(dynamic raw, {Map<String, dynamic>? comp, Map<String, dynamic>? area}) {
    final x = _m(raw);
    final score = _m(x['score']);
    final ft = _m(score['fullTime']), ht = _m(score['halfTime']);
    final dur = score['duration'];
    final st = switch (x['status']) {
      'IN_PLAY' => 'LIVE',
      'PAUSED' => 'HT',
      'FINISHED' => dur == 'PENALTY_SHOOTOUT' ? 'PEN' : (dur == 'EXTRA_TIME' ? 'AET' : 'FT'),
      'POSTPONED' => 'PST',
      'SUSPENDED' => 'SUSP',
      'CANCELLED' => 'CANC',
      'AWARDED' => 'AWD',
      _ => 'NS',
    };
    final season = DateTime.tryParse('${_m(x['season'])['startDate']}')?.year;
    final md = _i(x['matchday']);
    return Match(
      id: offset + (_i(x['id']) ?? 0),
      league: league(x['competition'] ?? comp, area: x['area'] ?? area, season: season, round: md == null ? x['stage'] as String? : 'Regular Season - $md'),
      home: team(x['homeTeam']),
      away: team(x['awayTeam']),
      kickoff: DateTime.tryParse('${x['utcDate']}')?.toLocal() ?? DateTime.now(),
      status: MatchStatus(short: st, elapsed: _i(x['minute'])),
      homeGoals: _i(ft['home']),
      awayGoals: _i(ft['away']),
      halftime: ScorePair(_i(ht['home']), _i(ht['away'])),
      homeWinner: score['winner'] == null ? null : score['winner'] == 'HOME_TEAM',
      awayWinner: score['winner'] == null ? null : score['winner'] == 'AWAY_TEAM',
      venue: x['venue'] as String?,
      referee: _l(x['referees']).map((r) => _m(r)['name']).whereType<String>().firstOrNull,
    );
  }

  List<Match> _matches(Map<String, dynamic> j) => [for (final m in _l(j['matches'])) parseMatch(m, comp: _m(j['competition']))]..sort((a, b) => a.kickoff.compareTo(b.kickoff));

  // ── endpoints ────────────────────────────────────────────────────────────
  Future<Fresh<StandingsTable?>> standings(int leagueId) => _q('/competitions/${codes[leagueId]}/standings', const Duration(minutes: 30), (j) {
        final season = DateTime.tryParse('${_m(j['season'])['startDate']}')?.year ?? DateTime.now().year;
        final lg = league(j['competition'], area: j['area'], season: season);
        final groups = <StandingsGroup>[];
        for (final s in _l(j['standings']).where((s) => _m(s)['type'] == 'TOTAL')) {
          final rows = [
            for (final r in _l(_m(s)['table']))
              StandingRow(
                rank: _i(_m(r)['position']) ?? 0,
                team: team(_m(r)['team']),
                points: _i(_m(r)['points']) ?? 0,
                played: _i(_m(r)['playedGames']) ?? 0,
                win: _i(_m(r)['won']) ?? 0,
                draw: _i(_m(r)['draw']) ?? 0,
                lose: _i(_m(r)['lost']) ?? 0,
                goalsFor: _i(_m(r)['goalsFor']) ?? 0,
                goalsAgainst: _i(_m(r)['goalsAgainst']) ?? 0,
                goalDiff: _i(_m(r)['goalDifference']) ?? 0,
                form: (_m(r)['form'] as String?)?.replaceAll(',', ''),
              ),
          ];
          if (rows.isNotEmpty) groups.add(StandingsGroup(_m(s)['group'] as String?, rows));
        }
        return groups.isEmpty ? null : StandingsTable(league: lg, season: season, groups: groups);
      });

  Future<Fresh<List<Match>>> leagueMatches(int leagueId) => _q('/competitions/${codes[leagueId]}/matches', const Duration(minutes: 30), _matches);

  Future<Fresh<List<PlayerWithSeasons>>> scorers(int leagueId, {bool byAssists = false}) => _q('/competitions/${codes[leagueId]}/scorers', const Duration(hours: 6), (j) {
        final season = DateTime.tryParse('${_m(j['season'])['startDate']}')?.year ?? DateTime.now().year;
        final lg = league(j['competition'], season: season);
        final out = [
          for (final s in _l(j['scorers']))
            () {
              final p = _m(_m(s)['player']);
              final t = team(_m(s)['team']);
              return PlayerWithSeasons(
                PlayerProfile(id: offset + (_i(p['id']) ?? 0), name: '${p['name'] ?? ''}', nationality: p['nationality'] as String?, position: p['section'] as String? ?? p['position'] as String?, team: t),
                [PlayerSeason(season: season, team: t, league: lg, stats: PlayerStatLine(appearances: _i(_m(s)['playedMatches']), goals: _i(_m(s)['goals']) ?? 0, assists: _i(_m(s)['assists']) ?? 0, penaltiesScored: _i(_m(s)['penalties'])))],
              );
            }(),
        ];
        if (byAssists) out.sort((a, b) => (b.total.assists ?? 0).compareTo(a.total.assists ?? 0));
        return out;
      }, const {'limit': '20'});

  Future<Map<String, dynamic>> _team(int id) async => (await _q('/teams/${id - offset}', const Duration(days: 1), (j) => j)).data;

  Future<Fresh<TeamInfo>> teamInfo(int id) => _q('/teams/${id - offset}', const Duration(days: 1), (j) => TeamInfo(
        ref: team(j),
        country: _m(j['area'])['name'] as String?,
        founded: _i(j['founded']),
        venueName: j['venue'] as String?,
      ));

  Future<Fresh<List<LeagueInfo>>> teamLeagues(int id) async {
    final j = await _team(id);
    return Fresh([
      for (final c in _l(j['runningCompetitions']))
        LeagueInfo(ref: league(c, area: j['area']), type: _m(c)['type'] == 'CUP' ? 'Cup' : 'League', seasons: [SeasonInfo(year: DateTime.now().month >= 7 ? DateTime.now().year : DateTime.now().year - 1, current: true)]),
    ], fetchedAt: DateTime.now());
  }

  Future<Fresh<List<SquadPlayer>>> squad(int id) async {
    final j = await _team(id);
    int? age(dynamic dob) {
      final d = DateTime.tryParse('${dob ?? ''}');
      if (d == null) return null;
      final n = DateTime.now();
      return n.year - d.year - ((n.month < d.month || (n.month == d.month && n.day < d.day)) ? 1 : 0);
    }

    return Fresh([
      for (final p in _l(j['squad'])) SquadPlayer(id: offset + (_i(_m(p)['id']) ?? 0), name: '${_m(p)['name']}', position: _m(p)['position'] as String?, age: age(_m(p)['dateOfBirth'])),
    ], fetchedAt: DateTime.now());
  }

  Future<Fresh<List<Match>>> teamMatches(int id) => _q('/teams/${id - offset}/matches', const Duration(minutes: 30), _matches);

  Future<Fresh<Match>> match(int id) => _q('/matches/${id - offset}', const Duration(minutes: 1), (j) => FootballDataSource.parseMatch(j));

  Future<Fresh<PlayerWithSeasons>> person(int id) => _q('/persons/${id - offset}', const Duration(days: 3), (j) {
        final d = DateTime.tryParse('${j['dateOfBirth'] ?? ''}');
        final t = j['currentTeam'] == null ? null : team(j['currentTeam']);
        return PlayerWithSeasons(
          PlayerProfile(id: id, name: '${j['name'] ?? ''}', firstname: j['firstName'] as String?, lastname: j['lastName'] as String?, birthDate: d, age: d == null ? null : DateTime.now().difference(d).inDays ~/ 365, nationality: j['nationality'] as String?, position: j['position'] as String?, number: _i(j['shirtNumber']), team: t),
          const [],
        );
      });
}

/// Primary provider + football-data.org fallback. Whatever the primary plan
/// blocks (current-season tables, fixtures, scorers) is served by
/// football-data.org for the competitions it covers; entities that came from
/// football-data.org are routed back to it by ID namespace.
class HybridRepository implements FootballRepository {
  HybridRepository(this.primary, this.fd);
  final FootballRepository primary;
  final FootballDataSource fd;

  @override
  String get providerName => '${primary.providerName} + football-data.org';
  @override
  ProviderCapabilities get capabilities => primary.capabilities;
  @override
  bool get isDemo => false;

  /// Try the primary; on a plan restriction fall back when covered.
  Future<Fresh<T>> _or<T>(Future<Fresh<T>> Function() first, int leagueId, Future<Fresh<T>> Function() fallback) async {
    if (!FootballDataSource.codes.containsKey(leagueId)) return first();
    try {
      return await first();
    } on DataException catch (e) {
      if (e.kind == DataErrorKind.plan) return fallback();
      rethrow;
    }
  }

  static Fresh<T> _empty<T>(T v) => Fresh(v, fetchedAt: DateTime.now());

  @override
  Future<Fresh<List<Match>>> liveMatches({bool force = false}) => primary.liveMatches(force: force);
  @override
  Future<Fresh<List<Match>>> matchesOn(DateTime day, {bool force = false}) => primary.matchesOn(day, force: force);
  @override
  Future<Fresh<Match>> match(int id, {bool force = false}) => FootballDataSource.owns(id) ? fd.match(id) : primary.match(id, force: force);
  @override
  Future<Fresh<List<Match>>> matchesByIds(List<int> ids) => primary.matchesByIds(ids.where((i) => !FootballDataSource.owns(i)).toList());
  @override
  Future<Fresh<MatchAnalytics?>> analytics(int matchId, {bool force = false}) => FootballDataSource.owns(matchId) ? Future.value(_empty(null)) : primary.analytics(matchId, force: force);
  @override
  Future<Fresh<List<Match>>> headToHead(int a, int b) => (FootballDataSource.owns(a) || FootballDataSource.owns(b)) ? Future.value(_empty(const <Match>[])) : primary.headToHead(a, b);
  @override
  Future<Fresh<List<Injury>>> injuries(int id) => FootballDataSource.owns(id) ? Future.value(_empty(const <Injury>[])) : primary.injuries(id);
  @override
  Future<Fresh<Prediction?>> prediction(int id) => FootballDataSource.owns(id) ? Future.value(_empty(null)) : primary.prediction(id);

  @override
  Future<Fresh<List<LeagueInfo>>> leagues() => primary.leagues();
  @override
  Future<Fresh<LeagueInfo?>> league(int id) => primary.league(id);
  @override
  Future<Fresh<StandingsTable?>> standings(int l, int s) => _or(() => primary.standings(l, s), l, () => fd.standings(l));
  @override
  Future<Fresh<List<Match>>> leagueMatches(int l, int s) => _or(() => primary.leagueMatches(l, s), l, () => fd.leagueMatches(l));
  @override
  Future<Fresh<List<PlayerWithSeasons>>> topScorers(int l, int s) => _or(() => primary.topScorers(l, s), l, () => fd.scorers(l));
  @override
  Future<Fresh<List<PlayerWithSeasons>>> topAssists(int l, int s) => _or(() => primary.topAssists(l, s), l, () => fd.scorers(l, byAssists: true));
  @override
  Future<Fresh<List<TeamRef>>> leagueTeams(int l, int s) =>
      _or(() => primary.leagueTeams(l, s), l, () async => (await fd.standings(l)).map((t) => [for (final g in t?.groups ?? const <StandingsGroup>[]) ...g.rows.map((r) => r.team)]));

  @override
  Future<Fresh<TeamInfo>> team(int id) => FootballDataSource.owns(id) ? fd.teamInfo(id) : primary.team(id);
  @override
  Future<Fresh<List<LeagueInfo>>> teamLeagues(int id) => FootballDataSource.owns(id) ? fd.teamLeagues(id) : primary.teamLeagues(id);
  @override
  Future<Fresh<List<Match>>> teamMatches(int id, int s) => FootballDataSource.owns(id) ? fd.teamMatches(id) : primary.teamMatches(id, s);
  @override
  Future<Fresh<TeamSeasonStats?>> teamStats(int id, int l, int s) => FootballDataSource.owns(id) ? Future.value(_empty(null)) : primary.teamStats(id, l, s);
  @override
  Future<Fresh<List<SquadPlayer>>> squad(int id) => FootballDataSource.owns(id) ? fd.squad(id) : primary.squad(id);
  @override
  Future<Fresh<List<Transfer>>> teamTransfers(int id) => FootballDataSource.owns(id) ? Future.value(_empty(const <Transfer>[])) : primary.teamTransfers(id);

  @override
  Future<Fresh<PlayerWithSeasons>> player(int id, int s) => FootballDataSource.owns(id) ? fd.person(id) : primary.player(id, s);
  @override
  Future<Fresh<List<int>>> playerSeasons(int id) => FootballDataSource.owns(id) ? Future.value(_empty([DateTime.now().month >= 7 ? DateTime.now().year : DateTime.now().year - 1])) : primary.playerSeasons(id);
  @override
  Future<Fresh<List<CareerEntry>>> playerCareer(int id) => FootballDataSource.owns(id) ? Future.value(_empty(const <CareerEntry>[])) : primary.playerCareer(id);
  @override
  Future<Fresh<List<Transfer>>> playerTransfers(int id) => FootballDataSource.owns(id) ? Future.value(_empty(const <Transfer>[])) : primary.playerTransfers(id);

  @override
  Future<Fresh<List<SearchHit>>> searchTeams(String q) => primary.searchTeams(q);
  @override
  Future<Fresh<List<SearchHit>>> searchPlayers(String q) => primary.searchPlayers(q);
}
