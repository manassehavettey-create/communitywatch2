import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/db/database.dart';
import 'package:folio/data/logic/streak.dart';
import 'package:folio/data/repositories/stats_repository.dart';

import 'test_helpers.dart';

DateTime d(int m, int day) => DateTime(2026, m, day);

void main() {
  group('computeStreak', () {
    final now = DateTime(2026, 3, 10, 21, 15);

    test('empty history', () {
      final r = computeStreak([], now);
      expect(r.current, 0);
      expect(r.longest, 0);
      expect(r.readToday, isFalse);
    });

    test('counts consecutive days ending today', () {
      final r = computeStreak([d(3, 8), d(3, 9), d(3, 10)], now);
      expect(r.current, 3);
      expect(r.longest, 3);
      expect(r.readToday, isTrue);
    });

    test('streak stays alive until today is over', () {
      final r = computeStreak([d(3, 7), d(3, 8), d(3, 9)], now);
      expect(r.current, 3);
      expect(r.readToday, isFalse);
    });

    test('a missed day resets the current streak', () {
      final r = computeStreak([d(3, 5), d(3, 6), d(3, 7), d(3, 8)], now);
      expect(r.current, 0);
      expect(r.longest, 4);
    });

    test('longest streak is found across gaps and month boundaries', () {
      final days = [
        d(1, 30), d(1, 31), d(2, 1), d(2, 2), d(2, 3), // 5 across month end
        d(2, 10),
        d(3, 9), d(3, 10),
      ];
      final r = computeStreak(days, now);
      expect(r.longest, 5);
      expect(r.current, 2);
    });

    test('duplicate timestamps on the same day count once', () {
      final r = computeStreak(
        [DateTime(2026, 3, 10, 8), DateTime(2026, 3, 10, 22), DateTime(2026, 3, 9, 1)],
        now,
      );
      expect(r.current, 2);
    });

    test('works across a DST change', () {
      // Days are compared as calendar dates, not 24h spans.
      final r = computeStreak([DateTime(2026, 3, 28), DateTime(2026, 3, 29), DateTime(2026, 3, 30)],
          DateTime(2026, 3, 30, 12));
      expect(r.current, 3);
    });
  });

  test('qualifying threshold: one page or one minute', () {
    expect(qualifiesForStreak(pagesRead: 0, seconds: 59), isFalse);
    expect(qualifiesForStreak(pagesRead: 0, seconds: 60), isTrue);
    expect(qualifiesForStreak(pagesRead: 1, seconds: 0), isTrue);
  });

  group('stats repository', () {
    late AppDatabase db;
    late StatsRepository stats;
    setUp(() {
      db = newDb();
      stats = StatsRepository(db);
    });
    tearDown(() => db.close());

    test('activity accumulates per local day and feeds the streak', () async {
      final book = await seedBook(db);
      await stats.addActivity(bookId: book, pages: 3, seconds: 300, at: DateTime(2026, 3, 9, 10));
      await stats.addActivity(bookId: book, pages: 2, seconds: 120, at: DateTime(2026, 3, 10, 9));
      await stats.addActivity(bookId: book, pages: 4, seconds: 200, at: DateTime(2026, 3, 10, 20));
      final s = await stats.summary(now: DateTime(2026, 3, 10, 22));
      expect(s.pagesToday, 6);
      expect(s.secondsToday, 320);
      expect(s.totalSeconds, 620);
      expect(s.streak.current, 2);
      expect(s.streak.readToday, isTrue);
      expect(s.lastDays(7, DateTime(2026, 3, 10)).map((e) => e.pages).toList(),
          [0, 0, 0, 0, 0, 3, 6]);
    });

    test('history survives deleting the book', () async {
      final book = await seedBook(db);
      await stats.addActivity(bookId: book, pages: 1, seconds: 90, at: DateTime(2026, 3, 10));
      await (db.delete(db.books)..where((b) => b.id.equals(book))).go();
      final s = await stats.summary(now: DateTime(2026, 3, 10, 12));
      expect(s.streak.current, 1);
    });
  });
}
