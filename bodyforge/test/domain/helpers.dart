import 'package:bodyforge/domain/catalog/skill_paths.dart';
import 'package:bodyforge/domain/engine/baseline.dart';
import 'package:bodyforge/domain/engine/environment.dart';
import 'package:bodyforge/domain/engine/session_builder.dart';
import 'package:bodyforge/domain/engine/training_params.dart';
import 'package:bodyforge/domain/models/enums.dart';
import 'package:bodyforge/domain/models/exercise.dart';
import 'package:bodyforge/domain/models/local_date.dart';
import 'package:bodyforge/domain/models/profile.dart';
import 'package:bodyforge/domain/models/workout.dart';

UserProfile profile({
  Set<Goal> goals = const {Goal.buildMuscle},
  FitnessLevel level = FitnessLevel.novice,
  TrainingEnvironment env = TrainingEnvironment.livingRoom,
  Limitations lim = Limitations.none,
  int days = 4,
  int minutes = 30,
  PushAbility push = PushAbility.sixToFifteen,
}) =>
    UserProfile(
      id: 'u1',
      name: 'Ama Mensah',
      age: 27,
      sex: Sex.female,
      heightCm: 165,
      weightKg: 68,
      level: level,
      experience: TrainingExperience.lessThan6Months,
      goals: goals,
      daysPerWeek: days,
      sessionMinutes: minutes,
      environment: env,
      limitations: lim,
      journeyStart: const LocalDate(2026, 9, 7),
      pushAbility: push,
    );

TrainingParams paramsFor(UserProfile p, {JourneyPhase phase = JourneyPhase.body}) =>
    TrainingParams.from(goals: p.goals, level: p.level, phase: phase, daysPerWeek: p.daysPerWeek);

SessionInputs inputsFor(
  UserProfile p,
  DayType day, {
  int? minutes,
  Map<String, TrackProgress>? progress,
  JourneyPhase phase = JourneyPhase.body,
  Area? weakest,
  WorkoutStyle style = WorkoutStyle.straightSets,
}) {
  final params = paramsFor(p, phase: phase);
  return SessionInputs(
    dayType: day,
    params: params,
    progress: progress ?? initialProgress(p, params),
    filter: ExerciseFilter(p.environment, p.limitations),
    minutes: minutes ?? p.sessionMinutes,
    weakest: weakest,
    style: style,
    seed: 3,
  );
}

TrackProgress pushTrack({int node = 3, int sets = 3, int amount = 10, int easy = 0, int hard = 0}) =>
    TrackProgress(key: PathIds.push, nodeIndex: node, sets: sets, amount: amount, easyStreak: easy, hardStreak: hard);

/// Sets for one track: [count] sets hitting [achieved] of [target].
List<SetResult> sets(String exerciseId, String? track, int count, int target, int achieved,
        {BlockKind block = BlockKind.main}) =>
    [
      for (var i = 0; i < count; i++)
        SetResult(
            exerciseId: exerciseId, trackKey: track, setIndex: i, target: target, achieved: achieved, blockKind: block)
    ];
