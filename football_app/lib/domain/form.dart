import '../data/models/models.dart';

enum FormResult { win, draw, loss }

extension FormResultX on FormResult {
  String get letter => switch (this) { FormResult.win => 'W', FormResult.draw => 'D', FormResult.loss => 'L' };
  int get points => switch (this) { FormResult.win => 3, FormResult.draw => 1, FormResult.loss => 0 };
}

class FormEntry {
  const FormEntry(this.match, this.result);
  final Match match;
  final FormResult result;
}

/// Team form from finished matches, most recent LAST (reads left→right in
/// time, like "W W D W L"). Uses provider winner flags so extra-time and
/// penalty results are classified correctly.
List<FormEntry> recentForm(Iterable<Match> matches, int teamId, {int count = 5, DateTime? before}) {
  final finished = matches.where((m) => m.involves(teamId) && m.status.isFinished && (before == null || m.kickoff.isBefore(before))).toList()
    ..sort((a, b) => b.kickoff.compareTo(a.kickoff));
  final out = <FormEntry>[];
  for (final m in finished) {
    final r = switch (m.resultFor(teamId)) { 'W' => FormResult.win, 'D' => FormResult.draw, 'L' => FormResult.loss, _ => null };
    if (r == null) continue;
    out.add(FormEntry(m, r));
    if (out.length == count) break;
  }
  return out.reversed.toList();
}

String formString(Iterable<Match> matches, int teamId, {int count = 5}) => recentForm(matches, teamId, count: count).map((e) => e.result.letter).join();

/// Parse a provider form string like "WWDLW" (oldest → newest).
List<FormResult> parseFormString(String? s) => [
      for (final ch in (s ?? '').toUpperCase().split(''))
        if (ch == 'W') FormResult.win else if (ch == 'D') FormResult.draw else if (ch == 'L') FormResult.loss,
    ];

class FormSummary {
  const FormSummary({required this.wins, required this.draws, required this.losses, required this.goalsFor, required this.goalsAgainst});
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  int get points => wins * 3 + draws;
  int get played => wins + draws + losses;
}

FormSummary summarizeForm(List<FormEntry> entries, int teamId) {
  var w = 0, d = 0, l = 0, gf = 0, ga = 0;
  for (final e in entries) {
    switch (e.result) {
      case FormResult.win:
        w++;
      case FormResult.draw:
        d++;
      case FormResult.loss:
        l++;
    }
    final home = e.match.isHome(teamId);
    gf += (home ? e.match.homeGoals : e.match.awayGoals) ?? 0;
    ga += (home ? e.match.awayGoals : e.match.homeGoals) ?? 0;
  }
  return FormSummary(wins: w, draws: d, losses: l, goalsFor: gf, goalsAgainst: ga);
}
