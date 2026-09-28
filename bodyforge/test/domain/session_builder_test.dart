import 'package:bodyforge/domain/catalog/exercises.dart';
import 'package:bodyforge/domain/catalog/skill_paths.dart';
import 'package:bodyforge/domain/engine/environment.dart';
import 'package:bodyforge/domain/engine/quick_sessions.dart';
import 'package:bodyforge/domain/engine/recovery.dart';
import 'package:bodyforge/domain/engine/session_builder.dart';
import 'package:bodyforge/domain/engine/time_fitter.dart';
import 'package:bodyforge/domain/models/enums.dart';
import 'package:bodyforge/domain/models/exercise.dart';
import 'package:bodyforge/domain/models/workout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const trainingDays = [
  DayType.upper,
  DayType.lower,
  DayType.core,
  DayType.upperCore,
  DayType.fullBody,
  DayType.conditioning,
];

void main() {
  group('time compression keeps the objective (spec §8)', () {
    for (final goals in [
      {Goal.buildMuscle},
      {Goal.loseFat},
      {Goal.getStronger},
      {Goal.fullTransformation, Goal.visibleAbs},
    ]) {
      for (final day in trainingDays) {
        for (final minutes in kTimeOptions) {
          test('${goals.map((g) => g.name).join('+')} · ${day.name} · $minutes min', () {
            final p = profile(goals: goals, minutes: 30);
            final plan = SessionBuilder(inputsFor(p, day, minutes: minutes)).build();
            final main = plan.main;
            expect(main.exercises, isNotEmpty, reason: 'main block must never be empty');
            expect(main.exercises.any((e) => e.role == SlotRole.primary), isTrue,
                reason: 'the primary objective survives compression');
            if (minutes < 45) {
              expect(plan.estimatedSeconds, lessThanOrEqualTo(minutes * 60 * 1.05 + 1),
                  reason: 'estimated ${plan.estimatedMinutes} min for a $minutes-min slot');
            }
            expect(plan.targetMinutes, minutes);
          });
        }
      }
    }
  });

  test('a 30-minute session becomes a focused 10-minute one with the same primaries', () {
    final p = profile(minutes: 30);
    final full = SessionBuilder(inputsFor(p, DayType.upper, minutes: 30)).build();
    final short = SessionBuilder(inputsFor(p, DayType.upper, minutes: 10)).build();
    final fullPrimaries = full.main.exercises.where((e) => e.role == SlotRole.primary).map((e) => e.exerciseId);
    final shortPrimaries = short.main.exercises.where((e) => e.role == SlotRole.primary).map((e) => e.exerciseId);
    expect(shortPrimaries.first, fullPrimaries.first);
    expect(short.estimatedSeconds, lessThan(full.estimatedSeconds));
    expect(short.block(BlockKind.finisher), isNull);
  });

  test('45+ minutes expands the session', () {
    final p = profile(minutes: 20);
    final base = SessionBuilder(inputsFor(p, DayType.lower, minutes: 20)).build();
    final long = SessionBuilder(inputsFor(p, DayType.lower, minutes: 45)).build();
    expect(long.estimatedSeconds, greaterThan(base.estimatedSeconds));
  });

  test('refit converts a planned session to time-adjusted when shortened', () {
    final p = profile(minutes: 30);
    final b = SessionBuilder(inputsFor(p, DayType.fullBody, minutes: 30));
    final plan = b.build();
    final refit = b.refit(plan, 10);
    expect(refit.kind, SessionKind.timeAdjusted);
    expect(refit.estimatedSeconds, lessThanOrEqualTo(10 * 60 * 1.05 + 1));
  });

  group('recovery check (spec §9)', () {
    test('low energy + very sore → recovery session', () {
      final adj = adjustForRecovery(
          const RecoveryCheck(sleep: SleepQuality.good, soreness: Soreness.very, energy: Energy.low));
      expect(adj.mode, RecoveryMode.recovery);
    });

    test('good sleep + high energy → continue as planned', () {
      final adj = adjustForRecovery(
          const RecoveryCheck(sleep: SleepQuality.good, soreness: Soreness.none, energy: Energy.high));
      expect(adj.mode, RecoveryMode.full);
      expect(adj.changesPlan, isFalse);
    });

    test('poor sleep + a little sore + normal energy → reduced', () {
      final adj = adjustForRecovery(
          const RecoveryCheck(sleep: SleepQuality.poor, soreness: Soreness.little, energy: Energy.normal));
      expect(adj.mode, RecoveryMode.reduced);
      expect(adj.dropFinisher, isTrue);
      expect(adj.volumeFactor, lessThan(1));
    });

    test('score 4 → trimmed', () {
      final adj = adjustForRecovery(
          const RecoveryCheck(sleep: SleepQuality.okay, soreness: Soreness.little, energy: Energy.high));
      expect(adj.mode, RecoveryMode.trimmed);
    });

    test('a reduced check lowers the planned volume and marks the session', () {
      final p = profile(goals: {Goal.fullTransformation});
      final normal = SessionBuilder(inputsFor(p, DayType.fullBody, minutes: 45)).build();
      final reduced = SessionBuilder(inputsFor(p, DayType.fullBody, minutes: 45).copyWith(
        recovery: adjustForRecovery(
            const RecoveryCheck(sleep: SleepQuality.poor, soreness: Soreness.little, energy: Energy.normal)),
      )).build();
      int volume(WorkoutPlan w) => w.main.circuit
          ? w.main.rounds * w.main.exercises.length
          : w.main.exercises.fold(0, (s, e) => s + e.sets);
      expect(volume(reduced), lessThan(volume(normal)));
      expect(reduced.kind, SessionKind.recoveryReduced);
      expect(reduced.block(BlockKind.finisher), isNull);
      expect(reduced.notes.first, RecoveryMode.reduced.message);
    });

    test('recovery mode swaps the workout for a mobility flow', () {
      final p = profile();
      final plan = SessionBuilder(inputsFor(p, DayType.upper, minutes: 20).copyWith(
        recovery: adjustForRecovery(
            const RecoveryCheck(sleep: SleepQuality.poor, soreness: Soreness.very, energy: Energy.low)),
      )).build();
      expect(plan.dayType, DayType.recovery);
      expect(plan.kind, SessionKind.recovery);
      expect(plan.allExercises.every((e) => exerciseById(e.exerciseId).mobility || exerciseById(e.exerciseId).warmup),
          isTrue);
      expect(plan.allExercises.any((e) => exerciseById(e.exerciseId).impact), isFalse);
    });
  });

  group('environment mode (spec §10)', () {
    test('bedroom: no jumping and nothing that needs a large area', () {
      final p = profile(env: TrainingEnvironment.bedroom, goals: {Goal.loseFat});
      for (final day in trainingDays) {
        final plan = SessionBuilder(inputsFor(p, day, minutes: 45)).build();
        for (final e in plan.allExercises) {
          final ex = exerciseById(e.exerciseId);
          expect(ex.impact, isFalse, reason: '${ex.id} jumps in a bedroom');
          expect(ex.space, SpaceNeed.small, reason: '${ex.id} needs more space');
        }
      }
    });

    test('small space without furniture substitutes the Bulgarian split squat', () {
      final p = profile(env: TrainingEnvironment.smallSpace);
      final params = paramsFor(p);
      final filter = ExerciseFilter(p.environment, p.limitations);
      final resolved = filter.resolve(pathById(PathIds.legs), 5)!;
      expect(resolved.exerciseId, 'tempo_split_squat');
      final progress = {...inputsFor(p, DayType.lower).progress};
      progress[PathIds.legs] = progress[PathIds.legs]!.copyWith(nodeIndex: 5, amount: 10);
      final plan = SessionBuilder(inputsFor(p, DayType.lower, progress: progress)).build();
      expect(plan.allExercises.map((e) => e.exerciseId), isNot(contains('bulgarian_split_squat')));
      expect(params, isNotNull);
    });

    test('large space unlocks travelling moves', () {
      const f = ExerciseFilter(TrainingEnvironment.largeSpace, Limitations.none);
      expect(f.allowsId('shuttle_run'), isTrue);
      const g = ExerciseFilter(TrainingEnvironment.livingRoom, Limitations.none);
      expect(g.allowsId('shuttle_run'), isFalse);
    });

    test('no-jumping users never get impact moves, even outside', () {
      final p = profile(env: TrainingEnvironment.outside, lim: const Limitations(noJumping: true), goals: {Goal.loseFat});
      for (final day in trainingDays) {
        final plan = SessionBuilder(inputsFor(p, day, minutes: 45)).build();
        expect(plan.allExercises.where((e) => exerciseById(e.exerciseId).impact), isEmpty);
      }
    });

    test('limited mobility (avoid floor) gets standing alternatives everywhere', () {
      final p = profile(lim: const Limitations(avoidFloor: true, noJumping: true));
      for (final day in [...trainingDays, DayType.recovery]) {
        final plan = SessionBuilder(inputsFor(p, day, minutes: 30)).build();
        expect(plan.main.exercises, isNotEmpty, reason: '$day has nothing to do');
        for (final e in plan.allExercises) {
          expect(exerciseById(e.exerciseId).floorWork, isFalse, reason: '${e.exerciseId} is floor work');
        }
      }
    });

    test('every node of every path has a possible option in every environment', () {
      for (final env in TrainingEnvironment.values) {
        final f = ExerciseFilter(env, Limitations.none);
        for (final path in kSkillPaths) {
          for (var i = 0; i < path.length; i++) {
            expect(f.resolve(path, i), isNotNull, reason: '${path.id}#$i in ${env.name}');
          }
        }
      }
    });
  });

  group('weakest link bias', () {
    test('adds volume for the weakest area', () {
      final p = profile();
      final base = SessionBuilder(inputsFor(p, DayType.upper)).build();
      final biased = SessionBuilder(inputsFor(p, DayType.upper, weakest: Area.legs)).build();
      expect(biased.allExercises.any((e) => exerciseById(e.exerciseId).area == Area.legs), isTrue);
      expect(base.allExercises.any((e) => exerciseById(e.exerciseId).area == Area.legs && e.role != SlotRole.warmup && e.role != SlotRole.cooldown), isFalse);
      expect(biased.notes.join(), contains('weakest link'));
    });
  });

  test('visible abs goal puts core work in every session', () {
    final p = profile(goals: {Goal.visibleAbs});
    for (final day in [DayType.upper, DayType.lower, DayType.fullBody]) {
      final plan = SessionBuilder(inputsFor(p, day, minutes: 45)).build();
      expect(plan.workExercises.any((e) => exerciseById(e.exerciseId).area == Area.core), isTrue, reason: '$day');
    }
  });

  test('recovery day builds a gentle flow ending in breathing', () {
    final plan = SessionBuilder(inputsFor(profile(), DayType.recovery, minutes: 15)).build();
    expect(plan.kind, SessionKind.recovery);
    expect(plan.main.exercises.last.exerciseId, 'box_breathing');
    expect(plan.estimatedSeconds, lessThanOrEqualTo(15 * 60 * 1.05));
  });

  test('benchmark tests push, legs and plank with targets above the best', () {
    final p = profile();
    final inputs = inputsFor(p, DayType.benchmark);
    final plan = SessionBuilder(SessionInputs(
      dayType: DayType.benchmark,
      params: inputs.params,
      progress: inputs.progress,
      filter: inputs.filter,
      minutes: 30,
      bestRecords: const {'push_up': 20, 'plank': 60},
    )).build();
    final ids = plan.main.exercises.map((e) => e.exerciseId).toList();
    expect(ids, contains('plank'));
    expect(plan.main.exercises.firstWhere((e) => e.exerciseId == 'push_up').amount, 21);
    expect(plan.main.exercises.firstWhere((e) => e.exerciseId == 'plank').amount, 65);
  });

  test('rest days have no session', () {
    expect(() => SessionBuilder(inputsFor(profile(), DayType.rest)).build(), throwsArgumentError);
  });

  group('"I don\'t feel like working out" (spec §7)', () {
    for (final opt in QuickOption.values) {
      test('${opt.minutes} minutes fits and carries the message', () {
        final plan = buildQuickSession(opt, inputsFor(profile(), DayType.upper), todaysDay: DayType.upper);
        expect(plan.kind, SessionKind.lowMotivation);
        expect(plan.notes, contains(kLowMotivationMessage));
        expect(plan.estimatedSeconds, lessThanOrEqualTo(opt.minutes * 60 * 1.05 + 1));
        expect(plan.main.exercises, isNotEmpty);
      });
    }

    test('15 minutes is a reduced version of today\'s workout', () {
      final plan = buildQuickSession(QuickOption.fifteen, inputsFor(profile(), DayType.lower), todaysDay: DayType.lower);
      expect(plan.dayType, DayType.lower);
    });

    test('works on a rest day too', () {
      final plan = buildQuickSession(QuickOption.fifteen, inputsFor(profile(), DayType.fullBody), todaysDay: DayType.rest);
      expect(plan.dayType, DayType.fullBody);
    });
  });

  test('plans are deterministic for the same seed', () {
    final a = SessionBuilder(inputsFor(profile(), DayType.upper)).build();
    final b = SessionBuilder(inputsFor(profile(), DayType.upper)).build();
    expect(a.toJson(), b.toJson());
  });

  test('plan JSON round-trips', () {
    final a = SessionBuilder(inputsFor(profile(goals: {Goal.loseFat}), DayType.fullBody)).build();
    expect(WorkoutPlan.fromJson(a.toJson()).toJson(), a.toJson());
  });
}
