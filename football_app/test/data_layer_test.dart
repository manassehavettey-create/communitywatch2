import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/core/cache/cache_store.dart';
import 'package:touchline/core/network/api_client.dart';
import 'package:touchline/core/network/request_budget.dart';
import 'package:touchline/data/api_football/api_football_repository.dart';
import 'package:touchline/data/api_football/parser.dart';
import 'package:touchline/data/models/models.dart';
import 'package:touchline/domain/insights.dart';

import 'fixtures.dart';

void main() {
  group('ApiFootballParser', () {
    final m = ApiFootballParser.fixture(ApiFootballParser.response(fixtureDetailJson).first);

    test('maps core match fields', () {
      expect(m.id, 1001);
      expect(m.home.name, 'Arsenal');
      expect(m.status.phase, MatchPhase.live);
      expect(m.status.minuteLabel, "78'");
      expect((m.homeGoals, m.awayGoals), (2, 1));
      expect(m.halftime.home, 1);
      expect(m.league.round, 'Regular Season - 8');
    });

    test('classifies events and normalises substitutions via lineups', () {
      final ev = m.sortedEvents;
      expect(ev.where((e) => e.isGoal).length, 3);
      expect(ev[1].kind, EventKind.penaltyGoal);
      expect(ev[0].relatedName, 'M. Odegaard');
      final sub = ev.firstWhere((e) => e.kind == EventKind.sub);
      // Trossard started, so he is the player going OFF; Martinelli comes ON.
      expect(sub.playerName, 'G. Martinelli');
      expect(sub.relatedName, 'L. Trossard');
    });

    test('parses statistics, null counts as zero when tracked, and flags derived totals', () {
      final s = m.stats!;
      expect(s[StatKey.possession]!.home, 54);
      expect(s[StatKey.xg]!.away, closeTo(0.94, 1e-9));
      expect(s[StatKey.red]!.home, 0);
      expect(s[StatKey.duelsWon]!.home, 6);
      expect(s.derivedKeys, contains(StatKey.duelsWon));
      expect(s[StatKey.corners], isNull, reason: 'not provided → hidden, never guessed');
    });

    test('parses player lines; accuracy count becomes a percentage', () {
      final saka = m.players!.firstWhere((p) => p.player.id == 7);
      expect(saka.stats.rating, 8.2);
      expect(saka.stats.passAccuracy, closeTo(80, 0.01));
      expect(m.players!.firstWhere((p) => p.player.id == 20).captain, isTrue);
    });

    test('lineups keep grid and colours', () {
      final lu = m.lineups!.first;
      expect(lu.formation, '4-3-3');
      expect(lu.startXI.first.gridRow, 1);
      expect(lu.primaryColor, 0xFFFF0000);
      expect(m.lineups!.last.primaryColor, isNull);
    });

    test('standings keep provider zone descriptions', () {
      final t = ApiFootballParser.standings(standingsJson)!;
      final rows = t.groups.single.rows;
      expect(rows.first.trend, Trend.up);
      expect(zoneFor(rows.first.description)!.kind, ZoneKind.champions);
      expect(zoneFor(rows.last.description)!.kind, ZoneKind.relegation);
      expect(zoneFor(null), isNull);
    });
  });

  group('ApiFootballClient.checkErrors', () {
    test('maps plan and auth errors to typed exceptions', () {
      expect(() => ApiFootballClient.checkErrors(planErrorJson), throwsA(isA<DataException>().having((e) => e.kind, 'kind', DataErrorKind.plan)));
      expect(() => ApiFootballClient.checkErrors(tokenErrorJson), throwsA(isA<DataException>().having((e) => e.kind, 'kind', DataErrorKind.auth)));
      ApiFootballClient.checkErrors(standingsJson); // no throw
    });
  });

  group('ApiFootballRepository via cache', () {
    test('finished match is served from cache without network', () async {
      var calls = 0;
      final store = MemoryCacheStore();
      var now = DateTime(2026, 9, 30, 22);
      final ft = fixtureDetailJson.replaceAll('"short":"2H"', '"short":"FT"');
      final repo = ApiFootballRepository.withFetcher(
        CachedFetcher(store, (p, q) async {
          calls++;
          return ft;
        }, clock: () => now),
        clock: () => now,
      );
      await repo.match(1001);
      now = now.add(const Duration(days: 2));
      final again = await repo.match(1001);
      expect(calls, 1);
      expect(again.data.status.isFinished, isTrue);
    });
  });

  group('RequestBudget', () {
    test('slows then pauses live polling as quota runs low', () {
      final b = RequestBudget();
      b.update(remaining: 90);
      expect(b.liveInterval(), const Duration(minutes: 2));
      b.update(remaining: 10);
      expect(b.liveInterval(), isNull);
      b.saver = true;
      b.update(remaining: 500);
      expect(b.liveInterval(), const Duration(minutes: 2));
    });
  });
}
