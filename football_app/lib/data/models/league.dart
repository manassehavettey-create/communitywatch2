import 'common.dart';

class Coverage {
  const Coverage({
    this.events = true,
    this.lineups = true,
    this.fixtureStats = true,
    this.playerStats = true,
    this.standings = true,
    this.players = true,
    this.topScorers = true,
    this.topAssists = true,
    this.injuries = true,
    this.predictions = true,
  });
  final bool events;
  final bool lineups;
  final bool fixtureStats;
  final bool playerStats;
  final bool standings;
  final bool players;
  final bool topScorers;
  final bool topAssists;
  final bool injuries;
  final bool predictions;
}

class SeasonInfo {
  const SeasonInfo({required this.year, this.start, this.end, this.current = false, this.coverage = const Coverage()});
  final int year;
  final DateTime? start;
  final DateTime? end;
  final bool current;
  final Coverage coverage;
}

class LeagueInfo {
  const LeagueInfo({required this.ref, required this.type, required this.seasons});
  final LeagueRef ref;

  /// "League" or "Cup"
  final String type;
  final List<SeasonInfo> seasons;

  SeasonInfo? get currentSeason => seasons.where((s) => s.current).firstOrNull ?? (seasons.isEmpty ? null : (seasons.toList()..sort((a, b) => b.year.compareTo(a.year))).first);
  bool get isCup => type.toLowerCase() == 'cup';
}

enum Trend { up, down, same }

class StandingRow {
  const StandingRow({
    required this.rank,
    required this.team,
    required this.points,
    required this.played,
    required this.win,
    required this.draw,
    required this.lose,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDiff,
    this.form,
    this.description,
    this.group,
    this.trend = Trend.same,
  });
  final int rank;
  final TeamRef team;
  final int points;
  final int played;
  final int win;
  final int draw;
  final int lose;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDiff;
  final String? form;

  /// Provider-supplied zone text, e.g. "Promotion - Champions League (Group
  /// Stage)" or "Relegation - Championship". Zones are derived only from this.
  final String? description;
  final String? group;
  final Trend trend;
}

class StandingsGroup {
  const StandingsGroup(this.name, this.rows);
  final String? name;
  final List<StandingRow> rows;
}

class StandingsTable {
  const StandingsTable({required this.league, required this.season, required this.groups});
  final LeagueRef league;
  final int season;
  final List<StandingsGroup> groups;

  StandingRow? rowFor(int teamId) {
    for (final g in groups) {
      for (final r in g.rows) {
        if (r.team.id == teamId) return r;
      }
    }
    return null;
  }
}

class TeamInfo {
  const TeamInfo({required this.ref, this.country, this.founded, this.national = false, this.code, this.venueName, this.venueCity, this.venueCapacity, this.venueImage});
  final TeamRef ref;
  final String? country;
  final int? founded;
  final bool national;
  final String? code;
  final String? venueName;
  final String? venueCity;
  final int? venueCapacity;
  final String? venueImage;
}

class TeamSeasonStats {
  const TeamSeasonStats({
    required this.league,
    required this.season,
    this.form,
    this.played,
    this.wins,
    this.draws,
    this.losses,
    this.homeRecord,
    this.awayRecord,
    this.goalsFor,
    this.goalsAgainst,
    this.goalsForHome,
    this.goalsForAway,
    this.goalsAgainstHome,
    this.goalsAgainstAway,
    this.cleanSheets,
    this.failedToScore,
    this.yellow,
    this.red,
    this.cardsByPeriod = const {},
    this.formations = const [],
    this.penaltiesScored,
    this.penaltiesMissed,
    this.biggestWin,
    this.biggestLoss,
    this.possession,
    this.shotsPerGame,
    this.xg,
    this.passAccuracy,
  });
  final LeagueRef league;
  final int season;
  final String? form;
  final int? played;
  final int? wins;
  final int? draws;
  final int? losses;

  /// (W, D, L)
  final (int, int, int)? homeRecord;
  final (int, int, int)? awayRecord;
  final int? goalsFor;
  final int? goalsAgainst;
  final int? goalsForHome;
  final int? goalsForAway;
  final int? goalsAgainstHome;
  final int? goalsAgainstAway;
  final int? cleanSheets;
  final int? failedToScore;
  final int? yellow;
  final int? red;

  /// "0-15" → (yellow, red)
  final Map<String, (int, int)> cardsByPeriod;
  final List<(String, int)> formations;
  final int? penaltiesScored;
  final int? penaltiesMissed;
  final String? biggestWin;
  final String? biggestLoss;

  /// Not all providers supply these; null → shown as "not provided".
  final double? possession;
  final double? shotsPerGame;
  final double? xg;
  final double? passAccuracy;
}

enum SearchKind { player, team, league, match }

class SearchHit {
  const SearchHit({required this.kind, required this.id, required this.title, this.subtitle, this.image, this.score = 0});
  final SearchKind kind;
  final int id;
  final String title;
  final String? subtitle;
  final String? image;
  final double score;

  SearchHit withScore(double s) => SearchHit(kind: kind, id: id, title: title, subtitle: subtitle, image: image, score: s);
}

class H2HSummary {
  const H2HSummary({required this.teamA, required this.teamB, required this.winsA, required this.winsB, required this.draws, required this.goalsA, required this.goalsB, this.from, this.to, required this.count});
  final TeamRef teamA;
  final TeamRef teamB;
  final int winsA;
  final int winsB;
  final int draws;
  final int goalsA;
  final int goalsB;
  final DateTime? from;
  final DateTime? to;
  final int count;
}
