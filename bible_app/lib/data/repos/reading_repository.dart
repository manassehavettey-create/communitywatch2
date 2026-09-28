import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';

import '../../bible/canon.dart';
import '../../bible/references.dart';
import '../../domain/days.dart';
import '../../domain/streaks.dart';
import '../db/database.dart';
import '../sync/sync_writer.dart';

/// Reading statistics shown on Home, Profile and the streak screen.
class ReadingStats {
  const ReadingStats({
    required this.streak,
    required this.chaptersRead,
    required this.booksCompleted,
    required this.days,
  });

  final StreakStats streak;
  final int chaptersRead;
  final int booksCompleted;

  /// Chapters read per day key.
  final Map<String, int> days;

  static const empty = ReadingStats(
    streak: StreakStats.none,
    chaptersRead: 0,
    booksCompleted: 0,
    days: {},
  );
}

class ReadingRepository {
  ReadingRepository(this._w);

  final SyncWriter _w;
  AppDatabase get _db => _w.db;

  /// Records that [chapter] was read today (after enough time on it).
  /// Counts a chapter towards today's total once per day.
  Future<void> recordChapterRead(ChapterRef chapter, {int seconds = 0}) async {
    final code = chapter.code;
    final today = Days.today();
    final existing = await (_db.select(
      _db.chapterReads,
    )..where((c) => c.id.equals(code))).getSingleOrNull();
    final readTodayAlready =
        existing != null &&
        existing.deletedAt == null &&
        Days.key(DateTime.fromMillisecondsSinceEpoch(existing.lastReadAt)) ==
            today;

    await _w.write('chapter_reads', code, (t) async {
      if (existing == null) {
        await _db
            .into(_db.chapterReads)
            .insert(
              ChapterReadsCompanion.insert(
                id: code,
                userId: Value(_w.userId),
                createdAt: t,
                updatedAt: t,
                firstReadAt: t,
                lastReadAt: t,
              ),
            );
      } else {
        await (_db.update(
          _db.chapterReads,
        )..where((c) => c.id.equals(code))).write(
          ChapterReadsCompanion(
            lastReadAt: Value(t),
            updatedAt: Value(t),
            deletedAt: const Value(null),
            timesRead: Value(existing.timesRead + (readTodayAlready ? 0 : 1)),
          ),
        );
      }
    });
    await _addToDay(
      today,
      chapters: readTodayAlready ? 0 : 1,
      seconds: seconds,
    );
  }

  /// Adds reading time to today without counting a chapter.
  Future<void> addReadingTime(int seconds) =>
      _addToDay(Days.today(), chapters: 0, seconds: seconds);

  Future<void> _addToDay(
    String day, {
    required int chapters,
    required int seconds,
  }) async {
    if (chapters == 0 && seconds == 0) return;
    await _w.write('reading_activity', day, (t) async {
      final row = await (_db.select(
        _db.readingActivity,
      )..where((r) => r.id.equals(day))).getSingleOrNull();
      if (row == null) {
        await _db
            .into(_db.readingActivity)
            .insert(
              ReadingActivityCompanion.insert(
                id: day,
                userId: Value(_w.userId),
                createdAt: t,
                updatedAt: t,
                chapters: Value(chapters),
                seconds: Value(seconds),
              ),
            );
      } else {
        await (_db.update(
          _db.readingActivity,
        )..where((r) => r.id.equals(day))).write(
          ReadingActivityCompanion(
            chapters: Value(row.chapters + chapters),
            seconds: Value(row.seconds + seconds),
            updatedAt: Value(t),
          ),
        );
      }
    });
  }

  Stream<ReadingStats> watchStats() {
    final days =
        (_db.select(_db.readingActivity)..where(
              (r) => r.deletedAt.isNull() & r.chapters.isBiggerThanValue(0),
            ))
            .watch();
    final chapters = (_db.select(
      _db.chapterReads,
    )..where((c) => c.deletedAt.isNull())).watch();
    return Rx.combineLatest2(days, chapters, _stats);
  }

  Stream<Set<String>> watchReadChapterCodes() =>
      (_db.select(_db.chapterReads)..where((c) => c.deletedAt.isNull()))
          .watch()
          .map((rows) => {for (final r in rows) r.id});

  static ReadingStats _stats(
    List<ReadingActivityData> days,
    List<ChapterRead> chapters,
  ) {
    final read = {for (final c in chapters) c.id};
    var booksDone = 0;
    for (final b in Canon.books) {
      var all = true;
      for (var i = 1; i <= b.chapterCount; i++) {
        if (!read.contains('${b.id}.$i')) {
          all = false;
          break;
        }
      }
      if (all) booksDone++;
    }
    return ReadingStats(
      streak: computeStreaks(days.map((d) => d.id), Days.today()),
      chaptersRead: read.length,
      booksCompleted: booksDone,
      days: {for (final d in days) d.id: d.chapters},
    );
  }
}
