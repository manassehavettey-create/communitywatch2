import 'dart:convert';

import 'package:bodyforge/data/local/database.dart';
import 'package:bodyforge/data/repositories/data_context.dart';
import 'package:bodyforge/data/services/export_service.dart';
import 'package:bodyforge/data/services/training_service.dart';
import 'package:bodyforge/domain/catalog/achievements.dart';
import 'package:bodyforge/domain/engine/environment.dart';
import 'package:bodyforge/domain/engine/mission.dart';
import 'package:bodyforge/domain/engine/player.dart';
import 'package:bodyforge/domain/engine/program_generator.dart';
import 'package:bodyforge/domain/engine/session_builder.dart';
import 'package:bodyforge/domain/models/enums.dart';
import 'package:bodyforge/domain/models/local_date.dart';
import 'package:bodyforge/domain/models/workout.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late TrainingService svc;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 9, 28, 7, 30)); // Monday morning
    svc = TrainingService(DataContext(db: db, userId: 'u1', clock: clock));
  });
  tearDown(() => db.close());

  /// Play [plan] to the end, hitting [factor] of each rep target.
  Future<PlayerSnapshot> play(WorkoutPlan plan, {double factor = 1}) async {
    var s = PlayerSnapshot.start('w-${clock.now().millisecondsSinceEpoch}', plan, clock.now());
    while (!s.isFinished) {
      clock.advance(const Duration(seconds: 50));
      s = s.catchUp(clock.now());
      if (!s.isFinished && !s.current!.isClocked) {
        s = s.completeWork((s.current!.target * factor).round(), clock.now());
      }
    }
    return s;
  }

  Future<WorkoutPlan> todaysPlan() async {
    final p = (await svc.profiles.getProfile())!;
    final program = (await svc.profiles.getActiveProgram())!;
    final day = program.spec.dayTypeFor(clock.today());
    return SessionBuilder(SessionInputs(
      dayType: day == DayType.rest ? DayType.fullBody : day,
      params: await svc.paramsFor(p),
      progress: await svc.training.getProgress(),
      filter: ExerciseFilter(p.environment, p.limitations),
      minutes: program.spec.minutes,
      style: p.style,
    )).build();
  }

  test('onboarding creates the starting program, placement, journey and weight', () async {
    final spec = await svc.completeOnboarding(profile(days: 5, minutes: 20));
    expect(spec.days.map((d) => d.dayType).toList(),
        [DayType.upper, DayType.lower, DayType.recovery, DayType.upperCore, DayType.fullBody]);
    final progress = await svc.training.getProgress();
    expect(progress.keys, containsAll(['push', 'legs', 'core', 'back', 'hips', 'conditioning']));
    expect(progress['push']!.nodeIndex, 3, reason: '6–15 push-ups → standard push-up');
    final journey = await svc.training.getJourney();
    expect(journey!.startNodes['push'], 3);
    final m = await svc.lifestyle.getMeasurements();
    expect(m.single.point.value, 68);
    expect(await db.pendingChanges(), greaterThan(10), reason: 'everything is queued for sync');
  });

  test('completing a workout: saves it, progresses, unlocks FIRST REP, records baselines', () async {
    await svc.completeOnboarding(profile(days: 5, minutes: 20));
    final plan = await todaysPlan();
    final before = await svc.training.getProgress();
    final snap = await play(plan);
    final out = await svc.completeWorkout(snap, Rating.good);

    expect(out.achievements.map((a) => a.id), contains(AchievementIds.firstRep));
    expect(out.prs, isEmpty, reason: 'first results are baselines');
    expect(out.baselines, isNotEmpty);
    expect(out.progression, isNotEmpty);

    final after = await svc.training.getProgress();
    final push = out.progression.firstWhere((e) => e.trackKey == 'push');
    expect(after['push'], isNot(before['push']));
    expect(push.type, anyOf(ProgressionTypeMatcher.upward));

    final workouts = await svc.training.getWorkouts();
    expect(workouts.single.rating, Rating.good);
    expect(workouts.single.sets, isNotEmpty);
    expect(await svc.training.getActiveSession(), isNull);
  });

  test('beating a previous best is a celebrated PR with previous vs current', () async {
    await svc.completeOnboarding(profile(days: 5, minutes: 20));
    await svc.completeWorkout(await play(await todaysPlan()), Rating.good);
    clock.advance(const Duration(days: 7)); // next Monday: same upper-body day
    final out = await svc.completeWorkout(await play(await todaysPlan(), factor: 1.5), Rating.tooEasy);
    expect(out.prs, isNotEmpty);
    expect(out.prs.first.previous, isNotNull);
    expect(out.prs.first.current, greaterThan(out.prs.first.previous!));
    expect((await svc.lifestyle.getUnlocked()).keys, contains(AchievementIds.firstPr));
  });

  test('the running session survives a restart', () async {
    await svc.completeOnboarding(profile());
    final plan = await todaysPlan();
    final s = PlayerSnapshot.start('w1', plan, clock.now()).catchUp(clock.now().add(const Duration(seconds: 45)));
    await svc.training.saveActiveSession(s);
    final restored = await svc.training.getActiveSession();
    expect(restored!.stepIndex, s.stepIndex);
    expect(restored.plan.toJson(), plan.toJson());
  });

  test('mission: rest day offers a catch-up for a missed session', () async {
    await svc.completeOnboarding(profile(days: 3)); // Mon / Wed / Fri
    final program = (await svc.profiles.getActiveProgram())!;
    final tue = planToday(
        today: const LocalDate(2026, 9, 29), program: program.spec, programStart: program.startedOn, sessionDates: {});
    expect(tue.isRestDay, isTrue);
    expect(tue.catchUp, program.spec.dayTypeFor(const LocalDate(2026, 9, 28)));
    final done = planToday(
        today: const LocalDate(2026, 9, 29),
        program: program.spec,
        programStart: program.startedOn,
        sessionDates: {const LocalDate(2026, 9, 28)});
    expect(done.catchUp, isNull);
    expect(done.missionType, isNull);
  });

  test('regenerating the program archives the old one', () async {
    await svc.completeOnboarding(profile(days: 3));
    final p = (await svc.profiles.getProfile())!;
    await svc.regenerateProgram(p.copyWith(daysPerWeek: 6));
    final active = (await svc.profiles.getActiveProgram())!;
    expect(active.spec.days, hasLength(6));
    final all = await db.select(db.programs).get();
    expect(all.where((r) => r.active), hasLength(1));
  });

  test('challenges: 7 check-ins complete the water challenge and unlock HYDRATED', () async {
    await svc.completeOnboarding(profile());
    await svc.lifestyle.startChallenge('water_7');
    var done = false;
    for (var i = 0; i < 7; i++) {
      final e = (await svc.lifestyle.getChallenges()).single;
      done = await svc.lifestyle.checkIn(e, i == 3 ? 5 : 8, date: clock.today().addDays(i));
    }
    // Day 4 missed the target: not complete yet, but not failed either.
    expect(done, isFalse);
    final e = (await svc.lifestyle.getChallenges()).single;
    expect(e.successDays, 6);
    done = await svc.lifestyle.checkIn(e, 8, date: clock.today().addDays(8));
    expect(done, isTrue);
    final fresh = await svc.checkAchievements();
    expect(fresh.map((a) => a.id), contains(AchievementIds.hydrated));
  });

  test('export contains every user table', () async {
    await svc.completeOnboarding(profile());
    final json = jsonDecode(await ExportService(db, 'u1').toJson()) as Map<String, dynamic>;
    expect(json['app'], 'BODYFORGE');
    expect((json['profiles'] as List).single['name'], 'Ama Mensah');
    expect(json.keys, containsAll(['workouts', 'measurements', 'skill_progress', 'journey_progress']));
  });

  test('generated program days use the spec', () {
    final spec = generateProgram(goals: {Goal.buildMuscle}, daysPerWeek: 5, minutes: 20);
    expect(spec.isTrainingDay(const LocalDate(2026, 10, 3)), isFalse); // Saturday
  });
}

abstract final class ProgressionTypeMatcher {
  static final upward = [
    // Reps up, a set added or a new variation — any forward step.
    for (final t in ['repsUp', 'setAdded', 'unlocked']) predicate<dynamic>((v) => v.toString().endsWith(t))
  ];
}
