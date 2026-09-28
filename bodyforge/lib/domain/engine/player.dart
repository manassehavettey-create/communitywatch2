import '../catalog/exercises.dart';
import '../catalog/skill_paths.dart';
import '../models/enums.dart';
import '../models/workout.dart';
import 'training_params.dart';

enum StepKind { work, rest }

/// One screen of the guided player: a set to perform, or a rest.
class PlayerStep {
  const PlayerStep({
    required this.kind,
    required this.block,
    required this.blockIndex,
    required this.exerciseIndex,
    required this.exerciseId,
    required this.setIndex,
    required this.totalSets,
    required this.target,
    required this.timed,
    required this.durationSec,
    this.trackKey,
    this.nextExerciseId,
  });

  final StepKind kind;
  final BlockKind block;
  final int blockIndex;
  final int exerciseIndex;
  final String exerciseId;
  final String? trackKey;

  /// 0-based set (or round) number for this exercise.
  final int setIndex;
  final int totalSets;

  /// Reps, or seconds per side for timed work.
  final int target;
  final bool timed;

  /// Seconds for rests and timed work (both sides included). 0 for rep sets.
  final int durationSec;

  /// For rests: what comes next.
  final String? nextExerciseId;

  bool get isWork => kind == StepKind.work;
  bool get isRest => kind == StepKind.rest;

  /// Steps that run on a clock and finish on their own.
  bool get isClocked => isRest || timed;
}

/// Minimum rest worth showing as its own screen.
const _minRestSec = 10;

/// Expand a plan into the linear sequence the player walks through.
List<PlayerStep> flattenPlan(WorkoutPlan plan) {
  final steps = <PlayerStep>[];
  final benchmark = plan.dayType == DayType.benchmark;

  PlayerStep work(PlanBlock b, int bi, int ei, PlannedExercise p, int set, int total) {
    final ex = exerciseById(p.exerciseId);
    final timed = ex.isTimed;
    final duration = timed ? (ex.perSide ? p.amount * 2 + 5 : p.amount) : 0;
    return PlayerStep(
      kind: StepKind.work,
      block: b.kind,
      blockIndex: bi,
      exerciseIndex: ei,
      exerciseId: p.exerciseId,
      trackKey: p.trackKey,
      setIndex: set,
      totalSets: total,
      target: p.amount,
      // Benchmark holds count up until the user stops.
      timed: timed && !benchmark,
      durationSec: benchmark ? 0 : duration,
    );
  }

  PlayerStep rest(PlanBlock b, int bi, int ei, String exId, int seconds, String? nextId) => PlayerStep(
        kind: StepKind.rest,
        block: b.kind,
        blockIndex: bi,
        exerciseIndex: ei,
        exerciseId: exId,
        setIndex: 0,
        totalSets: 0,
        target: 0,
        timed: true,
        durationSec: seconds,
        nextExerciseId: nextId,
      );

  for (var bi = 0; bi < plan.blocks.length; bi++) {
    final b = plan.blocks[bi];
    if (b.exercises.isEmpty) continue;
    if (b.circuit) {
      for (var r = 0; r < b.rounds; r++) {
        for (var ei = 0; ei < b.exercises.length; ei++) {
          final p = b.exercises[ei];
          steps.add(work(b, bi, ei, p, r, b.rounds));
          final lastInRound = ei == b.exercises.length - 1;
          if (!lastInRound && p.restSec >= _minRestSec) {
            steps.add(rest(b, bi, ei, p.exerciseId, p.restSec, b.exercises[ei + 1].exerciseId));
          }
        }
        if (r < b.rounds - 1 && b.roundRestSec >= _minRestSec) {
          steps.add(rest(b, bi, b.exercises.length - 1, b.exercises.last.exerciseId, b.roundRestSec,
              b.exercises.first.exerciseId));
        }
      }
    } else {
      for (var ei = 0; ei < b.exercises.length; ei++) {
        final p = b.exercises[ei];
        for (var s = 0; s < p.sets; s++) {
          steps.add(work(b, bi, ei, p, s, p.sets));
          final lastSet = s == p.sets - 1;
          final lastEx = ei == b.exercises.length - 1;
          if (p.restSec >= _minRestSec && !(lastSet && lastEx)) {
            final nextId = lastSet ? b.exercises[ei + 1].exerciseId : p.exerciseId;
            steps.add(rest(b, bi, ei, p.exerciseId, p.restSec, nextId));
          }
        }
      }
    }
  }
  // Never end on a rest.
  while (steps.isNotEmpty && steps.last.isRest) {
    steps.removeLast();
  }
  return steps;
}

