/// Core enumerations shared by the engine, database and UI.
/// Pure Dart: no Flutter imports anywhere under lib/domain.
library;

T enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

enum Sex {
  male('Male'),
  female('Female'),
  other('Prefer not to say');

  const Sex(this.label);
  final String label;
}

enum FitnessLevel {
  beginner('Beginner', 'New to training or returning after a long break'),
  novice('Novice', 'Some training, still building the basics'),
  intermediate('Intermediate', 'Train regularly and know the main movements'),
  advanced('Advanced', 'Years of consistent training');

  const FitnessLevel(this.label, this.description);
  final String label;
  final String description;
}

enum TrainingExperience {
  none('Never trained'),
  lessThan6Months('Less than 6 months'),
  sixTo24Months('6 months – 2 years'),
  over2Years('2+ years');

  const TrainingExperience(this.label);
  final String label;
}

enum Goal {
  buildMuscle('Build Muscle', 'Develop muscle using progressive bodyweight resistance.'),
  loseFat('Lose Body Fat', 'Improve fitness and support overall body-fat reduction.'),
  visibleAbs('Build Visible Abs', 'Develop the abdominal muscles while working toward lower overall body fat.'),
  getStronger('Get Stronger', 'Improve performance in bodyweight movements.'),
  fullTransformation(
      'Full Transformation', 'Combine strength, muscle development, conditioning and body-composition goals.');

  const Goal(this.label, this.description);
  final String label;
  final String description;
}

/// Environment mode (spec §10).
enum TrainingEnvironment {
  bedroom('Bedroom'),
  livingRoom('Living room'),
  smallSpace('Small space'),
  largeSpace('Large space'),
  outside('Outside'),
  hotelRoom('Hotel room');

  const TrainingEnvironment(this.label);
  final String label;
}

/// How much floor an exercise needs.
enum SpaceNeed { small, medium, large }

/// Household items an exercise may use. Strictly household only (no table rows).
enum Prop {
  elevated('Chair, bed or sofa'),
  wall('Wall'),
  towel('Towel');

  const Prop(this.label);
  final String label;
}

/// The four weakest-link areas (spec §11).
enum Area {
  upper('Upper body'),
  core('Core'),
  legs('Legs'),
  conditioning('Conditioning');

  const Area(this.label);
  final String label;
}

/// Finer muscle focus used by Build-your-own and the library filters.
enum MuscleFocus {
  chest('Chest'),
  arms('Arms'),
  shoulders('Shoulders'),
  back('Back'),
  legs('Legs'),
  core('Core'),
  fullBody('Full body');

  const MuscleFocus(this.label);
  final String label;
}

enum MovementPattern { push, pull, squat, lunge, hinge, coreAnterior, coreLateral, coreRotation, conditioning, mobility }

enum ExerciseUnit { reps, seconds }

/// Type of a training day.
enum DayType {
  upper('Upper Body'),
  lower('Lower Body'),
  core('Core'),
  upperCore('Upper Body + Core'),
  fullBody('Full Body'),
  conditioning('Conditioning + Core'),
  recovery('Recovery'),
  rest('Rest'),
  benchmark('Benchmark Test');

  const DayType(this.label);
  final String label;

  bool get isTraining => this != rest;
}

enum Rating {
  tooEasy('Too Easy'),
  good('Good'),
  hard('Hard'),
  brutal('Brutal');

  const Rating(this.label);
  final String label;
}

enum SleepQuality {
  poor('Poor'),
  okay('Okay'),
  good('Good');

  const SleepQuality(this.label);
  final String label;
}

enum Soreness {
  none('Not sore'),
  little('A little sore'),
  very('Very sore');

  const Soreness(this.label);
  final String label;
}

enum Energy {
  low('Low'),
  normal('Normal'),
  high('High');

  const Energy(this.label);
  final String label;
}

/// How a session came to be — drives calendar colouring.
enum SessionKind {
  planned('Workout'),
  timeAdjusted('Time-adjusted'),
  lowMotivation('Quick session'),
  recoveryReduced('Recovery-adjusted'),
  recovery('Recovery'),
  benchmark('Benchmark'),
  custom('Custom');

  const SessionKind(this.label);
  final String label;

  /// Whether the calendar shows this as a "modified" workout.
  bool get isModified => this == timeAdjusted || this == lowMotivation || this == recoveryReduced;
}

enum WorkoutStyle {
  straightSets('Straight sets', 'Finish all sets of one exercise before moving on'),
  circuits('Circuits', 'Rotate through exercises in rounds'),
  mixed('Let BODYFORGE decide', 'Circuits when time is short, straight sets otherwise');

  const WorkoutStyle(this.label, this.description);
  final String label;
  final String description;
}

enum MeasurementType {
  weight('Weight', 'kg'),
  waist('Waist', 'cm'),
  chest('Chest', 'cm'),
  arms('Arms', 'cm'),
  thighs('Thighs', 'cm'),
  hips('Hips', 'cm'),
  custom('Custom', 'cm');

  const MeasurementType(this.label, this.metricUnit);
  final String label;
  final String metricUnit;
}

enum JourneyPhase {
  habit('Build the Habit', 'Weeks 1–4', 'Learn proper movement. Establish consistency. Build baseline strength. Understand your body.'),
  body('Build the Body', 'Weeks 5–8', 'Increase difficulty and volume. Develop strength. Build muscle. Improve conditioning.'),
  forge('Forge Yourself', 'Weeks 9–12', 'Harder variations. Push performance. Improve endurance. Test your records.');

  const JourneyPhase(this.title, this.weeks, this.description);
  final String title;
  final String weeks;
  final String description;

  static JourneyPhase forWeek(int week) => week <= 4 ? habit : (week <= 8 ? body : forge);
}
