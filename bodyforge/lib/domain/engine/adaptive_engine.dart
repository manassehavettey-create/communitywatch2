import '../catalog/exercises.dart';
import '../catalog/skill_paths.dart';
import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/profile.dart';
import '../models/workout.dart';
import 'training_params.dart';

enum ProgressionType { repsUp, setAdded, unlocked, maintained, reduced, regressed, skipped }

class ProgressionEvent {
  const ProgressionEvent({
    required this.trackKey,
    required this.type,
    required this.before,
    required this.after,
    required this.fromExerciseId,
    required this.toExerciseId,
  });

  final String trackKey;
  final ProgressionType type;
  final TrackProgress before;
  final TrackProgress after;
  final String fromExerciseId;
  final String toExerciseId;

  bool get isUnlock => type == ProgressionType.unlocked;

  String get message {
    final to = exerciseById(toExerciseId);
    final unit = to.isTimed ? 's' : '';
    final rx = '${after.sets} × ${after.amount}$unit';
    return switch (type) {
      ProgressionType.unlocked => 'Unlocked ${to.name}! Next time: $rx',
      ProgressionType.setAdded => '${to.name}: one more set — $rx',
      ProgressionType.repsUp => '${to.name}: $rx next time',
      ProgressionType.maintained => '${to.name}: holding at $rx',
      ProgressionType.reduced => '${to.name}: eased to $rx',
      ProgressionType.regressed => 'Back to ${to.name} to rebuild — $rx',
      ProgressionType.skipped => '${exerciseById(fromExerciseId).name}: skipped, no change',
    };
  }
}

class ProgressionResult {
  const ProgressionResult(this.progress, this.events);

  /// The complete, updated progress map.
  final Map<String, TrackProgress> progress;
  final List<ProgressionEvent> events;

  Iterable<ProgressionEvent> get unlocks => events.where((e) => e.isUnlock);
}

/// The rules-based adaptive engine (spec §5 and §24). Pure function: given the
/// current progress, what was actually done and how it felt, decide the next
/// prescription for every track trained in the session.
///
/// Rules per track
/// - Performance ratio = achieved ÷ target over the sets that weren't skipped.
/// - **Brutal**, or ratio < 70% → reduce (drop a set, else fewer reps). Two
///   bad sessions in a row on a path → step back one variation.
/// - **Hard** → maintain.
/// - **Good** with ≥ 95% done → +1 step (reps or 5 s).
/// - **Too easy** with ≥ 95% done → +2 steps; twice in a row in the upper half
///   of the range → unlock the next variation early.
/// - Going past the top of the range adds a set; at max sets the next
///   variation unlocks and reps reset to the bottom of its range.
/// - A session that was already reduced for recovery can't count as "too
///   easy" (it was designed to be easy).
ProgressionResult applySession({
  required Map<String, TrackProgress> current,
  required List<SetResult> results,
  required Rating rating,
  required TrainingParams params,
  bool wasReduced = false,
  DateTime? now,
}) {
  final byTrack = <String, List<SetResult>>{};
  for (final r in results) {
    final key = r.trackKey;
    if (key == null) continue;
    if (r.blockKind == BlockKind.warmup || r.blockKind == BlockKind.cooldown) continue;
    byTrack.putIfAbsent(key, () => []).add(r);
  }

  final progress = {...current};
  final events = <ProgressionEvent>[];

  byTrack.forEach((key, sets) {
    final performedId = sets.first.exerciseId;
    final before = progress[key] ?? _seedAccessory(key, sets, params, now);
    final done = sets.where((s) => !s.skipped).toList();
    if (done.isEmpty) {
      events.add(ProgressionEvent(
          trackKey: key,
          type: ProgressionType.skipped,
          before: before,
          after: before,
          fromExerciseId: performedId,
          toExerciseId: performedId));
      progress[key] = before;
      return;
    }

    final target = done.fold<int>(0, (s, r) => s + r.target);
    final achieved = done.fold<int>(0, (s, r) => s + r.achieved);
    final ratio = target <= 0 ? 1.0 : achieved / target;
    final effective = (wasReduced && rating == Rating.tooEasy) ? Rating.good : rating;

    final path = before.isPath ? kPathById[key] : null;
    final nodeExercise = path != null ? exerciseById(path.node(before.nodeIndex).exerciseId) : exerciseById(performedId);

    ({TrackProgress p, ProgressionType t}) outcome;
    if (effective == Rating.brutal || ratio < 0.7) {
      outcome = _reduce(before, path, params, rating: effective, ratio: ratio, done: done, nodeExercise: nodeExercise);
    } else if (effective == Rating.hard || ratio < 0.95) {
      outcome = (p: before.copyWith(easyStreak: 0, hardStreak: 0), t: ProgressionType.maintained);
    } else if (effective == Rating.good) {
      outcome = _increase(before.copyWith(easyStreak: 0, hardStreak: 0), path, params, 1, nodeExercise);
    } else {
      final streak = before.easyStreak + 1;
      final b = before.copyWith(easyStreak: streak, hardStreak: 0);
      final (lo, hi) = params.window(nodeExercise, path);
      final upperHalf = before.amount >= lo + (hi - lo) / 2;
      if (path != null && streak >= 2 && upperHalf && before.sets >= params.baseSets && before.nodeIndex < path.length - 1) {
        outcome = (p: _unlock(b, path, params), t: ProgressionType.unlocked);
      } else {
        outcome = _increase(b, path, params, 2, nodeExercise);
      }
    }

    final after = outcome.p.copyWith(
      updatedAt: now,
      bestNodeIndex: outcome.p.nodeIndex > before.highestNode ? outcome.p.nodeIndex : before.highestNode,
    );
    progress[key] = after;
    final toId = path != null ? path.node(after.nodeIndex).exerciseId : performedId;
    events.add(ProgressionEvent(
      trackKey: key,
      type: outcome.t,
      before: before,
      after: after,
      fromExerciseId: performedId,
      toExerciseId: toId,
    ));
  });

  return ProgressionResult(progress, events);
}

