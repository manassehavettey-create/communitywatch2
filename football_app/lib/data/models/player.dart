import 'common.dart';

/// A bag of player statistics used for a single match, a season, or an
/// aggregate (career / last N). Null = not provided (hidden in UI).
class PlayerStatLine {
  const PlayerStatLine({
    this.appearances,
    this.lineups,
    this.minutes,
    this.rating,
    this.goals,
    this.assists,
    this.conceded,
    this.saves,
    this.cleanSheets,
    this.shots,
    this.shotsOn,
    this.passes,
    this.keyPasses,
    this.passAccuracy,
    this.tackles,
    this.interceptions,
    this.blocks,
    this.duels,
    this.duelsWon,
    this.dribbles,
    this.dribblesWon,
    this.foulsDrawn,
    this.foulsCommitted,
    this.yellow,
    this.red,
    this.penaltiesScored,
    this.penaltiesMissed,
    this.xg,
    this.xa,
  });

  final int? appearances;
  final int? lineups;
  final int? minutes;

  /// Provider rating (official provider figure, never app-computed for a
  /// single match). For aggregates it's the appearance-weighted mean.
  final double? rating;
  final int? goals;
  final int? assists;
  final int? conceded;
  final int? saves;
  final int? cleanSheets;
  final int? shots;
  final int? shotsOn;
  final int? passes;
  final int? keyPasses;

  /// 0–100
  final double? passAccuracy;
  final int? tackles;
  final int? interceptions;
  final int? blocks;
  final int? duels;
  final int? duelsWon;
  final int? dribbles;
  final int? dribblesWon;
  final int? foulsDrawn;
  final int? foulsCommitted;
  final int? yellow;
  final int? red;
  final int? penaltiesScored;
  final int? penaltiesMissed;
  final double? xg;
  final double? xa;

  static const empty = PlayerStatLine();

  /// Aggregate several lines. Counts are summed (null only if every input is
  /// null); rating is weighted by appearances; pass accuracy by passes.
  static PlayerStatLine sum(Iterable<PlayerStatLine> lines) {
    final l = lines.toList();
    if (l.isEmpty) return empty;
    int? s(int? Function(PlayerStatLine) f) {
      int? acc;
      for (final x in l) {
        final v = f(x);
        if (v != null) acc = (acc ?? 0) + v;
      }
      return acc;
    }

    double? sd(double? Function(PlayerStatLine) f) {
      double? acc;
      for (final x in l) {
        final v = f(x);
        if (v != null) acc = (acc ?? 0) + v;
      }
      return acc;
    }

    double? weighted(double? Function(PlayerStatLine) value, num? Function(PlayerStatLine) weight) {
      double total = 0, w = 0;
      for (final x in l) {
        final v = value(x);
        if (v == null) continue;
        final wt = (weight(x) ?? 1).toDouble();
        if (wt <= 0) continue;
        total += v * wt;
        w += wt;
      }
      return w == 0 ? null : total / w;
    }

    return PlayerStatLine(
      appearances: s((x) => x.appearances),
      lineups: s((x) => x.lineups),
      minutes: s((x) => x.minutes),
      rating: weighted((x) => x.rating, (x) => x.appearances ?? 1),
      goals: s((x) => x.goals),
      assists: s((x) => x.assists),
      conceded: s((x) => x.conceded),
      saves: s((x) => x.saves),
      cleanSheets: s((x) => x.cleanSheets),
      shots: s((x) => x.shots),
      shotsOn: s((x) => x.shotsOn),
      passes: s((x) => x.passes),
      keyPasses: s((x) => x.keyPasses),
      passAccuracy: weighted((x) => x.passAccuracy, (x) => x.passes ?? 1),
      tackles: s((x) => x.tackles),
      interceptions: s((x) => x.interceptions),
      blocks: s((x) => x.blocks),
      duels: s((x) => x.duels),
      duelsWon: s((x) => x.duelsWon),
      dribbles: s((x) => x.dribbles),
      dribblesWon: s((x) => x.dribblesWon),
      foulsDrawn: s((x) => x.foulsDrawn),
      foulsCommitted: s((x) => x.foulsCommitted),
      yellow: s((x) => x.yellow),
      red: s((x) => x.red),
      penaltiesScored: s((x) => x.penaltiesScored),
      penaltiesMissed: s((x) => x.penaltiesMissed),
      xg: sd((x) => x.xg),
      xa: sd((x) => x.xa),
    );
  }
}

/// One player's line in one match.
class PlayerMatchLine {
  const PlayerMatchLine({required this.player, required this.teamId, this.number, this.position, this.captain = false, this.substitute = false, required this.stats});
  final PlayerRef player;
  final int teamId;
  final int? number;

