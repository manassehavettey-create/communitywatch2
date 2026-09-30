import '../data/models/models.dart';

// ── League table zones ─────────────────────────────────────────────────────

enum ZoneKind { champions, europa, conference, promotion, playoff, relegation, other }

class Zone {
  const Zone(this.kind, this.label);
  final ZoneKind kind;

  /// Provider text, shown verbatim in the legend.
  final String label;
}

/// Classifies a provider zone description for colour only. Which rows are in
/// a zone comes entirely from the provider (spec §22) — nothing is inferred
/// from rank.
Zone? zoneFor(String? description) {
  final d = description?.trim();
  if (d == null || d.isEmpty) return null;
  final l = d.toLowerCase();
  final kind = l.contains('relegation')
      ? ZoneKind.relegation
      : l.contains('champions league')
          ? ZoneKind.champions
          : l.contains('europa league') && !l.contains('conference')
              ? ZoneKind.europa
              : l.contains('conference')
                  ? ZoneKind.conference
                  : (l.contains('play-off') || l.contains('playoff') || l.contains('play off'))
                      ? ZoneKind.playoff
                      : (l.contains('promotion') || l.contains('qualif') || l.contains('next round') || l.contains('knockout') || l.contains('1/8'))
                          ? ZoneKind.promotion
                          : ZoneKind.other;
  return Zone(kind, d);
}

/// Distinct zones in table order (for the legend).
List<Zone> legendFor(StandingsTable t) {
  final seen = <String>{};
  final out = <Zone>[];
  for (final g in t.groups) {
    for (final r in g.rows) {
      final z = zoneFor(r.description);
      if (z != null && seen.add(z.label)) out.add(z);
    }
  }
  return out;
}

// ── Head-to-head ───────────────────────────────────────────────────────────

H2HSummary summarizeH2H(List<Match> meetings, TeamRef a, TeamRef b) {
  var wa = 0, wb = 0, d = 0, ga = 0, gb = 0;
  DateTime? from, to;
  for (final m in meetings.where((m) => m.status.isFinished)) {
    final r = m.resultFor(a.id);
    if (r == 'W') wa++;
    if (r == 'L') wb++;
    if (r == 'D') d++;
    ga += (m.isHome(a.id) ? m.homeGoals : m.awayGoals) ?? 0;
    gb += (m.isHome(a.id) ? m.awayGoals : m.homeGoals) ?? 0;
    if (from == null || m.kickoff.isBefore(from)) from = m.kickoff;
    if (to == null || m.kickoff.isAfter(to)) to = m.kickoff;
  }
  return H2HSummary(teamA: a, teamB: b, winsA: wa, winsB: wb, draws: d, goalsA: ga, goalsB: gb, from: from, to: to, count: wa + wb + d);
}

// ── Explain a statistic (spec §45 "Ask/Explain") ─────────────────────────────

String statDefinition(StatKey k) => switch (k) {
      StatKey.possession => 'Share of the time each team had the ball.',
      StatKey.xg => 'Expected goals: the probability each shot becomes a goal, added up. It measures chance quality, not luck.',
      StatKey.xa => 'Expected assists: the xG value of shots created by a player\'s passes.',
      StatKey.shotsTotal => 'Every attempt at goal, on target or not, including blocked shots.',
      StatKey.shotsOn => 'Shots that would have gone in without a save by the goalkeeper.',
      StatKey.shotsOff => 'Shots that missed the target.',
      StatKey.shotsBlocked => 'Shots stopped by an outfield player before reaching goal.',
      StatKey.shotsInside => 'Shots taken from inside the penalty area — usually the better chances.',
      StatKey.shotsOutside => 'Long-range shots from outside the penalty area.',
      StatKey.bigChances => 'Situations where a player should reasonably be expected to score.',
      StatKey.corners => 'Corner kicks won.',
      StatKey.fouls => 'Fouls committed.',
      StatKey.offsides => 'Times caught offside.',
      StatKey.passes => 'Total passes attempted.',
      StatKey.passesAccurate => 'Passes that reached a teammate.',
      StatKey.passAccuracy => 'Percentage of passes that reached a teammate.',
      StatKey.yellow => 'Yellow cards shown.',
      StatKey.red => 'Red cards shown (including second yellows).',
      StatKey.saves => 'Shots on target stopped by the goalkeeper.',
      StatKey.progressivePasses => 'Passes that move the ball significantly towards the opponent\'s goal.',
      StatKey.duelsWon => 'One-on-one contests for the ball won (ground and aerial).',
      StatKey.tackles => 'Tackles made to win the ball from an opponent.',
      StatKey.interceptions => 'Opponent passes read and cut out.',
      StatKey.crosses => 'Balls delivered from wide areas into the box.',
      StatKey.dribbles => 'Successful attempts to beat an opponent with the ball.',
      StatKey.keyPasses => 'Passes that led directly to a shot.',
      StatKey.goalsPrevented => 'Goals a goalkeeper saved compared with the expected outcome of the shots faced.',
    };

/// A short, factual reading of the numbers (app-generated, labelled as such).
String? statContext(StatKey k, StatPair p, String home, String away) {
  final h = p.home?.toDouble(), a = p.away?.toDouble();
  if (h == null || a == null) return null;
  final leader = h > a ? home : away;
  final hi = h > a ? h : a, lo = h > a ? a : h;
  if (h == a) return 'Both teams are level on this.';
  switch (k) {
    case StatKey.possession:
      if (hi >= 60) return '$leader have had most of the ball (${hi.round()}%).';
      return 'Possession has been fairly even (${h.round()}% – ${a.round()}%).';
    case StatKey.xg:
      return '$leader have created the better chances (${hi.toStringAsFixed(2)} xG vs ${lo.toStringAsFixed(2)}).';
    case StatKey.shotsOn:
    case StatKey.shotsTotal:
      final ratio = lo == 0 ? null : hi / lo;
      if (ratio != null && ratio >= 2) return '$leader have had more than twice as many (${hi.round()} vs ${lo.round()}).';
      return '$leader lead this ${hi.round()}–${lo.round()}.';
    case StatKey.passAccuracy:
      return '$leader have been more accurate in possession (${hi.round()}% vs ${lo.round()}%).';
    default:
      return '$leader lead this ${_fmt(k, hi)}–${_fmt(k, lo)}.';
  }
}

String _fmt(StatKey k, double v) => k.unit == StatUnit.decimal ? v.toStringAsFixed(2) : v.round().toString();
