import 'dart:io';

import 'package:bible_app/bible/canon.dart';
import 'package:bible_app/domain/plans.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final plans = PlanDefinition.parseAll(
    File('assets/plans/plans.json').readAsStringSync(),
  );
  PlanDefinition byId(String id) => plans.firstWhere((p) => p.id == id);

  PlanState state(
    String planId, {
    PlanStatus status = PlanStatus.active,
    String start = '2026-09-01',
    Set<int> done = const {},
    String? pausedOn,
    int pausedDays = 0,
  }) => PlanState(
    plan: byId(planId),
    status: status,
    startDate: start,
    completedDays: done,
    pausedOn: pausedOn,
    pausedDays: pausedDays,
  );

  group('bundled plan definitions', () {
    test('every requested kind of plan is present', () {
      final ids = plans.map((p) => p.id).toSet();
      expect(
        ids,
        containsAll([
          'bible-1y',
          'bible-90',
          'nt-90',
          'ot-240',
          'gospels-40',
          'psalms-30',
          'proverbs-31',
          'first-steps-14',
          'mark-16',
          'chronological-1y',
          'sermon-mount-3',
          'peace-7',
        ]),
      );
      for (final c in PlanCategory.values) {
        expect(plans.any((p) => p.category == c), isTrue, reason: c.name);
      }
    });

    test('whole-Bible plans cover all 1,189 chapters exactly once', () {
      for (final id in ['bible-1y', 'bible-90', 'chronological-1y']) {
        final seen = <String>[];
        for (final day in byId(id).days) {
          for (final p in day) {
            for (final c in p.chapters) {
              seen.add(c.code);
            }
          }
        }
        expect(seen.length, Canon.totalChapters, reason: id);
        expect(seen.toSet().length, Canon.totalChapters, reason: id);
      }
    });

    test('day lengths and labels', () {
      expect(byId('bible-1y').totalDays, 365);
      expect(byId('proverbs-31').labelFor(3), 'Proverbs 3');
      expect(byId('first-steps-14').labelFor(4), 'Genesis 2–3');
      expect(byId('peace-7').labelFor(1), 'Philippians 4:4–9');
    });
  });

  group('PlanState', () {
    test('fresh plan starts at day 1 with 0%', () {
      final s = state('proverbs-31');
      expect(s.currentDay, 1);
      expect(s.percent, 0);
      expect(s.isFinished, isFalse);
    });

    test('current day is the first day not completed', () {
      final s = state('proverbs-31', done: {1, 2, 4});
      expect(s.currentDay, 3);
      expect(s.completedCount, 3);
      expect(s.percent, 9); // 3/31 = 9.6%, floored
      expect(s.pastDays(), [2, 1]);
      expect(s.upcomingDays(count: 3), [4, 5, 6]);
    });

    test('completion percent reaches 100 only when every day is done', () {
      final all = {for (var d = 1; d <= 31; d++) d};
      expect(state('proverbs-31', done: all).percent, 100);
      expect(state('proverbs-31', done: all).isFinished, isTrue);
      expect(state('proverbs-31', done: all.difference({17})).percent, 96);
    });

    test('schedule follows the calendar and reports days behind', () {
      final s = state('proverbs-31', start: '2026-09-01', done: {1, 2});
      expect(s.scheduledDay('2026-09-01'), 1);
      expect(s.scheduledDay('2026-09-05'), 5);
      // Days 3 and 4 are overdue; day 5 is today's reading, not late yet.
      expect(s.behindBy('2026-09-05'), 2);
      expect(
        state('proverbs-31', done: {1, 2, 3, 4, 5}).behindBy('2026-09-05'),
        0,
      );
      // Reading ahead is never "behind".
      expect(state('proverbs-31', done: {1, 2, 3}).behindBy('2026-09-02'), 0);
    });

    test('scheduled day is clamped to the plan length', () {
      final s = state('sermon-mount-3', start: '2026-01-01');
      expect(s.scheduledDay('2026-09-28'), 3);
      expect(s.scheduledDay('2025-12-01'), 1);
    });

    test('pausing freezes the schedule; resuming shifts it', () {
      final paused = state(
        'proverbs-31',
        status: PlanStatus.paused,
        start: '2026-09-01',
        pausedOn: '2026-09-05',
        done: {1, 2, 3, 4},
      );
      // Ten days later the schedule still says day 5.
      expect(paused.scheduledDay('2026-09-15'), 5);
      expect(paused.behindBy('2026-09-15'), 0);
      expect(paused.dateOfDay(5, '2026-09-15'), '2026-09-15');

      final extra = PlanState.resumedPausedDays(
        pausedDays: 0,
        pausedOn: '2026-09-05',
        today: '2026-09-15',
      );
      expect(extra, 10);
      final resumed = state(
        'proverbs-31',
        start: '2026-09-01',
        pausedDays: extra,
        done: {1, 2, 3, 4},
      );
      expect(resumed.scheduledDay('2026-09-15'), 5);
      expect(resumed.scheduledDay('2026-09-16'), 6);
      expect(resumed.dateOfDay(6, '2026-09-16'), '2026-09-16');
    });

    test('completions outside the plan are ignored', () {
      final s = state('sermon-mount-3', done: {1, 2, 3, 99});
      expect(s.completedCount, 3);
      expect(s.percent, 100);
    });
  });
}
