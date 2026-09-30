import '../core/utils/format.dart';
import '../data/models/models.dart';

/// What the user saw last time they looked at a match (persisted locally).
class SeenSnapshot {
  const SeenSnapshot({required this.minute, required this.eventKeys, this.homeShots, this.awayShots, this.homeGoals, this.awayGoals});
  final int minute;
  final Set<String> eventKeys;
  final int? homeShots;
  final int? awayShots;
  final int? homeGoals;
  final int? awayGoals;

  factory SeenSnapshot.of(Match m) => SeenSnapshot(
        minute: m.status.elapsed ?? 0,
        eventKeys: {for (final e in m.events ?? const <MatchEvent>[]) e.key},
        homeShots: m.stats?[StatKey.shotsTotal]?.home?.toInt(),
        awayShots: m.stats?[StatKey.shotsTotal]?.away?.toInt(),
        homeGoals: m.homeGoals,
        awayGoals: m.awayGoals,
      );

  Map<String, dynamic> toJson() => {'m': minute, 'k': eventKeys.toList(), 'hs': homeShots, 'as': awayShots, 'hg': homeGoals, 'ag': awayGoals};

  static SeenSnapshot? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return SeenSnapshot(
      minute: (j['m'] as num?)?.toInt() ?? 0,
      eventKeys: {...(j['k'] as List? ?? const []).map((e) => '$e')},
      homeShots: (j['hs'] as num?)?.toInt(),
      awayShots: (j['as'] as num?)?.toInt(),
      homeGoals: (j['hg'] as num?)?.toInt(),
      awayGoals: (j['ag'] as num?)?.toInt(),
    );
  }
}

class CatchUpSummary {
  const CatchUpSummary({required this.headline, required this.bullets, required this.scoreLine, required this.sinceMinute});
  final String headline;
  final List<String> bullets;
  final String scoreLine;
  final int? sinceMinute;
}

/// "What Just Happened?" (spec §28). Built exclusively from confirmed match
/// events and statistics — no inference beyond counting and ordering.
///
/// * First visit to a live match → "You joined at 72'" with everything so far.
/// * Returning visit → only what changed since [seen].
/// Returns null when there is nothing worth summarising.
CatchUpSummary? buildCatchUp(Match match, {SeenSnapshot? seen, int minMinuteForFirstVisit = 5}) {
  if (!match.status.isLive && !match.status.isFinished) return null;
  final minute = match.status.elapsed ?? 0;
  final events = match.sortedEvents;
  final newEvents = seen == null ? events : events.where((e) => !seen.eventKeys.contains(e.key)).toList();

  if (seen == null && minute < minMinuteForFirstVisit && events.isEmpty) return null;
  if (seen != null && newEvents.isEmpty && (match.status.elapsed ?? 0) - seen.minute < 10) return null;

  String teamName(int id) => match.teamById(id)?.name ?? 'A team';
  String who(MatchEvent e) => e.playerName ?? 'a player';
  String at(MatchEvent e) => 'at ${e.minuteLabel}';

  final bullets = <String>[];
  final yellows = newEvents.where((e) => e.kind == EventKind.yellow).toList();
  final subs = newEvents.where((e) => e.kind == EventKind.sub).toList();

  for (final e in newEvents) {
    switch (e.kind) {
      case EventKind.goal:
        final assist = e.relatedName != null ? ', assisted by ${e.relatedName}' : '';
        bullets.add('${teamName(e.teamId)} scored through ${who(e)} in the ${ordinal(e.minute)} minute$assist.');
      case EventKind.penaltyGoal:
        bullets.add('${who(e)} scored a penalty for ${teamName(e.teamId)} ${at(e)}.');
      case EventKind.ownGoal:
        bullets.add('An own goal by ${who(e)} ${at(e)}.');
      case EventKind.missedPenalty:
        bullets.add('${who(e)} missed a penalty for ${teamName(e.teamId)} ${at(e)}.');
      case EventKind.red:
        bullets.add('${who(e)} (${teamName(e.teamId)}) was sent off ${at(e)}.');
      case EventKind.secondYellow:
        bullets.add('${who(e)} (${teamName(e.teamId)}) was sent off for a second booking ${at(e)}.');
      case EventKind.varDecision:
        bullets.add('VAR: ${e.detail.isEmpty ? 'decision reviewed' : e.detail} ${at(e)}.');
      case EventKind.yellow:
        if (yellows.length <= 3) bullets.add('${teamName(e.teamId)} received a yellow card ${at(e)} (${who(e)}).');
      case EventKind.sub:
      case EventKind.other:
        break;
    }
  }

  if (yellows.length > 3) {
    final h = yellows.where((e) => e.teamId == match.home.id).length;
    final a = yellows.length - h;
    bullets.add('${yellows.length} yellow cards shown (${match.home.name} $h, ${match.away.name} $a).');
  }
  if (subs.isNotEmpty) {
    bullets.add(subs.length == 1
        ? '${teamName(subs.first.teamId)} made a substitution: ${subs.first.playerName ?? 'a player'} on${subs.first.relatedName != null ? ' for ${subs.first.relatedName}' : ''}.'
        : '${subs.length} substitutions made.');
  }

  // Statistics — only when the provider supplied them.
  final shots = match.stats?[StatKey.shotsTotal];
  if (shots != null && shots.home != null && shots.away != null) {
    if (seen?.homeShots != null && seen?.awayShots != null) {
      final dh = shots.home!.toInt() - seen!.homeShots!;
      final da = shots.away!.toInt() - seen.awayShots!;
      if (dh > 0 || da > 0) {
        if (dh > 0 && da == 0) {
          bullets.add('${match.home.name} have had $dh shot${dh == 1 ? '' : 's'} since you left; ${match.away.name} none.');
        } else if (da > 0 && dh == 0) {
          bullets.add('${match.away.name} have had $da shot${da == 1 ? '' : 's'} since you left; ${match.home.name} none.');
        } else {
          bullets.add('Shots since you left: ${match.home.name} $dh, ${match.away.name} $da.');
        }
      }
    } else if (seen == null) {
      bullets.add('Shots so far: ${match.home.name} ${shots.home} – ${shots.away} ${match.away.name}.');
    }
  }
  final pos = match.stats?[StatKey.possession];
  if (seen == null && pos?.home != null && pos?.away != null) {
    final h = pos!.home!.toDouble();
    if (h >= 58) bullets.add('${match.home.name} have had ${h.round()}% of the ball.');
    if (h <= 42) bullets.add('${match.away.name} have had ${pos.away!.round()}% of the ball.');
  }

  if (bullets.isEmpty) {
    if (seen != null) return null;
    bullets.add('No goals or cards yet.');
  }

  final hg = match.homeGoals ?? 0, ag = match.awayGoals ?? 0;
  final state = match.status.isFinished ? 'Full time' : (match.status.short == 'HT' ? 'Half-time' : 'Now ${match.status.minuteLabel}');
  final scoreLine = hg == ag
      ? (hg == 0 ? '$state: still goalless.' : '$state: level at $hg–$ag.')
      : '$state: ${hg > ag ? match.home.name : match.away.name} lead ${hg > ag ? '$hg–$ag' : '$ag–$hg'}.';

  final headline = seen == null ? "You joined at ${match.status.isFinished ? 'full time' : match.status.minuteLabel}" : "Since you left at ${seen.minute}'";
  return CatchUpSummary(headline: headline, bullets: bullets, scoreLine: match.status.isFinished ? scoreLine.replaceFirst('lead', 'won') : scoreLine, sinceMinute: seen?.minute);
}
