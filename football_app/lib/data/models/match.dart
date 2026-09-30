import 'common.dart';
import 'player.dart';

enum MatchPhase { scheduled, live, paused, finished, postponed, cancelled, unknown }

class MatchStatus {
  const MatchStatus({required this.short, this.long = '', this.elapsed, this.extra});
  final String short;
  final String long;
  final int? elapsed;
  final int? extra;

  MatchPhase get phase => switch (short) {
        'TBD' || 'NS' => MatchPhase.scheduled,
        '1H' || '2H' || 'ET' || 'P' || 'LIVE' => MatchPhase.live,
        'HT' || 'BT' || 'INT' || 'SUSP' => MatchPhase.paused,
        'FT' || 'AET' || 'PEN' || 'AWD' || 'WO' => MatchPhase.finished,
        'PST' => MatchPhase.postponed,
        'CANC' || 'ABD' => MatchPhase.cancelled,
        _ => MatchPhase.unknown,
      };

  bool get isLive => phase == MatchPhase.live || phase == MatchPhase.paused;
  bool get isFinished => phase == MatchPhase.finished;
  bool get isScheduled => phase == MatchPhase.scheduled;

  /// Minute label shown on live cards: 78', 45+2', HT, FT…
  String get minuteLabel {
    if (phase == MatchPhase.live && elapsed != null) {
      if (short == 'P') return 'PENS';
      return (extra != null && extra! > 0) ? "$elapsed+$extra'" : "$elapsed'";
    }
    return switch (short) {
      'HT' => 'HT',
      'BT' => 'ET BREAK',
      'FT' => 'FT',
      'AET' => 'AET',
      'PEN' => 'PENS',
      'PST' => 'POSTPONED',
      'CANC' => 'CANCELLED',
      'ABD' => 'ABANDONED',
      'SUSP' => 'SUSPENDED',
      'INT' => 'INTERRUPTED',
      'AWD' => 'AWARDED',
      'WO' => 'WALKOVER',
      _ => short,
    };
  }

  MatchStatus copyWith({String? short, int? elapsed}) => MatchStatus(short: short ?? this.short, long: long, elapsed: elapsed ?? this.elapsed, extra: extra);
}

class ScorePair {
  const ScorePair(this.home, this.away);
  final int? home;
  final int? away;
  bool get isSet => home != null && away != null;
  static const empty = ScorePair(null, null);
}

enum EventKind { goal, ownGoal, penaltyGoal, missedPenalty, yellow, secondYellow, red, sub, varDecision, other }

class MatchEvent {
  const MatchEvent({
    required this.minute,
    this.extra,
    required this.teamId,
    required this.kind,
    this.playerId,
    this.playerName,
    this.relatedId,
    this.relatedName,
    this.detail = '',
    this.comment,
  });

  final int minute;
  final int? extra;
  final int teamId;
  final EventKind kind;

  /// Primary player: scorer, booked player, or — for substitutions — the
  /// player coming ON.
  final int? playerId;
  final String? playerName;

  /// Assist provider for goals; player going OFF for substitutions.
  final int? relatedId;
  final String? relatedName;
  final String detail;
  final String? comment;

  bool get isGoal => kind == EventKind.goal || kind == EventKind.ownGoal || kind == EventKind.penaltyGoal;
  bool get isCard => kind == EventKind.yellow || kind == EventKind.secondYellow || kind == EventKind.red;
  bool get isRed => kind == EventKind.red || kind == EventKind.secondYellow;

  String get minuteLabel => (extra != null && extra! > 0) ? "$minute+$extra'" : "$minute'";
  int get sortKey => minute * 100 + (extra ?? 0);

  /// Stable identity used for animations, notification de-duplication and
  /// "what did I miss" diffs.
  String get key => '$sortKey-${kind.name}-$teamId-${playerId ?? playerName}';
}

class LineupPlayer {
  const LineupPlayer({required this.id, required this.name, this.number, this.pos, this.gridRow, this.gridCol});
  final int id;
  final String name;
  final int? number;

  /// G / D / M / F
  final String? pos;
  final int? gridRow;
  final int? gridCol;
}

class Lineup {
  const Lineup({
    required this.team,
    this.formation,
    required this.startXI,
    required this.substitutes,
    this.coach,
    this.primaryColor,
    this.numberColor,
    this.provenance = Provenance.confirmed,
  });
  final TeamRef team;
  final String? formation;
  final List<LineupPlayer> startXI;
  final List<LineupPlayer> substitutes;
  final String? coach;
  final int? primaryColor;
  final int? numberColor;
  final Provenance provenance;
}