  /// G / D / M / F
  final String? position;
  final bool captain;
  final bool substitute;
  final PlayerStatLine stats;
}

enum PositionGroup { goalkeeper, defender, midfielder, forward, unknown }

PositionGroup positionGroupOf(String? raw) {
  final p = (raw ?? '').toLowerCase();
  if (p.startsWith('g')) return PositionGroup.goalkeeper;
  if (p.startsWith('d')) return PositionGroup.defender;
  if (p.startsWith('m')) return PositionGroup.midfielder;
  if (p.startsWith('f') || p.startsWith('a') || p.startsWith('s')) return PositionGroup.forward;
  return PositionGroup.unknown;
}

extension PositionGroupX on PositionGroup {
  String get label => switch (this) {
        PositionGroup.goalkeeper => 'Goalkeeper',
        PositionGroup.defender => 'Defender',
        PositionGroup.midfielder => 'Midfielder',
        PositionGroup.forward => 'Forward',
        PositionGroup.unknown => 'Player',
      };
  String get plural => switch (this) {
        PositionGroup.goalkeeper => 'Goalkeepers',
        PositionGroup.defender => 'Defenders',
        PositionGroup.midfielder => 'Midfielders',
        PositionGroup.forward => 'Forwards',
        PositionGroup.unknown => 'Others',
      };
  String get abbr => switch (this) {
        PositionGroup.goalkeeper => 'GK',
        PositionGroup.defender => 'DEF',
        PositionGroup.midfielder => 'MID',
        PositionGroup.forward => 'FWD',
        PositionGroup.unknown => '—',
      };
}

class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.name,
    this.firstname,
    this.lastname,
    this.age,
    this.birthDate,
    this.birthPlace,
    this.birthCountry,
    this.nationality,
    this.height,
    this.weight,
    this.photo,
    this.position,
    this.number,
    this.injured,
    this.team,
  });
  final int id;
  final String name;
  final String? firstname;
  final String? lastname;
  final int? age;
  final DateTime? birthDate;
  final String? birthPlace;
  final String? birthCountry;
  final String? nationality;
  final String? height;
  final String? weight;
  final String? photo;
  final String? position;
  final int? number;
  final bool? injured;
  final TeamRef? team;

  PlayerRef get ref => PlayerRef(id: id, name: name, photo: photo);
  PositionGroup get group => positionGroupOf(position);

  PlayerProfile withSeasonInfo({String? position, int? number, TeamRef? team}) => PlayerProfile(
        id: id,
        name: name,
        firstname: firstname,
        lastname: lastname,
        age: age,
        birthDate: birthDate,
        birthPlace: birthPlace,
        birthCountry: birthCountry,
        nationality: nationality,
        height: height,
        weight: weight,
        photo: photo,
        position: this.position ?? position,
        number: this.number ?? number,
        injured: injured,
        team: this.team ?? team,
      );
}

/// A player's stats for one team+competition in one season.
class PlayerSeason {
  const PlayerSeason({required this.season, required this.team, required this.league, this.position, this.number, this.captain = false, required this.stats});
  final int season;
  final TeamRef team;
  final LeagueRef league;
  final String? position;
  final int? number;
  final bool captain;
  final PlayerStatLine stats;
}

/// Profile + season lines, as returned by leaderboards and player lookups.
class PlayerWithSeasons {
  const PlayerWithSeasons(this.profile, this.seasons);
  final PlayerProfile profile;
  final List<PlayerSeason> seasons;

  PlayerStatLine get total => PlayerStatLine.sum(seasons.map((s) => s.stats));

  /// Team with most appearances this season.
  TeamRef? get mainTeam {
    if (seasons.isEmpty) return profile.team;
    final sorted = [...seasons]..sort((a, b) => (b.stats.appearances ?? 0).compareTo(a.stats.appearances ?? 0));
    return sorted.first.team;
  }
}

class CareerEntry {
  const CareerEntry({required this.team, required this.seasons, this.isNational = false});
  final TeamRef team;
  final List<int> seasons;
  final bool isNational;
}

class SquadPlayer {
  const SquadPlayer({required this.id, required this.name, this.age, this.number, this.position, this.photo});
  final int id;
  final String name;
  final int? age;
  final int? number;
  final String? position;
  final String? photo;
  PositionGroup get group => positionGroupOf(position);
}

class Transfer {
  const Transfer({required this.player, this.date, required this.from, required this.to, this.fee, this.provenance = Provenance.confirmed, this.source});
  final PlayerRef player;
  final DateTime? date;
  final TeamRef from;
  final TeamRef to;

  /// Fee/type text exactly as supplied by the provider ("€ 80M", "Loan",
  /// "Free"). Null/"N/A" → hidden.
  final String? fee;
  final Provenance provenance;
  final String? source;
}
