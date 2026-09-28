import 'package:bodyforge/domain/catalog/achievements.dart';
import 'package:bodyforge/domain/catalog/skill_paths.dart';
import 'package:bodyforge/domain/engine/achievement_evaluator.dart';
import 'package:bodyforge/domain/engine/baseline.dart';
import 'package:bodyforge/domain/engine/calendar.dart';
import 'package:bodyforge/domain/engine/journey.dart';
import 'package:bodyforge/domain/engine/program_generator.dart';
import 'package:bodyforge/domain/engine/records.dart';
import 'package:bodyforge/domain/engine/reports.dart';
import 'package:bodyforge/domain/engine/weakest_link.dart';
import 'package:bodyforge/domain/models/enums.dart';
import 'package:bodyforge/domain/models/local_date.dart';
import 'package:bodyforge/domain/models/profile.dart';
import 'package:bodyforge/domain/models/workout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

CompletedWorkout workout(LocalDate date,
        {List<SetResult> s = const [],
        SessionKind kind = SessionKind.planned,
        DayType day = DayType.fullBody,
        int durationSec = 1800}) =>
    CompletedWorkout(id: 'w${date}_${kind.name}', date: date, dayType: day, kind: kind, sets: s, durationSec: durationSec);

void main() {
  const monday = LocalDate(2026, 9, 7);

  group('weakest link (spec §11)', () {
    final p = profile();
    final params = paramsFor(p);

    test('identifies the lagging area', () {
      final progress = initialProgress(p, params);
      progress[PathIds.push] = progress[PathIds.push]!.copyWith(nodeIndex: 6);
      progress[PathIds.core] = progress[PathIds.core]!.copyWith(nodeIndex: 5);
      progress[PathIds.legs] = progress[PathIds.legs]!.copyWith(nodeIndex: 6);
      progress[PathIds.hips] = progress[PathIds.hips]!.copyWith(nodeIndex: 6);
      progress[PathIds.back] = progress[PathIds.back]!.copyWith(nodeIndex: 5);
      progress[PathIds.conditioning] = progress[PathIds.conditioning]!.copyWith(nodeIndex: 0);
      final r = assessWeakestLink(progress, params);
      expect(r.weakest, Area.conditioning);
      expect(r.scores[Area.conditioning]!.rating, AreaRating.needsWork);
    });

    test('balanced areas have no weakest link', () {
      final progress = {
        for (final id in PathIds.all)
          id: TrackProgress(key: id, nodeIndex: 3, sets: 3, amount: params.nodeWindow(pathById(id), 3).$1)
      };
      final r = assessWeakestLink(progress, params);
      expect(r.weakest, isNull);
      expect(r.scores.values.every((s) => s.rating == AreaRating.good), isTrue);
    });

    test('poor recent completion drags an area down', () {
      final progress = {
        for (final id in PathIds.all)
          id: TrackProgress(key: id, nodeIndex: 3, sets: 3, amount: params.nodeWindow(pathById(id), 3).$1)
      };
      final r = assessWeakestLink(progress, params, recentCompletion: {Area.legs: 0.4});
      expect(r.weakest, Area.legs);
    });
  });

  group('personal records (spec §12)', () {
    test('first performance is a baseline, not a PR', () {
      final e = detectRecords({}, sets('push_up', 'push', 3, 10, 12));
      expect(e.single.isBaseline, isTrue);
      expect(e.single.isPr, isFalse);
      expect(e.single.current, 12);
    });

    test('beating the record is a PR with previous vs current', () {
      final e = detectRecords({recordKey('push_up', RecordMetric.maxReps): 24}, [
        ...sets('push_up', 'push', 2, 20, 30),
        ...sets('push_up', 'push', 1, 20, 34),
      ]);
      expect(e.single.isPr, isTrue);
      expect(e.single.previous, 24);
      expect(e.single.current, 34);
      expect(e.single.delta, 10);
    });

    test('equal or lower is not a PR', () {
      final e = detectRecords({recordKey('push_up', RecordMetric.maxReps): 24}, sets('push_up', 'push', 3, 20, 24));
      expect(e, isEmpty);
    });

    test('holds are tracked as max hold', () {
      final e = detectRecords({recordKey('plank', RecordMetric.maxHold): 90}, sets('plank', 'core', 1, 90, 135));
      expect(e.single.metric, RecordMetric.maxHold);
      expect(formatRecord(e.single.current, e.single.metric), '2:15');
      expect(formatRecord(e.single.previous!, e.single.metric), '1:30');
    });

    test('warm-ups and skipped sets never count', () {
      final e = detectRecords({}, [
        ...sets('march_in_place', null, 1, 30, 30, block: BlockKind.warmup),
        const SetResult(exerciseId: 'push_up', setIndex: 0, target: 10, achieved: 50, skipped: true),
      ]);
      expect(e, isEmpty);
    });
  });

  group('achievements (spec §20)', () {
    test('FIRST REP after one workout', () {
      final s = workoutStats([workout(monday)], 3);
      final unlocked = evaluateAchievements(AchievementStats(totalWorkouts: s.total), {});
      expect(unlocked.map((a) => a.id), contains(AchievementIds.firstRep));
    });

    test('100 PUSH-UPS sums push-up variations (both sides for archer)', () {
      final w = [
        workout(monday, s: sets('push_up', 'push', 3, 20, 20)), // 60
        workout(monday.addDays(2), s: sets('archer_push_up', 'push', 2, 10, 10)), // 2*10*2 = 40
      ];
      final s = workoutStats(w, 3);
      expect(s.pushUps, 100);
      final unlocked = evaluateAchievements(AchievementStats(pushUpReps: s.pushUps, totalWorkouts: 2), {});
      expect(unlocked.map((a) => a.id), contains(AchievementIds.hundredPushUps));
    });

    test('7 DAYS STRONG needs a full planned week', () {
      final three = workoutStats([workout(monday), workout(monday.addDays(2)), workout(monday.addDays(4))], 3);
      expect(three.fullWeek, isTrue);
      final two = workoutStats([workout(monday), workout(monday.addDays(2))], 3);
      expect(two.fullWeek, isFalse);
    });

    test('THE COMEBACK after 7+ days off', () {
      expect(workoutStats([workout(monday), workout(monday.addDays(10))], 3).comeback, isTrue);
      expect(workoutStats([workout(monday), workout(monday.addDays(3))], 3).comeback, isFalse);
    });

    test('CORE BUILDER counts core sessions', () {
      final w = [for (var i = 0; i < 20; i++) workout(monday.addDays(i), day: DayType.core)];
      final s = workoutStats(w, 3);
      expect(s.coreSessions, 20);
      expect(evaluateAchievements(AchievementStats(coreSessions: 20), {}).map((a) => a.id),
          contains(AchievementIds.coreBuilder));
    });

    test('never re-awards an unlocked achievement', () {
      final res = evaluateAchievements(const AchievementStats(totalWorkouts: 1), {AchievementIds.firstRep});
      expect(res.map((a) => a.id), isNot(contains(AchievementIds.firstRep)));
    });

    test('BODYFORGE only when the 12-week journey is complete', () {
      expect(evaluateAchievements(const AchievementStats(journeyCountedWeeks: 11), {}).map((a) => a.id),
          isNot(contains(AchievementIds.bodyforge)));
      expect(evaluateAchievements(const AchievementStats(journeyComplete: true, journeyCountedWeeks: 12), {})
          .map((a) => a.id), contains(AchievementIds.bodyforge));
    });

    test('nothing unlocks without real actions', () {
      expect(evaluateAchievements(const AchievementStats(), {}), isEmpty);
    });
  });

  group('12-week journey (spec §21)', () {
    List<LocalDate> perWeek(int weeks, int count) => [
          for (var w = 0; w < weeks; w++)
            for (var i = 0; i < count; i++) monday.addDays(w * 7 + i * 2)
        ];

    test('week 1 on day one', () {
      final j = computeJourney(start: monday, today: monday, workoutDates: const [], plannedPerWeek: 4);
      expect(j.currentWeek, 1);
      expect(j.phase, JourneyPhase.habit);
      expect(j.progress, 0);
    });

    test('advances through the phases', () {
      final j = computeJourney(
          start: monday, today: monday.addDays(7 * 5 + 1), workoutDates: perWeek(6, 3), plannedPerWeek: 4);
      expect(j.currentWeek, 6);
      expect(j.phase, JourneyPhase.body);
    });

    test('a week under half the plan is repeated, not failed', () {
      final dates = [...perWeek(2, 3), monday.addDays(14)]; // week 3 only 1 of 4
      final j = computeJourney(start: monday, today: monday.addDays(22), workoutDates: dates, plannedPerWeek: 4);
      expect(j.blocks[2].status, JourneyWeekStatus.repeated);
      expect(j.currentWeek, 3);
      expect(j.repeatedWeeks, 1);
    });

    test('weeks away pause the journey', () {
      final dates = perWeek(3, 3);
      final j = computeJourney(start: monday, today: monday.addDays(7 * 10), workoutDates: dates, plannedPerWeek: 3);
      expect(j.countedWeeks, 3);
      expect(j.currentWeek, 4);
    });

    test('completes after 12 counted weeks and reports the date', () {
      final dates = perWeek(12, 2);
      final j = computeJourney(start: monday, today: monday.addDays(7 * 12), workoutDates: dates, plannedPerWeek: 3);
      expect(j.complete, isTrue);
      expect(j.currentWeek, 12);
      expect(j.progress, 1);
      expect(j.completedOn, isNotNull);
      expect(j.phase, JourneyPhase.forge);
    });

    test('required workouts are half the plan, at least one', () {
      expect(requiredWorkoutsPerWeek(1), 1);
      expect(requiredWorkoutsPerWeek(2), 1);
      expect(requiredWorkoutsPerWeek(5), 3);
    });
  });

  group('program generator (spec §4, §19)', () {
    test('5 days matches the spec example', () {
      final prog = generateProgram(goals: {Goal.buildMuscle}, daysPerWeek: 5, minutes: 30);
      expect(prog.days.map((d) => d.dayType).toList(),
          [DayType.upper, DayType.lower, DayType.recovery, DayType.upperCore, DayType.fullBody]);
      expect(prog.days.map((d) => d.weekday).toList(), [1, 2, 3, 4, 5]);
    });

    test('respects preferred days', () {
      final prog = generateProgram(goals: {Goal.loseFat}, daysPerWeek: 3, minutes: 20, preferredDays: [2, 4, 6]);
      expect(prog.days.map((d) => d.weekday).toList(), [2, 4, 6]);
      expect(prog.days.map((d) => d.dayType), contains(DayType.conditioning));
    });

    test('2–7 days all produce valid plans', () {
      for (var n = 2; n <= 7; n++) {
        final prog = generateProgram(goals: {Goal.fullTransformation}, daysPerWeek: n, minutes: 30);
        expect(prog.days, hasLength(n));
        expect(prog.days.map((d) => d.weekday).toSet(), hasLength(n));
      }
    });

    test('build-your-own focus shapes the split', () {
      final prog = generateProgram(
          goals: {Goal.buildMuscle}, daysPerWeek: 4, minutes: 45, focus: {MuscleFocus.chest, MuscleFocus.arms});
      expect(prog.custom, isTrue);
      expect(prog.days.every((d) => d.dayType == DayType.upper), isTrue);
      final legs = generateProgram(
          goals: {Goal.getStronger}, daysPerWeek: 6, minutes: 30, focus: {MuscleFocus.legs, MuscleFocus.core});
      expect(legs.days.map((d) => d.dayType), containsAll([DayType.core, DayType.lower, DayType.recovery]));
    });

    test('duration is clamped to 5–60 minutes', () {
      expect(generateProgram(goals: {}, daysPerWeek: 3, minutes: 90).minutes, 60);
      expect(generateProgram(goals: {}, daysPerWeek: 3, minutes: 1).minutes, 5);
    });
  });

  group('consistency calendar (spec §18)', () {
    final program = generateProgram(goals: {Goal.buildMuscle}, daysPerWeek: 3, minutes: 30); // Mon/Wed/Fri
    test('shows completed, modified, recovery, rest and missed days', () {
      final today = monday.addDays(13); // Sunday week 2
      final cal = buildCalendar(
        today: today,
        program: program,
        programStart: monday,
        days: 14,
        sessions: {
          monday: [const CalendarEntry(kind: SessionKind.planned, dayType: DayType.fullBody)],
          monday.addDays(2): [const CalendarEntry(kind: SessionKind.lowMotivation, dayType: DayType.fullBody)],
          monday.addDays(5): [const CalendarEntry(kind: SessionKind.recovery, dayType: DayType.recovery)],
        },
      );
      final byDate = {for (final d in cal) d.date: d.status};
      expect(byDate[monday], DayStatus.completed);
      expect(byDate[monday.addDays(2)], DayStatus.modified);
      expect(byDate[monday.addDays(5)], DayStatus.recovery);
      expect(byDate[monday.addDays(4)], DayStatus.missed);
      expect(byDate[monday.addDays(1)], DayStatus.rest);
    });

    test('no "missed" days before the user started', () {
      final cal = buildCalendar(
          today: monday.addDays(3), program: program, programStart: monday.addDays(3), days: 10, sessions: const {});
      expect(cal.where((d) => d.status == DayStatus.missed), isEmpty);
    });

    test('consistency % is completed ÷ planned', () {
      final c = consistency(
        from: monday,
        to: monday.addDays(6),
        sessionDates: [monday, monday.addDays(2)],
        program: program,
        programStart: monday,
      );
      expect(c, closeTo(2 / 3, 0.001));
    });
  });

  group('weekly reality check (spec §17)', () {
    final program = generateProgram(goals: {Goal.buildMuscle}, daysPerWeek: 5, minutes: 30);
    test('summarises the week', () {
      final r = buildWeeklyReport(
        weekStart: monday,
        workouts: [for (var i = 0; i < 4; i++) workout(monday.addDays(i), s: sets('push_up', 'push', 3, 10, 10))],
        records: [
          RecordPoint(exerciseId: 'push_up', metric: RecordMetric.maxReps, previous: 24, value: 27, date: monday),
          RecordPoint(exerciseId: 'push_up', metric: RecordMetric.maxReps, previous: 27, value: 30, date: monday.addDays(3)),
          RecordPoint(exerciseId: 'plank', metric: RecordMetric.maxHold, previous: 90, value: 115, date: monday.addDays(2)),
        ],
        measurements: [
          MeasurementPoint(MeasurementType.weight, 78, monday.addDays(-3)),
          MeasurementPoint(MeasurementType.weight, 77.2, monday.addDays(5)),
          MeasurementPoint(MeasurementType.waist, 92, monday.addDays(-7)),
          MeasurementPoint(MeasurementType.waist, 90.5, monday.addDays(6)),
        ],
        recoveryScores: [(monday, 5), (monday.addDays(3), 5)],
        program: program,
        programStart: monday,
      );
      expect(r.completed, 4);
      expect(r.planned, 5);
      expect(r.consistency, closeTo(0.8, 0.001));
      expect(r.prDeltas.first.deltaLabel, '+25s');
      final push = r.prDeltas.firstWhere((d) => d.exerciseId == 'push_up');
      expect(push.delta, 6);
      expect(r.weightDelta, closeTo(-0.8, 0.001));
      expect(r.waistDelta, closeTo(-1.5, 0.001));
      expect(r.recovery, 'Good');
      expect(r.totalReps, 120);
    });
  });

  group('12-week report', () {
    test('compares start and end', () {
      final r = buildFinalReport(
        start: monday,
        end: monday.addDays(83),
        workouts: [workout(monday), workout(monday.addDays(40))],
        records: [
          RecordPoint(exerciseId: 'push_up', metric: RecordMetric.maxReps, previous: null, value: 12, date: monday),
          RecordPoint(exerciseId: 'push_up', metric: RecordMetric.maxReps, previous: 12, value: 31, date: monday.addDays(70)),
        ],
        measurements: [
          MeasurementPoint(MeasurementType.weight, 78, monday),
          MeasurementPoint(MeasurementType.weight, 75.4, monday.addDays(80)),
        ],
        startNodes: {PathIds.push: 2},
        currentNodes: {PathIds.push: 5},
        milestones: const [],
        achievementIds: const [AchievementIds.firstRep],
        program: generateProgram(goals: {Goal.buildMuscle}, daysPerWeek: 3, minutes: 30),
      );
      expect(r.workouts, 2);
      expect(r.records.single.from, 12);
      expect(r.records.single.to, 31);
      expect(r.weightChange, closeTo(-2.6, 0.001));
      expect(r.strength.single.levelsGained, 3);
      expect(r.prCount, 1);
    });
  });

  group('LocalDate', () {
    test('handles month/year boundaries and weekdays', () {
      expect(const LocalDate(2026, 12, 31).addDays(1), const LocalDate(2027, 1, 1));
      expect(const LocalDate(2026, 9, 28).weekday, 1);
      expect(const LocalDate(2026, 10, 4).startOfWeek, const LocalDate(2026, 9, 28));
      expect(LocalDate.parse('2026-03-29').addDays(1).toString(), '2026-03-30');
      expect(const LocalDate(2026, 3, 1).daysSince(const LocalDate(2026, 2, 1)), 28);
    });
  });
}
