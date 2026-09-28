import 'package:bodyforge/domain/catalog/exercises.dart';
import 'package:bodyforge/domain/catalog/skill_paths.dart';
import 'package:bodyforge/domain/engine/adaptive_engine.dart';
import 'package:bodyforge/domain/engine/training_params.dart';
import 'package:bodyforge/domain/models/enums.dart';
import 'package:bodyforge/domain/models/profile.dart';
import 'package:bodyforge/domain/models/workout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  // Hypertrophy, novice, phase 2: push window 6–15, base 3 sets, max 4 sets.
  final params = TrainingParams.from(goals: {Goal.buildMuscle}, level: FitnessLevel.novice, phase: JourneyPhase.body);

  ProgressionResult run(TrackProgress p, List<SetResult> s, Rating r, {bool reduced = false}) =>
      applySession(current: {p.key: p}, results: s, rating: r, params: params, wasReduced: reduced);

  test('params match expectations for the test', () {
    expect(params.baseSets, 3);
    expect(params.maxSets, 4);
    expect(params.window(pushTrackExercise, pathById(PathIds.push)), (6, 15));
  });

  group('spec example: beginner push-ups 3 × 10', () {
    test('Too Easy increases repetitions (by two steps)', () {
      final res = run(pushTrack(amount: 10), sets('push_up', 'push', 3, 10, 10), Rating.tooEasy);
      final after = res.progress['push']!;
      expect(after.amount, 12);
      expect(after.sets, 3);
      expect(after.easyStreak, 1);
      expect(res.events.single.type, ProgressionType.repsUp);
    });

    test('Good progresses slightly (+1 rep)', () {
      final after = run(pushTrack(amount: 10), sets('push_up', 'push', 3, 10, 10), Rating.good).progress['push']!;
      expect(after.amount, 11);
      expect(after.easyStreak, 0);
    });

    test('Hard maintains the current level', () {
      final res = run(pushTrack(amount: 10), sets('push_up', 'push', 3, 10, 10), Rating.hard);
      expect(res.progress['push']!.amount, 10);
      expect(res.progress['push']!.sets, 3);
      expect(res.events.single.type, ProgressionType.maintained);
    });

    test('Brutal reduces volume (drops a set)', () {
      final res = run(pushTrack(amount: 10), sets('push_up', 'push', 3, 10, 10), Rating.brutal);
      expect(res.progress['push']!.sets, 2);
      expect(res.progress['push']!.hardStreak, 1);
      expect(res.events.single.type, ProgressionType.reduced);
    });

    test('two Brutal sessions in a row step back one variation', () {
      final res = run(pushTrack(node: 3, amount: 10, hard: 1), sets('push_up', 'push', 3, 10, 10), Rating.brutal);
      final after = res.progress['push']!;
      expect(after.nodeIndex, 2); // knee push-up
      expect(after.sets, params.baseSets);
      expect(after.hardStreak, 0);
      expect(res.events.single.type, ProgressionType.regressed);
    });
  });

  test('eventually introduces a harder variation: top of range at max sets unlocks', () {
    final res = run(pushTrack(node: 3, sets: 4, amount: 15), sets('push_up', 'push', 4, 15, 15), Rating.good);
    final after = res.progress['push']!;
    expect(after.nodeIndex, 4); // diamond push-up
    expect(after.sets, params.baseSets);
    expect(after.amount, 6); // bottom of the new range
    expect(res.unlocks, hasLength(1));
    expect(res.events.single.toExerciseId, 'diamond_push_up');
    expect(after.bestNodeIndex, 4);
  });

  test('passing the top of the range below max sets adds a set', () {
    final res = run(pushTrack(sets: 3, amount: 15), sets('push_up', 'push', 3, 15, 15), Rating.good);
    final after = res.progress['push']!;
    expect(after.sets, 4);
    expect(after.amount, lessThan(15));
    expect(res.events.single.type, ProgressionType.setAdded);
  });

  test('Too Easy twice in the upper half of the range unlocks early', () {
    final res = run(pushTrack(sets: 3, amount: 12, easy: 1), sets('push_up', 'push', 3, 12, 12), Rating.tooEasy);
    expect(res.progress['push']!.nodeIndex, 4);
    expect(res.events.single.type, ProgressionType.unlocked);
  });

  test('a recovery-reduced session cannot count as Too Easy', () {
    final res = run(pushTrack(amount: 10), sets('push_up', 'push', 3, 10, 10), Rating.tooEasy, reduced: true);
    expect(res.progress['push']!.amount, 11); // treated as Good
    expect(res.progress['push']!.easyStreak, 0);
  });

  test('missing the target (<70%) resets the target to what was achieved', () {
    final res = run(pushTrack(amount: 12), sets('push_up', 'push', 3, 12, 7), Rating.good);
    expect(res.progress['push']!.amount, 7);
    expect(res.events.single.type, ProgressionType.reduced);
  });

  test('70–95% completion maintains even if rated Good', () {
    final res = run(pushTrack(amount: 10), sets('push_up', 'push', 3, 10, 9), Rating.good);
    expect(res.progress['push']!.amount, 10);
  });

  test('never reduces below the bottom of the range or minimum sets', () {
    final p = TrackProgress(key: 'push', nodeIndex: 3, sets: params.minSets, amount: 6);
    final res = run(p, sets('push_up', 'push', 2, 6, 6), Rating.brutal);
    expect(res.progress['push']!.sets, params.minSets);
    expect(res.progress['push']!.amount, 6);
  });

  test('skipping every set leaves progress unchanged', () {
    final s = [
      for (var i = 0; i < 3; i++)
        SetResult(exerciseId: 'push_up', trackKey: 'push', setIndex: i, target: 10, achieved: 0, skipped: true)
    ];
    final res = run(pushTrack(amount: 10), s, Rating.tooEasy);
    expect(res.progress['push'], pushTrack(amount: 10));
    expect(res.events.single.type, ProgressionType.skipped);
  });

  test('warm-up sets never drive progression', () {
    final res = run(pushTrack(amount: 10), sets('push_up', 'push', 3, 10, 10, block: BlockKind.warmup), Rating.tooEasy);
    expect(res.events, isEmpty);
    expect(res.progress['push'], pushTrack(amount: 10));
  });

  test('accessories get their own track seeded from the session', () {
    final res = applySession(
      current: const {},
      results: sets('chair_dip', 'ex:chair_dip', 3, 10, 10),
      rating: Rating.good,
      params: params,
    );
    final t = res.progress['ex:chair_dip']!;
    expect(t.sets, 3);
    expect(t.amount, 11);
  });

  test('path top keeps building reps but is capped', () {
    final last = pathById(PathIds.push).length - 1;
    final p = TrackProgress(key: 'push', nodeIndex: last, sets: params.maxSets, amount: 15);
    final res = run(p, sets('one_arm_push_up', 'push', 4, 15, 15), Rating.tooEasy);
    expect(res.progress['push']!.nodeIndex, last);
    expect(res.progress['push']!.amount, greaterThan(15));
    expect(res.progress['push']!.amount, lessThanOrEqualTo(23));
  });

  test('phase 3 unlocks before the very top of the range', () {
    final forge = TrainingParams.from(goals: {Goal.buildMuscle}, level: FitnessLevel.novice, phase: JourneyPhase.forge);
    final p = TrackProgress(key: 'push', nodeIndex: 3, sets: forge.maxSets, amount: 14);
    final res = applySession(
        current: {'push': p}, results: sets('push_up', 'push', forge.maxSets, 14, 14), rating: Rating.good, params: forge);
    expect(res.progress['push']!.nodeIndex, 4);
  });

  test('timed exercises progress in 5-second steps', () {
    const p = TrackProgress(key: 'core', nodeIndex: 1, sets: 3, amount: 30);
    final res = applySession(
        current: {'core': p}, results: sets('plank', 'core', 3, 30, 30), rating: Rating.good, params: params);
    expect(res.progress['core']!.amount, 35);
  });
}

final pushTrackExercise = exerciseById('push_up');
