import 'enums.dart';

/// A bodyweight exercise from the built-in catalog (reference data).
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.area,
    required this.pattern,
    required this.focus,
    required this.difficulty,
    required this.demo,
    required this.cues,
    this.summary = '',
    this.mistakes = const [],
    this.unit = ExerciseUnit.reps,
    this.perSide = false,
    this.space = SpaceNeed.small,
    this.impact = false,
    this.floorWork = true,
    this.kneeStress = false,
    this.wristStress = false,
    this.props = const {},
    this.secondsPerRep = 3,
    this.family,
    this.mobility = false,
    this.warmup = false,
  });

  final String id;
  final String name;
  final Area area;
  final MovementPattern pattern;
  final Set<MuscleFocus> focus;

  /// 1 (easiest) – 10 (hardest).
  final int difficulty;

  /// Key of the animated demo drawn in code.
  final String demo;

  /// Step-by-step form cues, in order.
  final List<String> cues;
  final String summary;
  final List<String> mistakes;
  final ExerciseUnit unit;

  /// Reps / seconds are per side (the athlete does both sides).
  final bool perSide;
  final SpaceNeed space;

  /// Involves jumping / landing.
  final bool impact;

  /// Requires getting down on the floor.
  final bool floorWork;
  final bool kneeStress;
  final bool wristStress;

  /// Household items required (all of them).
  final Set<Prop> props;

  /// Tempo used for time estimates.
  final double secondsPerRep;

  /// Aggregation family, e.g. `push_up`, `squat`, `plank` (achievements, PRs).
  final String? family;

  /// Suitable for recovery / mobility flows.
  final bool mobility;

  /// Suitable as a warm-up movement.
  final bool warmup;

  bool get isTimed => unit == ExerciseUnit.seconds;

  /// Seconds one set of [amount] reps/seconds takes, sides included.
  double setSeconds(int amount) {
    final base = isTimed ? amount.toDouble() : amount * secondsPerRep;
    return perSide ? base * 2 + 5 : base;
  }

  @override
  String toString() => 'Exercise($id)';
}

/// Things about the user's body that restrict exercise choice.
class Limitations {
  const Limitations({
    this.noJumping = false,
    this.avoidFloor = false,
    this.kneeSensitive = false,
    this.wristSensitive = false,
  });

  final bool noJumping;
  final bool avoidFloor;
  final bool kneeSensitive;
  final bool wristSensitive;

  static const none = Limitations();

  Limitations copyWith({bool? noJumping, bool? avoidFloor, bool? kneeSensitive, bool? wristSensitive}) =>
      Limitations(
        noJumping: noJumping ?? this.noJumping,
        avoidFloor: avoidFloor ?? this.avoidFloor,
        kneeSensitive: kneeSensitive ?? this.kneeSensitive,
        wristSensitive: wristSensitive ?? this.wristSensitive,
      );

  Map<String, Object?> toJson() => {
        'noJumping': noJumping,
        'avoidFloor': avoidFloor,
        'kneeSensitive': kneeSensitive,
        'wristSensitive': wristSensitive,
      };

  factory Limitations.fromJson(Map<String, Object?> j) => Limitations(
        noJumping: j['noJumping'] == true,
        avoidFloor: j['avoidFloor'] == true,
        kneeSensitive: j['kneeSensitive'] == true,
        wristSensitive: j['wristSensitive'] == true,
      );

  @override
  bool operator ==(Object other) =>
      other is Limitations &&
      other.noJumping == noJumping &&
      other.avoidFloor == avoidFloor &&
      other.kneeSensitive == kneeSensitive &&
      other.wristSensitive == wristSensitive;

  @override
  int get hashCode => Object.hash(noJumping, avoidFloor, kneeSensitive, wristSensitive);
}