/// Persisted, immutable state of a running workout. Every time-based value is
/// derived from wall-clock timestamps, so the timer is correct after the app
/// was backgrounded or killed and relaunched.
class PlayerSnapshot {
  const PlayerSnapshot({
    required this.workoutId,
    required this.plan,
    required this.stepIndex,
    required this.startedAt,
    required this.stepStartedAt,
    this.pausedAt,
    this.pausedTotalMs = 0,
    this.stepPausedMs = 0,
    this.stepExtraSec = 0,
    this.results = const [],
  });

  factory PlayerSnapshot.start(String workoutId, WorkoutPlan plan, DateTime now) => PlayerSnapshot(
        workoutId: workoutId,
        plan: plan,
        stepIndex: 0,
        startedAt: now,
        stepStartedAt: now,
      );

  final String workoutId;
  final WorkoutPlan plan;
  final int stepIndex;
  final DateTime startedAt;
  final DateTime stepStartedAt;
  final DateTime? pausedAt;

  /// Paused time across the whole session.
  final int pausedTotalMs;

  /// Paused time within the current step.
  final int stepPausedMs;

  /// Seconds added to the current step (e.g. "+15 s" on a rest).
  final int stepExtraSec;
  final List<SetResult> results;

  List<PlayerStep> get steps => flattenPlan(plan);
  bool get isPaused => pausedAt != null;
  bool get isFinished => stepIndex >= steps.length;
  PlayerStep? get current {
    final s = steps;
    return stepIndex < s.length ? s[stepIndex] : null;
  }

  PlayerStep? get nextWork {
    final s = steps;
    for (var i = stepIndex + 1; i < s.length; i++) {
      if (s[i].isWork) return s[i];
    }
    return null;
  }

  int _pausedNow(DateTime now) => pausedAt == null ? 0 : now.difference(pausedAt!).inMilliseconds;

  /// Active (unpaused) time since the start.
  Duration elapsed(DateTime now) =>
      Duration(milliseconds: now.difference(startedAt).inMilliseconds - pausedTotalMs - _pausedNow(now))
          .clampNonNegative();

  /// Active time in the current step.
  Duration stepElapsed(DateTime now) =>
      Duration(milliseconds: now.difference(stepStartedAt).inMilliseconds - stepPausedMs - _pausedNow(now))
          .clampNonNegative();

