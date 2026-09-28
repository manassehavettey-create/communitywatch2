import '../catalog/exercises.dart';
import '../catalog/skill_paths.dart';
import '../models/enums.dart';
import '../models/profile.dart';
import 'training_params.dart';

/// Places a new user on every skill path from their onboarding answers.
Map<String, TrackProgress> initialProgress(UserProfile p, TrainingParams params, {DateTime? now}) {
  final levelIndex = switch (p.level) {
    FitnessLevel.beginner => 0,
    FitnessLevel.novice => 1,
    FitnessLevel.intermediate => 2,
    FitnessLevel.advanced => 3,
  };

  // (node index, position within the window 0..1)
  final (pushNode, pushPos) = switch (p.pushAbility) {
    PushAbility.none => (0, 0.3),
    PushAbility.knee => (2, 0.0),
    PushAbility.oneToFive => (2, 0.6),
    PushAbility.sixToFifteen => (3, 0.2),
    PushAbility.sixteenToThirty => (4, 0.0),
    PushAbility.overThirty => (5, 0.0),
  };
  final (legNode, legPos) = switch (p.squatAbility) {
    SquatAbility.needSupport => (0, 0.2),
    SquatAbility.underTen => (1, 0.0),
    SquatAbility.tenToTwentyFive => (2, 0.2),
    SquatAbility.overTwentyFive => (3, 0.2),
  };
  final (coreNode, corePos) = switch (p.plankAbility) {
    PlankAbility.under20 => (0, 0.3),
    PlankAbility.twentyTo45 => (1, 0.2),
    PlankAbility.fortyFiveTo90 => (2, 0.2),
    PlankAbility.over90 => (3, 0.3),
  };

  final placement = <String, (int, double)>{
    PathIds.push: (pushNode, pushPos),
    PathIds.legs: (legNode, legPos),
    PathIds.core: (coreNode, corePos),
    PathIds.back: (levelIndex.clamp(0, 3), 0.2),
    PathIds.hips: (levelIndex.clamp(0, 3), 0.2),
    PathIds.conditioning: (levelIndex.clamp(0, 3), 0.2),
  };

  final result = <String, TrackProgress>{};
  placement.forEach((pathId, v) {
    final path = pathById(pathId);
    final index = v.$1.clamp(0, path.length - 1);
    final ex = exerciseById(path.node(index).exerciseId);
    final (lo, hi) = params.window(ex, path);
    final amount = (lo + (hi - lo) * v.$2).round();
    result[pathId] = TrackProgress(
      key: pathId,
      nodeIndex: index,
      sets: params.baseSets,
      amount: amount,
      bestNodeIndex: index,
      updatedAt: now,
    );
  });
  return result;
}
