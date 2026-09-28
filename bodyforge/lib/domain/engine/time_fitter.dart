import '../models/enums.dart';
import '../models/workout.dart';
import 'training_params.dart';

/// Minutes options for "How much time do you have?" (spec §8). 45 means 45+.
const kTimeOptions = [5, 10, 15, 20, 30, 45];

/// Fit [plan] into [minutes] while keeping the session's objective:
/// compress by removing the least important work first, or expand by adding
/// quality volume. The first primary exercise is never removed.
///
/// [expansionPool] holds extra exercises the builder is happy to add when
/// there is more time than planned. [allowExpand] is false for sessions that
/// were deliberately reduced (recovery check) — extra time never undoes that.
WorkoutPlan fitToTime(
  WorkoutPlan plan,
  int minutes, {
  required TrainingParams params,
  List<PlannedExercise> expansionPool = const [],
  bool allowExpand = true,
}) {
  final target = minutes * 60;
  var p = plan.copyWith(targetMinutes: minutes);

  // Recovery flows scale by simply adding / removing moves.
  if (plan.dayType == DayType.recovery || plan.kind == SessionKind.recovery) {
    return _fitFlow(p, target, expansionPool);
  }

  if (p.estimatedSeconds > target * 1.05) {
    for (final reduce in _reductions) {
      while (p.estimatedSeconds > target * 1.05) {
        final next = reduce(p, params);
        if (next == null) break;
        p = next;
      }
      if (p.estimatedSeconds <= target * 1.05) break;
    }
  } else if (allowExpand && p.estimatedSeconds < target * 0.8) {
    p = _expand(p, target, params, expansionPool);
  }
  return p;
}

typedef _Reduction = WorkoutPlan? Function(WorkoutPlan p, TrainingParams params);

final List<_Reduction> _reductions = [
  // 1. Drop the finisher.
  (p, _) => p.block(BlockKind.finisher) == null
      ? null
      : p.copyWith(blocks: p.blocks.where((b) => b.kind != BlockKind.finisher).toList()),
  // 2. Shorten warm-up and cool-down.
  (p, _) => _trimBlock(p, BlockKind.cooldown, keep: 1),
  (p, _) => _trimBlock(p, BlockKind.warmup, keep: 2),
  (p, _) => _shortenTimed(p, BlockKind.warmup, min: 25),
  // 3. Remove accessories, last first.
  (p, _) => _removeLastWithRole(p, SlotRole.accessory),
  // 4. Tighten rests.
  (p, params) => _tightenRests(p),
  // 5. Switch to a circuit (rest only between rounds).
  (p, _) => _toCircuit(p),
  // 6. Fewer sets / rounds, down to 2.
  (p, _) => _reduceVolume(p, floor: 2),
  // 7. Remove secondary exercises.
  (p, _) => _removeLastWithRole(p, SlotRole.secondary),
  // 8. Remove the cool-down, trim warm-up to one move.
  (p, _) => p.block(BlockKind.cooldown) == null
      ? null
      : p.copyWith(blocks: p.blocks.where((b) => b.kind != BlockKind.cooldown).toList()),
  (p, _) => _trimBlock(p, BlockKind.warmup, keep: 1),
  // 9. Down to a single set / round.
  (p, _) => _reduceVolume(p, floor: 1),
  // 10. Keep only the first two, then first primary.
  (p, _) => _keepPrimaries(p, 2),
  (p, _) => _keepPrimaries(p, 1),
  // 11. Shorter holds / fewer reps (never below 60%).
  (p, _) => _shrinkAmounts(p),
  // 12. Drop the warm-up entirely.
  (p, _) => p.block(BlockKind.warmup) == null
      ? null
      : p.copyWith(blocks: p.blocks.where((b) => b.kind != BlockKind.warmup).toList()),
];

WorkoutPlan? _trimBlock(WorkoutPlan p, BlockKind kind, {required int keep}) {
  final b = p.block(kind);
  if (b == null || b.exercises.length <= keep) return null;
  return p.replaceBlock(b.copyWith(exercises: b.exercises.take(keep).toList()));
}

WorkoutPlan? _shortenTimed(WorkoutPlan p, BlockKind kind, {required int min}) {
  final b = p.block(kind);
  if (b == null) return null;
  var changed = false;
  final ex = [
    for (final e in b.exercises)
      if (e.isTimed && e.amount > min) (() {
        changed = true;
        return e.copyWith(amount: min);
      })() else e
  ];
  return changed ? p.replaceBlock(b.copyWith(exercises: ex)) : null;
}

WorkoutPlan? _removeLastWithRole(WorkoutPlan p, SlotRole role) {
  final main = p.main;
  final idx = main.exercises.lastIndexWhere((e) => e.role == role);
  if (idx < 0) return null;
  final list = [...main.exercises]..removeAt(idx);
  if (list.isEmpty) return null;
  return p.replaceBlock(main.copyWith(exercises: list));
}

WorkoutPlan? _tightenRests(WorkoutPlan p) {
  final main = p.main;
  var changed = false;
  final list = [
    for (final e in main.exercises)
      () {
        final floor = main.circuit ? 10 : (e.role == SlotRole.primary ? 30 : 20);
        if (e.restSec > floor) {
          changed = true;
          return e.copyWith(restSec: (e.restSec - 20).clamp(floor, 999));
        }
        return e;
      }()
  ];
  var b = main.copyWith(exercises: list);
  if (main.circuit && main.roundRestSec > 30) {
    changed = true;
    b = b.copyWith(roundRestSec: (main.roundRestSec - 20).clamp(30, 999));
  }
  return changed ? p.replaceBlock(b) : null;
}

