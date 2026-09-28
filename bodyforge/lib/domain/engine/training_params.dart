import '../catalog/exercises.dart';
import '../catalog/skill_paths.dart';
import '../models/enums.dart';
import '../models/exercise.dart';

enum RepMode { strength, hypertrophy, endurance }

/// Everything the builder and the adaptive engine need to know about *how*
/// this person should train, derived from goals, level, journey phase and
/// frequency. Pure data — easy to test.
class TrainingParams {
  const TrainingParams({
    required this.repMode,
    required this.baseSets,
    required this.maxSets,
    required this.minSets,
    required this.restSec,
    required this.accessoryRestSec,
    required this.preferCircuit,
    required this.finisher,
    required this.extraCore,
    required this.unlockEarly,
    required this.phase,
  });

  final RepMode repMode;
  final int baseSets;
  final int maxSets;
  final int minSets;
  final int restSec;
  final int accessoryRestSec;
  final bool preferCircuit;
  final bool finisher;
  final bool extraCore;

  /// Phase 3: unlock the next variation before hitting the very top of the range.
  final bool unlockEarly;
  final JourneyPhase phase;

  factory TrainingParams.from({
    required Set<Goal> goals,
    required FitnessLevel level,
    JourneyPhase phase = JourneyPhase.habit,
    int daysPerWeek = 3,
  }) {
    final g = goals.isEmpty ? {Goal.fullTransformation} : goals;
    final strength = g.contains(Goal.getStronger);
    final muscle = g.contains(Goal.buildMuscle) || g.contains(Goal.fullTransformation);
    final fatLoss = g.contains(Goal.loseFat) || g.contains(Goal.fullTransformation) || g.contains(Goal.visibleAbs);
    final abs = g.contains(Goal.visibleAbs) || g.contains(Goal.fullTransformation);

    final RepMode mode;
    if (strength && !fatLoss) {
      mode = RepMode.strength;
    } else if (fatLoss && !muscle && !strength) {
      mode = RepMode.endurance;
    } else {
      mode = RepMode.hypertrophy;
    }

    var (base, max, min) = switch (level) {
      FitnessLevel.beginner => (2, 3, 1),
      FitnessLevel.novice => (3, 4, 2),
      FitnessLevel.intermediate => (3, 4, 2),
      FitnessLevel.advanced => (3, 5, 2),
    };
    if (phase == JourneyPhase.habit) max -= 1;
    if (daysPerWeek >= 6) max -= 1;
    if (max < base) max = base;

    var rest = switch (mode) {
      RepMode.strength => 90,
      RepMode.hypertrophy => 60,
      RepMode.endurance => 40,
    };
    if (phase == JourneyPhase.habit) rest += 15;

    return TrainingParams(
      repMode: mode,
      baseSets: base,
      maxSets: max,
      minSets: min,
      restSec: rest,
      accessoryRestSec: (rest - 15).clamp(30, 120),
      preferCircuit: fatLoss && !strength,
      finisher: fatLoss,
      extraCore: abs,
      unlockEarly: phase == JourneyPhase.forge,
      phase: phase,
    );
  }

  /// Target window (min, max) for [exercise]; [path] supplies the base range
  /// for path exercises.
  (int, int) window(Exercise exercise, [SkillPath? path]) {
    if (exercise.isTimed) {
      final (lo, hi) = path?.holdRange ?? (20, 45);
      return switch (repMode) {
        RepMode.strength => (lo, hi),
        RepMode.hypertrophy => (lo, hi),
        RepMode.endurance => (lo + 5, hi + 15),
      };
    }
    final (lo, hi) = path?.repRange ?? (8, 15);
    return switch (repMode) {
      RepMode.strength => (lo - 2 < 3 ? 3 : lo - 2, (lo + hi) ~/ 2 < lo + 3 ? lo + 3 : (lo + hi) ~/ 2),
      RepMode.hypertrophy => (lo, hi),
      RepMode.endurance => (lo + 2, hi + 5),
    };
  }

  /// The top of the window at which the next variation unlocks.
  int unlockAt(Exercise exercise, [SkillPath? path]) {
    final (lo, hi) = window(exercise, path);
    return unlockEarly ? (lo + (hi - lo) * 0.85).round() : hi;
  }

  /// Increment for one progression step.
  static int step(Exercise exercise, int amount) => exercise.isTimed ? 5 : (amount >= 15 ? 2 : 1);

  /// Convert an amount prescribed for [from] to the equivalent position in
  /// [to]'s window (used when an alternative has a different unit).
  int convertAmount(int amount, Exercise from, Exercise to, [SkillPath? path]) {
    if (from.unit == to.unit) return amount;
    final (a0, a1) = window(from, path);
    final (b0, b1) = window(to, path);
    final frac = a1 == a0 ? 0.0 : ((amount - a0) / (a1 - a0)).clamp(0.0, 1.0);
    return (b0 + frac * (b1 - b0)).round();
  }

  /// Window for the path node at [index].
  (int, int) nodeWindow(SkillPath path, int index) => window(exerciseById(path.node(index).exerciseId), path);
}