enum StatUnit { count, percent, decimal }

enum StatKey {
  possession('Possession', StatUnit.percent, false),
  xg('Expected goals (xG)', StatUnit.decimal, true),
  shotsTotal('Shots', StatUnit.count, false),
  shotsOn('Shots on target', StatUnit.count, false),
  shotsOff('Shots off target', StatUnit.count, false),
  shotsBlocked('Blocked shots', StatUnit.count, false),
  shotsInside('Shots inside box', StatUnit.count, false),
  shotsOutside('Shots outside box', StatUnit.count, false),
  bigChances('Big chances', StatUnit.count, true),
  corners('Corners', StatUnit.count, false),
  fouls('Fouls', StatUnit.count, false),
  offsides('Offsides', StatUnit.count, false),
  passes('Passes', StatUnit.count, false),
  passesAccurate('Accurate passes', StatUnit.count, false),
  passAccuracy('Pass accuracy', StatUnit.percent, false),
  yellow('Yellow cards', StatUnit.count, false),
  red('Red cards', StatUnit.count, false),
  saves('Goalkeeper saves', StatUnit.count, false),
  xa('Expected assists (xA)', StatUnit.decimal, true),
  progressivePasses('Progressive passes', StatUnit.count, true),
  duelsWon('Duels won', StatUnit.count, true),
  tackles('Tackles', StatUnit.count, true),
  interceptions('Interceptions', StatUnit.count, true),
  crosses('Crosses', StatUnit.count, true),
  dribbles('Successful dribbles', StatUnit.count, true),
  keyPasses('Key passes', StatUnit.count, true),
  goalsPrevented('Goals prevented', StatUnit.decimal, true);

  const StatKey(this.label, this.unit, this.advanced);
  final String label;
  final StatUnit unit;
  final bool advanced;
}

class StatPair {
  const StatPair(this.home, this.away);
  final num? home;
  final num? away;
  bool get isEmpty => home == null && away == null;
}

class MatchStats {
  const MatchStats(this.values, {this.derivedKeys = const {}});
  final Map<StatKey, StatPair> values;

  /// Keys computed by summing official per-player statistics (shown with a
  /// "Σ player stats" note rather than presented as provider team totals).
  final Set<StatKey> derivedKeys;

  StatPair? operator [](StatKey k) {
    final v = values[k];
    return (v == null || v.isEmpty) ? null : v;
  }

  bool get isEmpty => values.values.every((v) => v.isEmpty);
}

/// Optional advanced analytics — only provided by capable providers.
class MomentumPoint {
  const MomentumPoint(this.minute, this.value);
  final int minute;

  /// -100 (away dominance) … +100 (home dominance)
  final double value;
}

enum ShotOutcome { goal, saved, missed, blocked, post }

class ShotEvent {
  const ShotEvent({required this.minute, required this.teamId, required this.playerId, required this.playerName, required this.x, required this.y, this.xg, required this.outcome});
  final int minute;
  final int teamId;
  final int playerId;
  final String playerName;

  /// Normalised pitch coordinates for the attacking team: x 0 (own goal) → 1
  /// (opponent goal), y 0 (left touchline) → 1.
  final double x;
  final double y;
  final double? xg;
  final ShotOutcome outcome;
}

class PitchPoint {
  const PitchPoint(this.x, this.y, [this.weight = 1]);
  final double x;
  final double y;
  final double weight;
}

class PassEvent {
  const PassEvent(this.teamId, this.playerId, this.from, this.to, this.completed);
  final int teamId;
  final int playerId;
  final PitchPoint from;
  final PitchPoint to;
  final bool completed;
}

class MatchAnalytics {
  const MatchAnalytics({this.momentum = const [], this.shots = const [], this.heat = const {}, this.touches = const {}, this.passes = const [], this.commentary = const []});
  final List<MomentumPoint> momentum;
  final List<ShotEvent> shots;

  /// playerId → heat points (normalised to the player's attacking direction).
  final Map<int, List<PitchPoint>> heat;
  final Map<int, List<PitchPoint>> touches;
  final List<PassEvent> passes;
  final List<CommentaryLine> commentary;
}

class CommentaryLine {
  const CommentaryLine({required this.minute, this.extra, required this.text, this.kind, this.teamId, this.playerName});
  final int minute;
  final int? extra;
  final String text;
  final EventKind? kind;
  final int? teamId;
  final String? playerName;
}

