import '../data/models/models.dart';

enum ChangeKind { kickoff, goal, halftime, secondHalf, fulltime, redCard, substitution, varDecision, missedPenalty, lineups }

class MatchChange {
  const MatchChange(this.kind, this.match, {this.event, this.scoringTeamId});
  final ChangeKind kind;
  final Match match;
  final MatchEvent? event;

  /// For goals detected from a score change without an event.
  final int? scoringTeamId;

  int? get teamId => event?.teamId ?? scoringTeamId;

  /// Stable key for notification de-duplication.
  String get key => '${match.id}:${kind.name}:${event?.key ?? '${match.homeGoals}-${match.awayGoals}'}';

  String get title {
    final m = match;
    final score = '${m.home.name} ${m.homeGoals ?? 0}–${m.awayGoals ?? 0} ${m.away.name}';
    return switch (kind) {
      ChangeKind.goal => 'GOAL · $score',
      ChangeKind.kickoff => 'Kick-off · ${m.home.name} vs ${m.away.name}',
      ChangeKind.halftime => 'Half-time · $score',
      ChangeKind.secondHalf => 'Second half · $score',
      ChangeKind.fulltime => 'Full-time · $score',
      ChangeKind.redCard => 'Red card · ${m.home.name} vs ${m.away.name}',
      ChangeKind.substitution => 'Substitution · ${m.home.name} vs ${m.away.name}',
      ChangeKind.varDecision => 'VAR · ${m.home.name} vs ${m.away.name}',
      ChangeKind.missedPenalty => 'Penalty missed · ${m.home.name} vs ${m.away.name}',
      ChangeKind.lineups => 'Lineups · ${m.home.name} vs ${m.away.name}',
    };
  }

  String get body {
    final e = event;
    final team = teamId == null ? null : match.teamById(teamId!)?.name;
    return switch (kind) {
      ChangeKind.goal when e != null => "${e.minuteLabel} ${e.playerName ?? team ?? ''}${e.kind == EventKind.penaltyGoal ? ' (pen)' : e.kind == EventKind.ownGoal ? ' (OG)' : ''}${e.relatedName != null && e.kind == EventKind.goal ? ' · assist ${e.relatedName}' : ''}",
      ChangeKind.goal => '${team ?? 'Goal'} scores${match.status.elapsed != null ? " · ${match.status.elapsed}'" : ''}',
      ChangeKind.redCard => '${e?.minuteLabel ?? ''} ${e?.playerName ?? ''} (${team ?? ''}) is sent off',
      ChangeKind.substitution => '${e?.minuteLabel ?? ''} ${e?.playerName ?? ''} on${e?.relatedName != null ? ' for ${e!.relatedName}' : ''} (${team ?? ''})',
      ChangeKind.varDecision => '${e?.minuteLabel ?? ''} ${e?.detail ?? ''}',
      ChangeKind.missedPenalty => '${e?.minuteLabel ?? ''} ${e?.playerName ?? ''} misses from the spot',
      ChangeKind.kickoff => match.league.name,
      ChangeKind.lineups => 'Official lineups are out',
      _ => match.league.name,
    };
  }
}

/// Changes between two observations of the same match. Only reports what the
/// provider confirmed; the first observation ([before] == null) yields
/// nothing so opening the app never fires a burst of stale alerts.
List<MatchChange> diffMatch(Match? before, Match after) {
  if (before == null || before.id != after.id) return const [];
  final out = <MatchChange>[];
  final b = before.status, a = after.status;

  if (b.isScheduled && a.isLive) out.add(MatchChange(ChangeKind.kickoff, after));
  if (b.short != 'HT' && a.short == 'HT') out.add(MatchChange(ChangeKind.halftime, after));
  if (b.short == 'HT' && a.short == '2H') out.add(MatchChange(ChangeKind.secondHalf, after));
  if (!b.isFinished && a.isFinished) out.add(MatchChange(ChangeKind.fulltime, after));

  final hadLineups = (before.lineups?.isNotEmpty ?? false);
  if (!hadLineups && (after.lineups?.isNotEmpty ?? false)) out.add(MatchChange(ChangeKind.lineups, after));

  final seen = {for (final e in before.events ?? const <MatchEvent>[]) e.key};
  var goalEvents = 0;
  // Only diff events when both observations carry an event feed; otherwise
  // (e.g. first detail load after a list item) every event would look new.
  if (after.events != null && before.events != null) {
    for (final e in after.sortedEvents.where((e) => !seen.contains(e.key))) {
      final kind = switch (e.kind) {
        EventKind.goal || EventKind.ownGoal || EventKind.penaltyGoal => ChangeKind.goal,
        EventKind.red || EventKind.secondYellow => ChangeKind.redCard,
        EventKind.sub => ChangeKind.substitution,
        EventKind.varDecision => ChangeKind.varDecision,
        EventKind.missedPenalty => ChangeKind.missedPenalty,
        _ => null,
      };
      if (kind == null) continue;
      if (kind == ChangeKind.goal) goalEvents++;
      out.add(MatchChange(kind, after, event: e));
    }
  }

  // Score went up but the event feed hasn't caught up yet: report the goal
  // from the score itself (confirmed), attributing only the team.
  final dh = (after.homeGoals ?? 0) - (before.homeGoals ?? 0);
  final da = (after.awayGoals ?? 0) - (before.awayGoals ?? 0);
  if (goalEvents == 0) {
    if (dh > 0) out.add(MatchChange(ChangeKind.goal, after, scoringTeamId: after.home.id));
    if (da > 0) out.add(MatchChange(ChangeKind.goal, after, scoringTeamId: after.away.id));
  }
  return out;
}

/// Which side's score just increased (for the goal celebration).
int? scoringSide(Match? before, Match after) {
  if (before == null) return null;
  if ((after.homeGoals ?? 0) > (before.homeGoals ?? 0)) return after.home.id;
  if ((after.awayGoals ?? 0) > (before.awayGoals ?? 0)) return after.away.id;
  return null;
}
