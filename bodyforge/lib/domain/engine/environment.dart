import '../catalog/exercises.dart';
import '../catalog/skill_paths.dart';
import '../models/enums.dart';
import '../models/exercise.dart';

/// What a training environment offers (spec §10).
class EnvironmentProfile {
  const EnvironmentProfile({required this.maxSpace, required this.impactOk, required this.props, required this.note});

  final SpaceNeed maxSpace;

  /// Jumping is fine (not a quiet bedroom / hotel above neighbours).
  final bool impactOk;
  final Set<Prop> props;
  final String note;
}

const Map<TrainingEnvironment, EnvironmentProfile> kEnvironmentProfiles = {
  TrainingEnvironment.bedroom: EnvironmentProfile(
      maxSpace: SpaceNeed.small, impactOk: false, props: {Prop.elevated, Prop.wall, Prop.towel},
      note: 'Quiet, compact moves. Uses your bed edge and a wall.'),
  TrainingEnvironment.livingRoom: EnvironmentProfile(
      maxSpace: SpaceNeed.medium, impactOk: true, props: {Prop.elevated, Prop.wall, Prop.towel},
      note: 'Room to move. Uses a sofa or chair.'),
  TrainingEnvironment.smallSpace: EnvironmentProfile(
      maxSpace: SpaceNeed.small, impactOk: false, props: {Prop.wall, Prop.towel},
      note: 'Everything fits in the space of a towel. No furniture needed.'),
  TrainingEnvironment.largeSpace: EnvironmentProfile(
      maxSpace: SpaceNeed.large, impactOk: true, props: {Prop.elevated, Prop.wall, Prop.towel},
      note: 'Full range: travelling moves and sprints unlocked.'),
  TrainingEnvironment.outside: EnvironmentProfile(
      maxSpace: SpaceNeed.large, impactOk: true, props: {Prop.elevated, Prop.towel},
      note: 'Open air. Uses a step, bench or low wall.'),
  TrainingEnvironment.hotelRoom: EnvironmentProfile(
      maxSpace: SpaceNeed.small, impactOk: false, props: {Prop.elevated, Prop.wall, Prop.towel},
      note: 'Quiet for the neighbours. Uses the bed and a towel.'),
};

class ExerciseFilter {
  const ExerciseFilter(this.environment, this.limitations);

  final TrainingEnvironment environment;
  final Limitations limitations;

  EnvironmentProfile get profile => kEnvironmentProfiles[environment]!;

  /// Why an exercise is excluded, or null if it's allowed.
  String? reason(Exercise e) {
    final env = profile;
    if (e.space.index > env.maxSpace.index) return 'Needs more space';
    if (e.impact && limitations.noJumping) return 'Has jumping';
    if (e.impact && !env.impactOk) return 'Too noisy for ${environment.label.toLowerCase()}';
    for (final p in e.props) {
      if (!env.props.contains(p)) return 'Needs a ${p.label.toLowerCase()}';
    }
    if (limitations.avoidFloor && e.floorWork) return 'Floor work';
    if (limitations.kneeSensitive && e.kneeStress && (e.impact || e.difficulty >= 6)) return 'Hard on the knees';
    if (limitations.wristSensitive && e.wristStress && e.difficulty >= 7) return 'Hard on the wrists';
    return null;
  }

  bool allows(Exercise e) => reason(e) == null;
  bool allowsId(String id) => allows(exerciseById(id));

  /// Resolve the exercise to use for [path] at [index]: the node itself, then
  /// its alternatives, then easier nodes. Returns null if nothing on the path
  /// is possible (caller then substitutes an accessory).
  ({String exerciseId, int index})? resolve(SkillPath path, int index) {
    for (var i = index.clamp(0, path.length - 1); i >= 0; i--) {
      final node = path.node(i);
      for (final id in [node.exerciseId, ...node.alternatives]) {
        if (allowsId(id)) return (exerciseId: id, index: i);
      }
    }
    return null;
  }

  List<Exercise> filter(Iterable<Exercise> list) => [for (final e in list) if (allows(e)) e];
}