WorkoutPlan? _toCircuit(WorkoutPlan p) {
  final main = p.main;
  if (main.circuit || main.exercises.length < 2) return null;
  final rounds = main.exercises.map((e) => e.sets).reduce((a, b) => a > b ? a : b).clamp(1, 3);
  return p.replaceBlock(main.copyWith(
    circuit: true,
    rounds: rounds,
    roundRestSec: 45,
    exercises: [for (final e in main.exercises) e.copyWith(sets: rounds, restSec: 15)],
  ));
}

WorkoutPlan? _reduceVolume(WorkoutPlan p, {required int floor}) {
  final main = p.main;
  if (main.circuit) {
    if (main.rounds <= floor) return null;
    final r = main.rounds - 1;
    return p.replaceBlock(main.copyWith(rounds: r, exercises: [for (final e in main.exercises) e.copyWith(sets: r)]));
  }
  // Reduce the least important exercise that still has sets above the floor.
  var idx = -1;
  for (var i = 0; i < main.exercises.length; i++) {
    final e = main.exercises[i];
    if (e.sets > floor && (idx < 0 || e.role.priority >= main.exercises[idx].role.priority)) idx = i;
  }
  if (idx < 0) return null;
  final list = [...main.exercises];
  list[idx] = list[idx].copyWith(sets: list[idx].sets - 1);
  return p.replaceBlock(main.copyWith(exercises: list));
}

WorkoutPlan? _keepPrimaries(WorkoutPlan p, int n) {
  final main = p.main;
  if (main.exercises.length <= n) return null;
  final sorted = [...main.exercises];
  // Stable: keep original order among the kept ones.
  final keepIds = <int>{};
  final byPriority = [for (var i = 0; i < sorted.length; i++) i]
    ..sort((a, b) => sorted[a].role.priority.compareTo(sorted[b].role.priority));
  keepIds.addAll(byPriority.take(n));
  final list = [for (var i = 0; i < sorted.length; i++) if (keepIds.contains(i)) sorted[i]];
  return p.replaceBlock(main.copyWith(exercises: list));
}

WorkoutPlan? _shrinkAmounts(WorkoutPlan p) {
  final main = p.main;
  var changed = false;
  final list = [
    for (final e in main.exercises)
      () {
        final floor = (e.amount * 0.6).ceil().clamp(e.isTimed ? 15 : 4, 999);
        final next = (e.amount * 0.85).floor();
        if (next >= floor && next < e.amount) {
          changed = true;
          return e.copyWith(amount: next);
        }
        return e;
      }()
  ];
  return changed ? p.replaceBlock(main.copyWith(exercises: list)) : null;
}

WorkoutPlan _expand(WorkoutPlan p, int target, TrainingParams params, List<PlannedExercise> pool) {
  var plan = p;
  final used = {for (final e in plan.allExercises) e.exerciseId};
  final remaining = [for (final e in pool) if (!used.contains(e.exerciseId)) e];

  bool fits(WorkoutPlan x) => x.estimatedSeconds <= target * 1.02;

  var progress = true;
  while (plan.estimatedSeconds < target * 0.9 && progress) {
    progress = false;

    // 1. One more set on each primary/secondary (up to maxSets + 1).
    final main = plan.main;
    if (main.circuit) {
      if (main.rounds < 5) {
        final r = main.rounds + 1;
        final next = plan.replaceBlock(
            main.copyWith(rounds: r, exercises: [for (final e in main.exercises) e.copyWith(sets: r)]));
        if (fits(next)) {
          plan = next;
          progress = true;
          continue;
        }
      }
    } else {
      final idx = main.exercises.indexWhere(
          (e) => (e.role == SlotRole.primary || e.role == SlotRole.secondary) && e.sets < params.maxSets + 1);
      if (idx >= 0) {
        final list = [...main.exercises];
        list[idx] = list[idx].copyWith(sets: list[idx].sets + 1);
        final next = plan.replaceBlock(main.copyWith(exercises: list));
        if (fits(next)) {
          plan = next;
          progress = true;
          continue;
        }
      }
    }

    // 2. Add an accessory from the pool.
    if (remaining.isNotEmpty) {
      final add = remaining.removeAt(0);
      final m = plan.main;
      final e = m.circuit ? add.copyWith(sets: m.rounds, restSec: 15) : add;
      final next = plan.replaceBlock(m.copyWith(exercises: [...m.exercises, e]));
      if (fits(next)) {
        plan = next;
        progress = true;
        continue;
      }
    }
  }
  return plan;
}

WorkoutPlan _fitFlow(WorkoutPlan p, int target, List<PlannedExercise> pool) {
  var main = p.main;
  final used = {for (final e in main.exercises) e.exerciseId};
  final extra = [for (final e in pool) if (!used.contains(e.exerciseId)) e];
  var plan = p;
  while (plan.estimatedSeconds > target * 1.05 && main.exercises.length > 2) {
    main = main.copyWith(exercises: [...main.exercises]..removeAt(main.exercises.length - 2));
    plan = plan.replaceBlock(main);
  }
  while (plan.estimatedSeconds < target * 0.9 && extra.isNotEmpty) {
    final list = [...main.exercises];
    list.insert(list.isEmpty ? 0 : list.length - 1, extra.removeAt(0));
    final next = plan.replaceBlock(main.copyWith(exercises: list));
    if (next.estimatedSeconds > target * 1.02) break;
    main = next.main;
    plan = next;
  }
  if (plan.estimatedSeconds < target * 0.9 && main.rounds < 3 && main.exercises.isNotEmpty) {
    final next = plan.replaceBlock(main.copyWith(rounds: main.rounds + 1));
    if (next.estimatedSeconds <= target * 1.05) plan = next;
  }
  return plan;
}
