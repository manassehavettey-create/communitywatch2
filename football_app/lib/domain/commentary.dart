import '../core/utils/format.dart';
import '../data/models/models.dart';

/// Builds a play-by-play feed from confirmed events when the provider has no
/// written commentary. The *text* is app-generated (labelled in the UI); every
/// fact in it comes from a confirmed event or status. Phrasing is chosen
/// deterministically from the event key so it never flickers between polls.
List<CommentaryLine> commentaryFromEvents(Match m) {
  final lines = <CommentaryLine>[];
  String team(int id) => m.teamById(id)?.name ?? '';
  String pick(String key, List<String> options) => options[key.hashCode.abs() % options.length];

  if (!m.status.isScheduled) {
    lines.add(CommentaryLine(minute: 0, text: 'Kick-off. ${m.home.name} vs ${m.away.name}${m.venue != null ? ' at ${m.venue}' : ''} is under way.'));
  }

  for (final e in m.sortedEvents) {
    final p = e.playerName ?? 'A player';
    final t = team(e.teamId);
    final text = switch (e.kind) {
      EventKind.goal => pick(e.key, [
          '$p scores for $t!${e.relatedName != null ? ' Set up by ${e.relatedName}.' : ''}',
          'GOAL! $p finds the net for $t.${e.relatedName != null ? ' ${e.relatedName} with the assist.' : ''}',
          '$p puts $t on the scoresheet.${e.relatedName != null ? ' Assist: ${e.relatedName}.' : ''}',
        ]),
      EventKind.penaltyGoal => '$p converts the penalty for $t.',
      EventKind.ownGoal => 'Own goal by $p.',
      EventKind.missedPenalty => '$p misses the penalty for $t.',
      EventKind.yellow => pick(e.key, ['$p ($t) receives a booking.', 'Yellow card for $p ($t).', '$p goes into the book for $t.']) + (e.comment != null ? ' ${e.comment}.' : ''),
      EventKind.secondYellow => 'Second yellow for $p — $t are down to ten.',
      EventKind.red => 'Straight red card! $p ($t) is sent off.${e.comment != null ? ' ${e.comment}.' : ''}',
      EventKind.sub => '${e.playerName ?? 'A substitute'} replaces ${e.relatedName ?? 'a teammate'} for $t.',
      EventKind.varDecision => 'VAR check: ${e.detail.isEmpty ? 'decision under review' : e.detail}.',
      EventKind.other => e.detail,
    };
    lines.add(CommentaryLine(minute: e.minute, extra: e.extra, text: text, kind: e.kind, teamId: e.teamId, playerName: e.playerName));
  }

  final ht = m.halftime;
  final pastHalf = m.status.short == 'HT' || m.status.short == '2H' || m.status.short == 'ET' || m.status.short == 'P' || m.status.isFinished;
  if (pastHalf && ht.isSet) {
    lines.add(CommentaryLine(minute: 45, extra: 99, text: 'Half-time: ${m.home.name} ${ht.home}–${ht.away} ${m.away.name}.'));
  }
  if (m.status.isFinished) {
    lines.add(CommentaryLine(minute: 90, extra: 999, text: 'Full-time: ${m.home.name} ${m.homeGoals}–${m.awayGoals} ${m.away.name}.'));
  }
  lines.sort((a, b) => (a.minute * 1000 + (a.extra ?? 0)).compareTo(b.minute * 1000 + (b.extra ?? 0)));
  return lines.reversed.toList();
}

/// Key moments for the post-match recap (spec §27): goals, red cards, missed
/// penalties and VAR decisions, phrased from confirmed events.
List<String> keyMoments(Match m) {
  final out = <String>[];
  String team(int id) => m.teamById(id)?.name ?? '';
  for (final e in m.sortedEvents) {
    switch (e.kind) {
      case EventKind.goal:
      case EventKind.penaltyGoal:
      case EventKind.ownGoal:
        out.add("${e.minuteLabel} ${e.playerName ?? team(e.teamId)}${e.kind == EventKind.penaltyGoal ? ' (pen)' : e.kind == EventKind.ownGoal ? ' (OG)' : ''} — ${team(e.teamId)}");
      case EventKind.red:
      case EventKind.secondYellow:
        out.add('${e.minuteLabel} Red card: ${e.playerName ?? ''} (${team(e.teamId)})');
      case EventKind.missedPenalty:
        out.add('${e.minuteLabel} Penalty missed by ${e.playerName ?? team(e.teamId)}');
      case EventKind.varDecision:
        out.add('${e.minuteLabel} VAR: ${e.detail}');
      default:
        break;
    }
  }
  final ht = m.halftime;
  if (ht.isSet && m.hasScore) {
    final htLead = (ht.home! - ht.away!).sign;
    final ftLead = (m.homeGoals! - m.awayGoals!).sign;
    if (htLead != ftLead && htLead != 0) {
      out.add('${htLead > 0 ? m.home.name : m.away.name} led ${ht.home}–${ht.away} at half-time but ${ftLead == 0 ? 'were pegged back' : 'lost the lead'}.');
    } else if (htLead == 0 && ftLead != 0 && (ht.home! + ht.away!) >= 0) {
      out.add('Level at the break (${ht.home}–${ht.away}); ${ftLead > 0 ? m.home.name : m.away.name} won the second half.');
    }
  }
  final reds = m.sortedEvents.where((e) => e.isRed).length;
  if (reds >= 2) out.add('$reds red cards in the match.');
  final lastGoal = m.goals.lastOrNull;
  if (lastGoal != null && lastGoal.minute >= 85 && m.status.isFinished) {
    out.add('Late drama: the final goal came in the ${ordinal(lastGoal.minute)} minute.');
  }
  return out;
}
