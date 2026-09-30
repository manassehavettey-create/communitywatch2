import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/core/utils/fuzzy.dart';
import 'package:touchline/data/api_football/parser.dart';
import 'package:touchline/data/models/models.dart';
import 'package:touchline/domain/catch_up.dart';
import 'package:touchline/domain/form.dart';
import 'package:touchline/domain/match_diff.dart';

import 'fixtures.dart';

const ars = TeamRef(id: 42, name: 'Arsenal');
const che = TeamRef(id: 49, name: 'Chelsea');
const lg = LeagueRef(id: 39, name: 'Premier League');

Match fin(int id, TeamRef h, TeamRef a, int hg, int ag, DateTime at, {bool? hw, bool? aw, String short = 'FT'}) =>
    Match(id: id, league: lg, home: h, away: a, kickoff: at, status: MatchStatus(short: short), homeGoals: hg, awayGoals: ag, homeWinner: hw, awayWinner: aw);

void main() {
  group('form', () {
    final d = DateTime(2026, 8, 1);
    final ms = [
      fin(1, ars, che, 2, 0, d),
      fin(2, che, ars, 1, 1, d.add(const Duration(days: 7))),
      fin(3, ars, che, 0, 1, d.add(const Duration(days: 14))),
      // Penalties: level score but provider says Arsenal won.
      fin(4, che, ars, 1, 1, d.add(const Duration(days: 21)), hw: false, aw: true, short: 'PEN'),
      Match(id: 5, league: lg, home: ars, away: che, kickoff: d.add(const Duration(days: 28)), status: const MatchStatus(short: 'NS')),
    ];

    test('chronological W/D/L from the team perspective, ignoring unplayed', () {
      expect(formString(ms, ars.id), 'WDLW');
      expect(formString(ms, che.id), 'LDWL');
      expect(formString(ms, ars.id, count: 2), 'LW');
    });

    test('summary counts points and goals', () {
      final s = summarizeForm(recentForm(ms, ars.id), ars.id);
      expect((s.wins, s.draws, s.losses, s.points), (2, 1, 1, 7));
      expect((s.goalsFor, s.goalsAgainst), (4, 3));
    });

    test('parses provider form strings', () {
      expect(parseFormString('WDLx').map((e) => e.letter).join(), 'WDL');
    });
  });

  group('What just happened', () {
    final live = ApiFootballParser.fixture(ApiFootballParser.response(fixtureDetailJson).first);

    test('first visit summarises all confirmed events', () {
      final s = buildCatchUp(live)!;
      expect(s.headline, "You joined at 78'");
      expect(s.bullets.first, 'Arsenal scored through B. Saka in the 42nd minute, assisted by M. Odegaard.');
      expect(s.bullets, contains("C. Palmer scored a penalty for Chelsea at 53'."));
      expect(s.bullets, contains("Arsenal received a yellow card at 68' (D. Rice)."));
      expect(s.bullets.any((b) => b.contains('substitution')), isTrue);
      expect(s.bullets, contains('Shots so far: Arsenal 15 – 9 Chelsea.'));
      expect(s.scoreLine, contains('Arsenal lead 2–1'));
    });

    test('returning visit only reports what changed since last seen', () {
      final seen = SeenSnapshot(minute: 55, eventKeys: {for (final e in live.events!.where((e) => e.minute <= 55)) e.key}, homeShots: 10, awayShots: 9);
      final s = buildCatchUp(live, seen: seen)!;
      expect(s.headline, "Since you left at 55'");
      expect(s.bullets.any((b) => b.contains('Saka')), isFalse);
      expect(s.bullets.any((b) => b.contains('Havertz')), isTrue);
      expect(s.bullets, contains('Arsenal have had 5 shots since you left; Chelsea none.'));
    });

    test('nothing new → no card', () {
      final seen = SeenSnapshot.of(live);
      expect(buildCatchUp(live, seen: seen), isNull);
    });

    test('scheduled match → no summary', () {
      expect(buildCatchUp(Match(id: 1, league: lg, home: ars, away: che, kickoff: DateTime(2027), status: const MatchStatus(short: 'NS'))), isNull);
    });
  });

  group('match diff (notifications)', () {
    final live = ApiFootballParser.fixture(ApiFootballParser.response(fixtureDetailJson).first);

    test('first observation fires nothing', () => expect(diffMatch(null, live), isEmpty));

    test('new goal event and full time are detected once', () {
      final before = live.copyWith(events: live.events!.where((e) => e.minute < 61).toList(), homeGoals: 1);
      final after = live.copyWith(status: const MatchStatus(short: 'FT', elapsed: 90));
      final ch = diffMatch(before, after);
      expect(ch.where((c) => c.kind == ChangeKind.goal).single.event!.playerName, 'K. Havertz');
      expect(ch.any((c) => c.kind == ChangeKind.fulltime), isTrue);
      expect(diffMatch(after, after), isEmpty);
    });

    test('score change without event feed still reports the goal (team only)', () {
      final a = fin(9, ars, che, 0, 0, DateTime(2026), short: '1H');
      final b = fin(9, ars, che, 0, 1, DateTime(2026), short: '1H');
      final ch = diffMatch(a, b);
      expect(ch.single.kind, ChangeKind.goal);
      expect(ch.single.teamId, che.id);
    });
  });

  group('fuzzy search', () {
    test('tolerates typos and diacritics', () {
      expect(Fuzzy.score('mbape', 'Kylian Mbappé'), greaterThan(0.5));
      expect(Fuzzy.score('barcelna', 'Barcelona'), greaterThan(0.5));
      expect(Fuzzy.score('arsenal', 'Chelsea'), 0);
      expect(Fuzzy.rank('madrid', ['Real Madrid', 'Atlético Madrid', 'Arsenal'], (s) => s), hasLength(2));
    });
  });
}
