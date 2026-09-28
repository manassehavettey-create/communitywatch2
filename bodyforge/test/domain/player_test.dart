import 'package:bodyforge/domain/engine/player.dart';
import 'package:bodyforge/domain/engine/environment.dart';
import 'package:bodyforge/domain/models/enums.dart';
import 'package:bodyforge/domain/models/exercise.dart';
import 'package:bodyforge/domain/models/workout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const plan = WorkoutPlan(
  title: 'Test',
  dayType: DayType.upper,
  kind: SessionKind.planned,
  objective: 'x',
  blocks: [
    PlanBlock(kind: BlockKind.warmup, circuit: true, exercises: [
      PlannedExercise(exerciseId: 'march_in_place', sets: 1, amount: 30, restSec: 5, role: SlotRole.warmup),
      PlannedExercise(exerciseId: 'arm_circles', sets: 1, amount: 30, restSec: 5, role: SlotRole.warmup),
    ]),
    PlanBlock(kind: BlockKind.main, exercises: [
      PlannedExercise(exerciseId: 'push_up', trackKey: 'push', sets: 2, amount: 10, restSec: 60, role: SlotRole.primary),
      PlannedExercise(exerciseId: 'plank', trackKey: 'core', sets: 2, amount: 30, restSec: 30, role: SlotRole.secondary),
    ]),
  ],
);

void main() {
  final t0 = DateTime.utc(2026, 9, 28, 7);

  test('flattens warm-up, sets and rests without ending on a rest', () {
    final steps = flattenPlan(plan);
    final desc = steps.map((s) => '${s.kind.name}:${s.exerciseId}').toList();
    expect(desc, [
      'work:march_in_place',
      'work:arm_circles',
      'work:push_up',
      'rest:push_up',
      'work:push_up',
      'rest:push_up',
      'work:plank',
      'rest:plank',
      'work:plank',
    ]);
    expect(steps.last.isWork, isTrue);
  });

  test('circuits alternate exercises each round with round rests', () {
    const c = WorkoutPlan(
      title: 'c',
      dayType: DayType.conditioning,
      kind: SessionKind.planned,
      objective: 'x',
      blocks: [
        PlanBlock(kind: BlockKind.main, circuit: true, rounds: 2, roundRestSec: 45, exercises: [
          PlannedExercise(exerciseId: 'squat_jump', sets: 2, amount: 10, restSec: 15, role: SlotRole.primary),
          PlannedExercise(exerciseId: 'mountain_climber', sets: 2, amount: 30, restSec: 15, role: SlotRole.secondary),
        ]),
      ],
    );
    final ids = flattenPlan(c).map((s) => '${s.kind.name}:${s.exerciseId}:${s.durationSec}').toList();
    expect(ids, [
      'work:squat_jump:0',
      'rest:squat_jump:15',
      'work:mountain_climber:30',
      'rest:mountain_climber:45',
      'work:squat_jump:0',
      'rest:squat_jump:15',
      'work:mountain_climber:30',
    ]);
  });

  test('timed steps finish on their own; rep sets wait for the user', () {
    var s = PlayerSnapshot.start('w1', plan, t0);
    s = s.catchUp(t0.add(const Duration(seconds: 65)));
    // Both 30 s warm-ups are done, now waiting on push-ups.
    expect(s.current!.exerciseId, 'push_up');
    expect(s.results, hasLength(2));
    expect(s.results.every((r) => r.blockKind == BlockKind.warmup), isTrue);
  });

  test('survives the app being killed: state restores from JSON and catches up', () {
    var s = PlayerSnapshot.start('w1', plan, t0).catchUp(t0.add(const Duration(seconds: 61)));
    s = s.completeWork(10, t0.add(const Duration(seconds: 90))); // push-ups set 1, rest starts
    expect(s.current!.isRest, isTrue);
    final saved = s.toJson();

    // App killed; relaunched 45 s later: 15 s of rest left.
    final restored = PlayerSnapshot.fromJson(saved);
    final now = t0.add(const Duration(seconds: 135));
    expect(restored.remaining(now), const Duration(seconds: 15));
    expect(restored.elapsed(now), const Duration(seconds: 135));

    // Relaunched after the rest ended: moved on to set 2.
    final later = restored.catchUp(t0.add(const Duration(seconds: 200)));
    expect(later.current!.exerciseId, 'push_up');
    expect(later.current!.setIndex, 1);
  });

  test('pause freezes the timers and resume carries on', () {
    var s = PlayerSnapshot.start('w1', plan, t0);
    s = s.pause(t0.add(const Duration(seconds: 10)));
    final during = t0.add(const Duration(minutes: 5));
    expect(s.remaining(during), const Duration(seconds: 20));
    expect(s.catchUp(during).stepIndex, 0, reason: 'nothing advances while paused');
    s = s.resume(during);
    expect(s.remaining(during), const Duration(seconds: 20));
    expect(s.elapsed(during.add(const Duration(seconds: 5))), const Duration(seconds: 15));
    expect(s.currentStepEndsAt(during), during.add(const Duration(seconds: 20)));
  });

  test('skip logs a skipped set; skip exercise jumps past its remaining sets', () {
    var s = PlayerSnapshot.start('w1', plan, t0).catchUp(t0.add(const Duration(minutes: 2)));
    s = s.skip(t0.add(const Duration(minutes: 2)));
    expect(s.results.last.skipped, isTrue);
    expect(s.current!.isRest, isTrue);
    s = PlayerSnapshot.start('w1', plan, t0).catchUp(t0.add(const Duration(minutes: 2)));
    s = s.skipExercise(t0.add(const Duration(minutes: 2)));
    expect(s.current!.exerciseId, 'plank');
    expect(s.results.where((r) => r.exerciseId == 'push_up' && r.skipped), hasLength(2));
  });

  test('swap replaces the exercise for the rest of the session, keeping the track', () {
    final p = profile();
    var s = PlayerSnapshot.start('w1', plan, t0).catchUp(t0.add(const Duration(minutes: 2)));
    s = s.swap('knee_push_up', paramsFor(p));
    expect(s.current!.exerciseId, 'knee_push_up');
    expect(s.current!.trackKey, 'push');
    expect(s.steps.where((x) => x.exerciseId == 'push_up'), isEmpty);
  });

  test('extend rest adds time', () {
    var s = PlayerSnapshot.start('w1', plan, t0).catchUp(t0.add(const Duration(seconds: 61)));
    s = s.completeWork(10, t0.add(const Duration(seconds: 90)));
    s = s.extendRest(15, t0.add(const Duration(seconds: 90)));
    expect(s.remaining(t0.add(const Duration(seconds: 90))), const Duration(seconds: 75));
  });

  test('finishes after the last step and counts reps', () {
    var s = PlayerSnapshot.start('w1', plan, t0);
    var now = t0;
    while (!s.isFinished) {
      now = now.add(const Duration(minutes: 2));
      s = s.catchUp(now);
      if (!s.isFinished && !s.current!.isClocked) s = s.completeWork(s.current!.target, now);
    }
    expect(s.totalReps, 20);
    expect(s.results.where((r) => r.exerciseId == 'plank'), hasLength(2));
    expect(s.progress, 1);
  });

  test('swap candidates respect the environment', () {
    const f = ExerciseFilter(TrainingEnvironment.bedroom, Limitations(noJumping: true));
    final c = swapCandidates('squat_jump', f.allowsId);
    expect(c, isNotEmpty);
    expect(c, isNot(contains('jumping_jack')));
  });
}
