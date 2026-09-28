import 'package:drift/drift.dart';

import '../../core/db/database.dart';
import '../../core/utils/day.dart';
import '../logic/streak.dart';

class DayTotal {
  const DayTotal(this.day, this.pages, this.seconds);
  final DateTime day;
  final int pages;
  final int seconds;
}

class StatsSummary {
  const StatsSummary({
    required this.pagesToday,
    required this.secondsToday,
    required this.pagesWeek,
    required this.pagesMonth,
    required this.totalSeconds,
    required this.booksFinished,
    required this.booksInProgress,
    required this.streak,
    required this.days,
  });

  final int pagesToday;
  final int secondsToday;
  final int pagesWeek;
  final int pagesMonth;
  final int totalSeconds;
  final int booksFinished;
  final int booksInProgress;
  final StreakResult streak;

  /// Every day with activity, oldest first.
  final List<DayTotal> days;

  bool get hasHistory => days.isNotEmpty;

  /// Totals for the [count] days ending today (inclusive), oldest first.
  List<DayTotal> lastDays(int count, DateTime now) {
    final byDay = {for (final d in days) d.day: d};
    final today = dateOnly(now);
    return [
      for (var i = count - 1; i >= 0; i--)
        byDay[addDays(today, -i)] ?? DayTotal(addDays(today, -i), 0, 0),
    ];
  }

}

class StatsRepository {
  StatsRepository(this.db);
  final AppDatabase db;

  /// Adds reading time / pages to the local day of [at] and to the book's
  /// last-read timestamp.
  Future<void> addActivity({
    required int bookId,
    required int pages,
    required int seconds,
    required DateTime at,
  }) async {
    if (pages <= 0 && seconds <= 0) return;
    final key = dayKey(at);
    await db.transaction(() async {
      await db.customStatement(
        'INSERT INTO daily_activities(day, pages_read, seconds) VALUES (?1, ?2, ?3) '
        'ON CONFLICT(day) DO UPDATE SET pages_read = pages_read + ?2, seconds = seconds + ?3',
        [key, pages, seconds],
      );
      await (db.update(db.books)..where((b) => b.id.equals(bookId)))
          .write(BooksCompanion(lastReadAt: Value(at)));
    });
  }

  Future<int> saveSession(ReadingSessionsCompanion s) => db.into(db.readingSessions).insert(s);

  Future<void> updateSession(int id, ReadingSessionsCompanion s) =>
      (db.update(db.readingSessions)..where((r) => r.id.equals(id))).write(s);

  Stream<List<DayTotal>> watchDays() => (db.select(db.dailyActivities)
        ..orderBy([(d) => OrderingTerm.asc(d.day)]))
      .watch()
      .map((rows) => [
            for (final r in rows) DayTotal(parseDayKey(r.day), r.pagesRead, r.seconds),
          ]);

  Future<List<DayTotal>> _days() async {
    final rows = await (db.select(db.dailyActivities)..orderBy([(d) => OrderingTerm.asc(d.day)]))
        .get();
    return [for (final r in rows) DayTotal(parseDayKey(r.day), r.pagesRead, r.seconds)];
  }

  Future<StatsSummary> summary({DateTime? now}) async {
    final t = now ?? DateTime.now();
    final days = await _days();
    final today = dateOnly(t);
    final weekStart = startOfWeek(today);
    final monthStart = DateTime(today.year, today.month, 1);
    var pagesToday = 0, secondsToday = 0, pagesWeek = 0, pagesMonth = 0, total = 0;
    for (final d in days) {
      total += d.seconds;
      if (d.day == today) {
        pagesToday += d.pages;
        secondsToday += d.seconds;
      }
      if (!d.day.isBefore(weekStart)) pagesWeek += d.pages;
      if (!d.day.isBefore(monthStart)) pagesMonth += d.pages;
    }
    final counts = await db.customSelect(
      'SELECT '
      "(SELECT count(*) FROM books WHERE status = ${BookStatus.finished.index}) AS f, "
      "(SELECT count(*) FROM books WHERE status = ${BookStatus.reading.index}) AS r",
    ).getSingle();
    final readingDays = {
      for (final d in days)
        if (qualifiesForStreak(pagesRead: d.pages, seconds: d.seconds)) d.day,
    };
    return StatsSummary(
      pagesToday: pagesToday,
      secondsToday: secondsToday,
      pagesWeek: pagesWeek,
      pagesMonth: pagesMonth,
      totalSeconds: total,
      booksFinished: counts.read<int>('f'),
      booksInProgress: counts.read<int>('r'),
      streak: computeStreak(readingDays, t),
      days: days,
    );
  }

  /// Re-computes the summary whenever reading activity or books change.
  Stream<StatsSummary> watchSummary() async* {
    yield await summary();
    await for (final _ in db.tableUpdates(
      TableUpdateQuery.onAllTables([db.dailyActivities, db.books]),
    )) {
      yield await summary();
    }
  }

  /// Deletes all reading history (daily totals and sessions).
  Future<void> clearHistory() async {
    await db.delete(db.dailyActivities).go();
    await db.delete(db.readingSessions).go();
  }
}
