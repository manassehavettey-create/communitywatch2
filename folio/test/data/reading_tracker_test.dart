import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/logic/reading_tracker.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 10);
  DateTime at(int s) => t0.add(Duration(seconds: s));

  test('pages count after the minimum dwell, once each', () {
    final t = ReadingTracker(startPage: 1, now: t0);
    t.tick(at(3));
    expect(t.pagesRead, 0);
    t.tick(at(6));
    expect(t.pagesRead, 1);
    t.pageChanged(2, at(7));
    t.tick(at(9)); // only 2s on page 2
    t.pageChanged(3, at(9));
    t.tick(at(20));
    t.pageChanged(1, at(21)); // back to page 1 — already counted
    t.tick(at(40));
    expect(t.pagesRead, 2);
    expect(t.activeTime, const Duration(seconds: 40));
  });

  test('idle time beyond the timeout is not counted', () {
    final t = ReadingTracker(startPage: 1, now: t0, idleTimeout: const Duration(seconds: 60));
    t.tick(at(600));
    expect(t.activeTime, const Duration(seconds: 60));
    t.interaction(at(600));
    t.tick(at(630));
    expect(t.activeTime, const Duration(seconds: 90));
  });

  test('paused (app in background) time is not counted', () {
    final t = ReadingTracker(startPage: 1, now: t0);
    t.tick(at(10));
    t.pause(at(10));
    t.tick(at(100));
    t.resume(at(100));
    t.tick(at(110));
    expect(t.activeTime, const Duration(seconds: 20));
  });

  test('unflushed totals are handed out once', () {
    final t = ReadingTracker(startPage: 1, now: t0);
    t.tick(at(30));
    final a = t.takeUnflushed(at(30));
    expect(a.active, const Duration(seconds: 30));
    expect(a.pages, 1);
    final b = t.takeUnflushed(at(30));
    expect(b.active, Duration.zero);
    expect(b.pages, 0);
  });
}
