import 'models/models.dart';

/// The single abstraction between UI and any sports-data provider.
///
/// Implementations: [ApiFootballRepository] (production) and
/// [DemoRepository] (debug builds only). Swap providers by adding another
/// implementation — no UI code references a provider directly.
///
/// Every call returns [Fresh] so the UI can show last-known state with a
/// "may be delayed" notice when the network is unavailable.
abstract interface class FootballRepository {
  String get providerName;
  ProviderCapabilities get capabilities;
  bool get isDemo;

  // ── Matches ──────────────────────────────────────────────────────────────
  /// All matches in play right now, including their events when the provider
  /// includes them. [force] bypasses the cache TTL (live polling).
  Future<Fresh<List<Match>>> liveMatches({bool force = false});
  Future<Fresh<List<Match>>> matchesOn(DateTime day, {bool force = false});

  /// Full match: events, lineups, statistics and player lines.
  Future<Fresh<Match>> match(int id, {bool force = false});
  Future<Fresh<List<Match>>> matchesByIds(List<int> ids);
  Future<Fresh<MatchAnalytics?>> analytics(int matchId, {bool force = false});
  Future<Fresh<List<Match>>> headToHead(int teamA, int teamB);
  Future<Fresh<List<Injury>>> injuries(int matchId);
  Future<Fresh<Prediction?>> prediction(int matchId);

  // ── Competitions ─────────────────────────────────────────────────────────
  /// Catalogue of competitions with a current season.
  Future<Fresh<List<LeagueInfo>>> leagues();
  Future<Fresh<LeagueInfo?>> league(int id);
  Future<Fresh<StandingsTable?>> standings(int leagueId, int season);
  Future<Fresh<List<Match>>> leagueMatches(int leagueId, int season);
  Future<Fresh<List<PlayerWithSeasons>>> topScorers(int leagueId, int season);
  Future<Fresh<List<PlayerWithSeasons>>> topAssists(int leagueId, int season);
  Future<Fresh<List<TeamRef>>> leagueTeams(int leagueId, int season);

  // ── Teams ────────────────────────────────────────────────────────────────
  Future<Fresh<TeamInfo>> team(int id);
  Future<Fresh<List<LeagueInfo>>> teamLeagues(int teamId);
  Future<Fresh<List<Match>>> teamMatches(int teamId, int season);
  Future<Fresh<TeamSeasonStats?>> teamStats(int teamId, int leagueId, int season);
  Future<Fresh<List<SquadPlayer>>> squad(int teamId);
  Future<Fresh<List<Transfer>>> teamTransfers(int teamId);

  // ── Players ──────────────────────────────────────────────────────────────
  Future<Fresh<PlayerWithSeasons>> player(int id, int season);
  Future<Fresh<List<int>>> playerSeasons(int id);
  Future<Fresh<List<CareerEntry>>> playerCareer(int id);
  Future<Fresh<List<Transfer>>> playerTransfers(int id);

  // ── Search ───────────────────────────────────────────────────────────────
  Future<Fresh<List<SearchHit>>> searchTeams(String query);
  Future<Fresh<List<SearchHit>>> searchPlayers(String query);
}