  /// Remaining time for clocked steps (null for rep sets).
  Duration? remaining(DateTime now) {
    final step = current;
    if (step == null || !step.isClocked) return null;
    final left = Duration(seconds: step.durationSec + stepExtraSec) - stepElapsed(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// When the current clocked step ends, if running (for notifications).
  DateTime? currentStepEndsAt(DateTime now) {
    final r = remaining(now);
    if (r == null || isPaused) return null;
    return now.add(r);
  }

  /// 0..1 through the whole session by step count.
  double get progress {
    final n = steps.length;
    return n == 0 ? 1 : (stepIndex / n).clamp(0.0, 1.0);
  }

  PlayerSnapshot _copy({
    WorkoutPlan? plan,
    int? stepIndex,
    DateTime? stepStartedAt,
    DateTime? pausedAt,
    bool clearPause = false,
    int? pausedTotalMs,
    int? stepPausedMs,
    int? stepExtraSec,
    List<SetResult>? results,
  }) =>
      PlayerSnapshot(
        workoutId: workoutId,
        plan: plan ?? this.plan,
        stepIndex: stepIndex ?? this.stepIndex,
        startedAt: startedAt,
        stepStartedAt: stepStartedAt ?? this.stepStartedAt,
        pausedAt: clearPause ? null : (pausedAt ?? this.pausedAt),
        pausedTotalMs: pausedTotalMs ?? this.pausedTotalMs,
        stepPausedMs: stepPausedMs ?? this.stepPausedMs,
        stepExtraSec: stepExtraSec ?? this.stepExtraSec,
        results: results ?? this.results,
      );

  PlayerSnapshot pause(DateTime now) => isPaused || isFinished ? this : _copy(pausedAt: now);

  PlayerSnapshot resume(DateTime now) {
    if (!isPaused) return this;
    final p = _pausedNow(now);
    return _copy(clearPause: true, pausedTotalMs: pausedTotalMs + p, stepPausedMs: stepPausedMs + p);
  }

  SetResult _result(PlayerStep s, int achieved, DateTime at, {bool skipped = false}) => SetResult(
        exerciseId: s.exerciseId,
        trackKey: s.trackKey,
        setIndex: s.setIndex,
        target: s.target,
        achieved: achieved,
        skipped: skipped,
        blockKind: s.block,
        completedAt: at.toUtc(),
      );

  PlayerSnapshot _moveTo(int index, DateTime stepStart, List<SetResult> results) =>
      _copy(stepIndex: index, stepStartedAt: stepStart, stepPausedMs: 0, stepExtraSec: 0, results: results);

  /// Log a completed rep set (or a benchmark hold) and move on.
  PlayerSnapshot completeWork(int achieved, DateTime now) {
    final s = current;
    if (s == null || !s.isWork) return this;
    final resumed = resume(now);
    return resumed._moveTo(stepIndex + 1, now, [...results, _result(s, achieved < 0 ? 0 : achieved, now)]);
  }

  /// Skip the current step (a work step is logged as skipped).
  PlayerSnapshot skip(DateTime now) {
    final s = current;
    if (s == null) return this;
    final resumed = resume(now);
    final r = s.isWork ? [...results, _result(s, 0, now, skipped: true)] : results;
    return resumed._moveTo(stepIndex + 1, now, r);
  }

  /// Skip every remaining set of the current exercise in this block.
  PlayerSnapshot skipExercise(DateTime now) {
    final s = current;
    if (s == null) return this;
    final all = steps;
    var i = stepIndex;
    final r = [...results];
    // Skip forward to the next work step that belongs to a different exercise
    // (in a circuit that is the next exercise of the round).
    while (i < all.length) {
      final st = all[i];
      if (st.isWork && (st.blockIndex != s.blockIndex || st.exerciseIndex != s.exerciseIndex)) break;
      if (st.isWork) r.add(_result(st, 0, now, skipped: true));
      i++;
    }
    return resume(now)._moveTo(i, now, r);
  }

  /// Add seconds to the current rest.
  PlayerSnapshot extendRest(int seconds, DateTime now) {
    final s = current;
    if (s == null || !s.isRest) return this;
    return _copy(stepExtraSec: stepExtraSec + seconds);
  }

  /// Replace the current exercise with [newExerciseId] for the rest of the
  /// session (same block/slot), converting the prescription if units differ.
  PlayerSnapshot swap(String newExerciseId, TrainingParams params) {
    final s = current;
    if (s == null) return this;
    final block = plan.blocks[s.blockIndex];
    final old = block.exercises[s.exerciseIndex];
    final from = exerciseById(old.exerciseId);
    final to = exerciseById(newExerciseId);
    final path = old.trackKey == null ? null : kPathById[old.trackKey];
    final amount = params.convertAmount(old.amount, from, to, path);
    final list = [...block.exercises];
    list[s.exerciseIndex] = old.copyWith(exerciseId: newExerciseId, amount: amount);
    final newPlan = plan.copyWith(blocks: [
      for (var i = 0; i < plan.blocks.length; i++) i == s.blockIndex ? block.copyWith(exercises: list) : plan.blocks[i]
    ]);
    return _copy(plan: newPlan);
  }

  /// Complete clocked steps whose time has run out — including several in a
  /// row after the app was killed. Stops at rep sets (they need the user).
  PlayerSnapshot catchUp(DateTime now) {
    if (isPaused) return this;
    var snap = this;
    var guard = 0;
    while (!snap.isFinished && guard++ < 500) {
      final s = snap.current!;
      if (!s.isClocked) break;
      final end = snap.stepStartedAt
          .add(Duration(milliseconds: snap.stepPausedMs))
          .add(Duration(seconds: s.durationSec + snap.stepExtraSec));
      if (now.isBefore(end)) break;
      final r = s.isWork ? [...snap.results, snap._result(s, s.target, end)] : snap.results;
      snap = snap._moveTo(snap.stepIndex + 1, end, r);
    }
    return snap;
  }

  /// Total reps logged (both sides counted for per-side exercises).
  int get totalReps => results
      .where((r) => !r.skipped && !r.isTimed && r.blockKind != BlockKind.warmup && r.blockKind != BlockKind.cooldown)
      .fold(0, (s, r) => s + r.achieved * (exerciseById(r.exerciseId).perSide ? 2 : 1));

  Map<String, Object?> toJson() => {
        'id': workoutId,
        'plan': plan.toJson(),
        'i': stepIndex,
        'start': startedAt.toUtc().toIso8601String(),
        'stepStart': stepStartedAt.toUtc().toIso8601String(),
        if (pausedAt != null) 'paused': pausedAt!.toUtc().toIso8601String(),
        'pt': pausedTotalMs,
        'sp': stepPausedMs,
        'sx': stepExtraSec,
        'r': [for (final r in results) r.toJson()],
      };

  factory PlayerSnapshot.fromJson(Map<String, Object?> j) => PlayerSnapshot(
        workoutId: j['id']! as String,
        plan: WorkoutPlan.fromJson((j['plan']! as Map).cast<String, Object?>()),
        stepIndex: (j['i']! as num).toInt(),
        startedAt: DateTime.parse(j['start']! as String),
        stepStartedAt: DateTime.parse(j['stepStart']! as String),
        pausedAt: j['paused'] == null ? null : DateTime.parse(j['paused']! as String),
        pausedTotalMs: (j['pt'] as num?)?.toInt() ?? 0,
        stepPausedMs: (j['sp'] as num?)?.toInt() ?? 0,
        stepExtraSec: (j['sx'] as num?)?.toInt() ?? 0,
        results: [for (final r in (j['r'] as List? ?? const [])) SetResult.fromJson((r as Map).cast<String, Object?>())],
      );
}

extension on Duration {
  Duration clampNonNegative() => isNegative ? Duration.zero : this;
}

/// Swap candidates: same movement pattern (or area), allowed here, similar
/// difficulty, excluding the current exercise.
List<String> swapCandidates(String exerciseId, bool Function(String id) allowed) {
  final ex = exerciseById(exerciseId);
  final same = kExercises.where((e) =>
      e.id != ex.id &&
      !e.mobility &&
      (e.pattern == ex.pattern || (e.area == ex.area && e.focus.intersection(ex.focus).isNotEmpty)) &&
      (e.difficulty - ex.difficulty).abs() <= 2 &&
      allowed(e.id));
  final list = same.toList()
    ..sort((a, b) {
      final pa = a.pattern == ex.pattern ? 0 : 1;
      final pb = b.pattern == ex.pattern ? 0 : 1;
      if (pa != pb) return pa - pb;
      return (a.difficulty - ex.difficulty).abs().compareTo((b.difficulty - ex.difficulty).abs());
    });
  return [for (final e in list.take(8)) e.id];
}