class Match {
  const Match({
    required this.id,
    required this.league,
    required this.home,
    required this.away,
    required this.kickoff,
    required this.status,
    this.homeGoals,
    this.awayGoals,
    this.halftime = ScorePair.empty,
    this.extratime = ScorePair.empty,
    this.penalties = ScorePair.empty,
    this.venue,
    this.city,
    this.referee,
    this.homeWinner,
    this.awayWinner,
    this.events,
    this.lineups,
    this.stats,
    this.players,
  });

  final int id;
  final LeagueRef league;
  final TeamRef home;
  final TeamRef away;
  final DateTime kickoff;
  final MatchStatus status;
  final int? homeGoals;
  final int? awayGoals;
  final ScorePair halftime;
  final ScorePair extratime;
  final ScorePair penalties;
  final String? venue;
  final String? city;
  final String? referee;
  final bool? homeWinner;
  final bool? awayWinner;

  /// Null = not loaded yet; empty = loaded, none available.
  final List<MatchEvent>? events;
  final List<Lineup>? lineups;
  final MatchStats? stats;
  final List<PlayerMatchLine>? players;

  bool get hasScore => homeGoals != null && awayGoals != null;
  String get scoreLabel => hasScore ? '$homeGoals – $awayGoals' : 'vs';

  bool involves(int teamId) => home.id == teamId || away.id == teamId;
  TeamRef? teamById(int id) => home.id == id ? home : (away.id == id ? away : null);
  bool isHome(int teamId) => home.id == teamId;

  /// W / D / L from the perspective of [teamId], or null if not decided.
  /// Uses the provider's winner flags first (they account for AET/penalties).
  String? resultFor(int teamId) {
    if (!status.isFinished || !involves(teamId)) return null;
    final isH = isHome(teamId);
    final myWin = isH ? homeWinner : awayWinner;
    final oppWin = isH ? awayWinner : homeWinner;
    if (myWin == true) return 'W';
    if (oppWin == true) return 'L';
    if (homeGoals == null || awayGoals == null) return null;
    final mine = isH ? homeGoals! : awayGoals!;
    final theirs = isH ? awayGoals! : homeGoals!;
    if (mine > theirs) return 'W';
    if (mine < theirs) return 'L';
    return 'D';
  }

  List<MatchEvent> get sortedEvents => [...?events]..sort((a, b) => a.sortKey.compareTo(b.sortKey));
  List<MatchEvent> get goals => sortedEvents.where((e) => e.isGoal).toList();

  /// Merge lightweight live-list data (score/status/events) into a richer
  /// detail object without dropping lineups/stats already loaded.
  Match mergeLive(Match live) => copyWith(
        status: live.status,
        homeGoals: live.homeGoals,
        awayGoals: live.awayGoals,
        events: live.events ?? events,
        halftime: live.halftime,
        homeWinner: live.homeWinner,
        awayWinner: live.awayWinner,
      );

  Match copyWith({
    MatchStatus? status,
    int? homeGoals,
    int? awayGoals,
    ScorePair? halftime,
    bool? homeWinner,
    bool? awayWinner,
    List<MatchEvent>? events,
    List<Lineup>? lineups,
    MatchStats? stats,
    List<PlayerMatchLine>? players,
  }) =>
      Match(
        id: id,
        league: league,
        home: home,
        away: away,
        kickoff: kickoff,
        status: status ?? this.status,
        homeGoals: homeGoals ?? this.homeGoals,
        awayGoals: awayGoals ?? this.awayGoals,
        halftime: halftime ?? this.halftime,
        extratime: extratime,
        penalties: penalties,
        venue: venue,
        city: city,
        referee: referee,
        homeWinner: homeWinner ?? this.homeWinner,
        awayWinner: awayWinner ?? this.awayWinner,
        events: events ?? this.events,
        lineups: lineups ?? this.lineups,
        stats: stats ?? this.stats,
        players: players ?? this.players,
      );
}

class Injury {
  const Injury({required this.player, required this.teamId, required this.type, required this.reason});
  final PlayerRef player;
  final int teamId;

  /// Provider status, e.g. "Missing Fixture" or "Questionable".
  final String type;
  final String reason;
  bool get isDoubtful => type.toLowerCase().contains('question') || type.toLowerCase().contains('doubt');
}

class Prediction {
  const Prediction({this.homePct, this.drawPct, this.awayPct, this.advice, this.winnerName});
  final double? homePct;
  final double? drawPct;
  final double? awayPct;
  final String? advice;
  final String? winnerName;
}