TrackProgress _seedAccessory(String key, List<SetResult> sets, TrainingParams params, DateTime? now) {
  final first = sets.first;
  final plannedSets = sets.map((s) => s.setIndex).fold<int>(0, (m, i) => i + 1 > m ? i + 1 : m);
  return TrackProgress(
    key: key,
    nodeIndex: 0,
    sets: plannedSets < 1 ? params.baseSets : plannedSets,
    amount: first.target,
    updatedAt: now,
  );
}

TrackProgress _unlock(TrackProgress p, SkillPath path, TrainingParams params) {
  final next = p.nodeIndex + 1;
  final (lo, _) = params.nodeWindow(path, next);
  return p.copyWith(nodeIndex: next, sets: params.baseSets, amount: lo, easyStreak: 0, hardStreak: 0);
}

({TrackProgress p, ProgressionType t}) _increase(
    TrackProgress p, SkillPath? path, TrainingParams params, int steps, Exercise nodeExercise) {
  final (lo, hi) = params.window(nodeExercise, path);
  final top = path != null ? params.unlockAt(nodeExercise, path) : hi;
  var amount = p.amount;
  for (var i = 0; i < steps; i++) {
    amount += TrainingParams.step(nodeExercise, amount);
  }
  if (amount <= top) return (p: p.copyWith(amount: amount), t: ProgressionType.repsUp);

  // Past the top of the range: add a set, else unlock the next variation.
  if (p.sets < params.maxSets) {
    final reset = lo + ((hi - lo) / 3).round();
    return (p: p.copyWith(sets: p.sets + 1, amount: reset), t: ProgressionType.setAdded);
  }
  if (path != null && p.nodeIndex < path.length - 1) {
    return (p: _unlock(p, path, params), t: ProgressionType.unlocked);
  }
  // Top of the path (or an accessory at max sets): keep building reps, capped.
  final cap = (hi * 1.5).round();
  if (p.amount >= cap) return (p: p, t: ProgressionType.maintained);
  return (p: p.copyWith(amount: amount > cap ? cap : amount), t: ProgressionType.repsUp);
}

({TrackProgress p, ProgressionType t}) _reduce(
  TrackProgress p,
  SkillPath? path,
  TrainingParams params, {
  required Rating rating,
  required double ratio,
  required List<SetResult> done,
  required Exercise nodeExercise,
}) {
  final streak = p.hardStreak + 1;
  final base = p.copyWith(hardStreak: streak, easyStreak: 0);

  if (path != null && streak >= 2 && p.nodeIndex > 0) {
    final prev = p.nodeIndex - 1;
    final (lo, hi) = params.nodeWindow(path, prev);
    return (
      p: base.copyWith(nodeIndex: prev, sets: params.baseSets, amount: (lo + (hi - lo) * 0.6).round(), hardStreak: 0),
      t: ProgressionType.regressed,
    );
  }

  final (lo, _) = params.window(nodeExercise, path);
  if (ratio < 0.7 && rating != Rating.brutal) {
    // Couldn't hit the numbers: set the target to what was actually achieved.
    final avg = (done.fold<int>(0, (s, r) => s + r.achieved) / done.length).round();
    final amount = avg < lo ? lo : (avg < p.amount ? avg : p.amount);
    return (p: base.copyWith(amount: amount), t: ProgressionType.reduced);
  }
  if (p.sets > params.minSets) {
    return (p: base.copyWith(sets: p.sets - 1), t: ProgressionType.reduced);
  }
  final step = TrainingParams.step(nodeExercise, p.amount);
  final amount = p.amount - step < lo ? lo : p.amount - step;
  return (p: base.copyWith(amount: amount), t: amount == p.amount ? ProgressionType.maintained : ProgressionType.reduced);
}

/// Area of the skill path a track key belongs to (null for accessories).
Area? areaOfTrack(String key) => kPathById[key]?.area;
