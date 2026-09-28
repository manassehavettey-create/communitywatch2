import 'enums.dart';
import 'exercise.dart';
import 'local_date.dart';

/// Onboarding "current abilities" — quick self-assessments that place the user
/// on each skill path.
enum PushAbility {
  none('Can\'t do a push-up yet'),
  knee('Knee push-ups only'),
  oneToFive('1–5 push-ups'),
  sixToFifteen('6–15 push-ups'),
  sixteenToThirty('16–30 push-ups'),
  overThirty('30+ push-ups');

  const PushAbility(this.label);
  final String label;
}

enum SquatAbility {
  needSupport('I need support to squat'),
  underTen('Under 10 squats'),
  tenToTwentyFive('10–25 squats'),
  overTwentyFive('25+ squats');

  const SquatAbility(this.label);
  final String label;
}

enum PlankAbility {
  under20('Under 20 seconds'),
  twentyTo45('20–45 seconds'),
  fortyFiveTo90('45–90 seconds'),
  over90('90+ seconds');

  const PlankAbility(this.label);
  final String label;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.sex,
    required this.heightCm,
    required this.weightKg,
    required this.level,
    required this.experience,
    required this.goals,
    required this.daysPerWeek,
    required this.sessionMinutes,
    required this.environment,
    required this.journeyStart,
    this.limitations = Limitations.none,
    this.preferredDays = const [],
    this.style = WorkoutStyle.mixed,
    this.pushAbility = PushAbility.knee,
    this.squatAbility = SquatAbility.underTen,
    this.plankAbility = PlankAbility.twentyTo45,
    this.updatedAt,
  });

  final String id;
  final String name;
  final int age;
  final Sex sex;
  final double heightCm;
  final double weightKg;
  final FitnessLevel level;
  final TrainingExperience experience;
  final Set<Goal> goals;
  final int daysPerWeek;
  final int sessionMinutes;
  final TrainingEnvironment environment;
  final Limitations limitations;

  /// Preferred weekdays (1 = Mon … 7 = Sun). Empty = let BODYFORGE choose.
  final List<int> preferredDays;
  final WorkoutStyle style;
  final PushAbility pushAbility;
  final SquatAbility squatAbility;
  final PlankAbility plankAbility;
  final LocalDate journeyStart;
  final DateTime? updatedAt;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  UserProfile copyWith({
    String? id,
    String? name,
    int? age,
    Sex? sex,
    double? heightCm,
    double? weightKg,
    FitnessLevel? level,
    TrainingExperience? experience,
    Set<Goal>? goals,
    int? daysPerWeek,
    int? sessionMinutes,
    TrainingEnvironment? environment,
    Limitations? limitations,
    List<int>? preferredDays,
    WorkoutStyle? style,
    PushAbility? pushAbility,
    SquatAbility? squatAbility,
    PlankAbility? plankAbility,
    LocalDate? journeyStart,
    DateTime? updatedAt,
  }) =>
      UserProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        age: age ?? this.age,
        sex: sex ?? this.sex,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        level: level ?? this.level,
        experience: experience ?? this.experience,
        goals: goals ?? this.goals,
        daysPerWeek: daysPerWeek ?? this.daysPerWeek,
        sessionMinutes: sessionMinutes ?? this.sessionMinutes,
        environment: environment ?? this.environment,
        limitations: limitations ?? this.limitations,
        preferredDays: preferredDays ?? this.preferredDays,
        style: style ?? this.style,
        pushAbility: pushAbility ?? this.pushAbility,
        squatAbility: squatAbility ?? this.squatAbility,
        plankAbility: plankAbility ?? this.plankAbility,
        journeyStart: journeyStart ?? this.journeyStart,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Progression state for one track (a skill path, or a single accessory
/// exercise keyed `ex:<exerciseId>`).
class TrackProgress {
  const TrackProgress({
    required this.key,
    required this.nodeIndex,
    required this.sets,
    required this.amount,
    this.easyStreak = 0,
    this.hardStreak = 0,
    this.bestNodeIndex,
    this.updatedAt,
  });

  final String key;
  final int nodeIndex;
  final int sets;

  /// Target reps, or seconds for timed exercises.
  final int amount;

  /// Consecutive "too easy" sessions at the current prescription.
  final int easyStreak;

  /// Consecutive "brutal"/failed sessions.
  final int hardStreak;

  /// Highest node ever reached (for unlock history on the skill tree).
  final int? bestNodeIndex;
  final DateTime? updatedAt;

  int get highestNode => bestNodeIndex == null ? nodeIndex : (bestNodeIndex! > nodeIndex ? bestNodeIndex! : nodeIndex);

  bool get isPath => !key.startsWith('ex:');
  static String accessoryKey(String exerciseId) => 'ex:$exerciseId';

  TrackProgress copyWith({
    int? nodeIndex,
    int? sets,
    int? amount,
    int? easyStreak,
    int? hardStreak,
    int? bestNodeIndex,
    DateTime? updatedAt,
  }) =>
      TrackProgress(
        key: key,
        nodeIndex: nodeIndex ?? this.nodeIndex,
        sets: sets ?? this.sets,
        amount: amount ?? this.amount,
        easyStreak: easyStreak ?? this.easyStreak,
        hardStreak: hardStreak ?? this.hardStreak,
        bestNodeIndex: bestNodeIndex ?? this.bestNodeIndex,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is TrackProgress &&
      other.key == key &&
      other.nodeIndex == nodeIndex &&
      other.sets == sets &&
      other.amount == amount &&
      other.easyStreak == easyStreak &&
      other.hardStreak == hardStreak;

  @override
  int get hashCode => Object.hash(key, nodeIndex, sets, amount, easyStreak, hardStreak);

  @override
  String toString() => 'Track($key #$nodeIndex ${sets}x$amount e$easyStreak h$hardStreak)';
}
