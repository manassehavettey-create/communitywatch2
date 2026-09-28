import '../catalog/exercises.dart';
import 'enums.dart';
import 'local_date.dart';

/// Role of an exercise in a session. Lower [priority] = more important; time
/// compression removes the highest priority numbers first.
enum SlotRole {
  primary(1),
  secondary(2),
  accessory(3),
  finisher(4),
  warmup(5),
  cooldown(5);

  const SlotRole(this.priority);
  final int priority;
}

enum BlockKind {
  warmup('Warm-up'),
  main('Workout'),
  finisher('Finisher'),
  cooldown('Cool-down');

  const BlockKind(this.label);
  final String label;
}

/// Seconds added between exercises for setting up.
const kTransitionSec = 10;

class PlannedExercise {
  const PlannedExercise({
    required this.exerciseId,
    required this.sets,
    required this.amount,
    required this.restSec,
    required this.role,
    this.trackKey,
  });

  final String exerciseId;

  /// Path id or `ex:<id>` this slot progresses. Null for warm-ups etc.
  final String? trackKey;
  final int sets;

  /// Reps, or seconds for timed exercises.
  final int amount;

  /// Rest after each set (straight sets) or after this exercise (circuits).
  final int restSec;
  final SlotRole role;

  bool get isTimed => exerciseById(exerciseId).isTimed;

  PlannedExercise copyWith({String? exerciseId, String? trackKey, int? sets, int? amount, int? restSec, SlotRole? role}) =>
      PlannedExercise(
        exerciseId: exerciseId ?? this.exerciseId,
        trackKey: trackKey ?? this.trackKey,
        sets: sets ?? this.sets,
        amount: amount ?? this.amount,
        restSec: restSec ?? this.restSec,
        role: role ?? this.role,
      );

  Map<String, Object?> toJson() => {
        'e': exerciseId,
        if (trackKey != null) 't': trackKey,
        's': sets,
        'a': amount,
        'r': restSec,
        'role': role.name,
      };

  factory PlannedExercise.fromJson(Map<String, Object?> j) => PlannedExercise(
        exerciseId: j['e']! as String,
        trackKey: j['t'] as String?,
        sets: (j['s']! as num).toInt(),
        amount: (j['a']! as num).toInt(),
        restSec: (j['r']! as num).toInt(),
        role: enumByName(SlotRole.values, j['role'] as String?, SlotRole.accessory),
      );

  @override
  String toString() => '$exerciseId ${sets}x$amount r$restSec ${role.name}';
}

class PlanBlock {
  const PlanBlock({
    required this.kind,
    required this.exercises,
    this.circuit = false,
    this.rounds = 1,
    this.roundRestSec = 0,
  });

  final BlockKind kind;
  final List<PlannedExercise> exercises;

  /// Circuit: one set of each exercise per round, [rounds] times.
  final bool circuit;
  final int rounds;
  final int roundRestSec;

  bool get isEmpty => exercises.isEmpty;

  PlanBlock copyWith({List<PlannedExercise>? exercises, bool? circuit, int? rounds, int? roundRestSec}) => PlanBlock(
        kind: kind,
        exercises: exercises ?? this.exercises,
        circuit: circuit ?? this.circuit,
        rounds: rounds ?? this.rounds,
        roundRestSec: roundRestSec ?? this.roundRestSec,
      );

  /// Estimated seconds for this block.
  int get estimatedSeconds {
    if (exercises.isEmpty) return 0;
    double total = 0;
    if (circuit) {
      for (var r = 0; r < rounds; r++) {
        for (var i = 0; i < exercises.length; i++) {
          final p = exercises[i];
          total += exerciseById(p.exerciseId).setSeconds(p.amount) + kTransitionSec;
          final lastInRound = i == exercises.length - 1;
          if (!lastInRound) total += p.restSec;
        }
        if (r < rounds - 1) total += roundRestSec;
      }
    } else {
      for (final p in exercises) {
        final setSec = exerciseById(p.exerciseId).setSeconds(p.amount);
        total += p.sets * setSec + (p.sets - 1) * p.restSec + kTransitionSec;
        // Rest before the next exercise.
        total += p.restSec * 0.5;
      }
    }
    return total.round();
  }

  Map<String, Object?> toJson() => {
        'k': kind.name,
        'x': [for (final e in exercises) e.toJson()],
        'c': circuit,
        'n': rounds,
        'rr': roundRestSec,
      };

  factory PlanBlock.fromJson(Map<String, Object?> j) => PlanBlock(
        kind: enumByName(BlockKind.values, j['k'] as String?, BlockKind.main),
        exercises: [
          for (final e in (j['x'] as List? ?? const [])) PlannedExercise.fromJson((e as Map).cast<String, Object?>())
        ],
        circuit: j['c'] == true,
        rounds: (j['n'] as num?)?.toInt() ?? 1,
        roundRestSec: (j['rr'] as num?)?.toInt() ?? 0,
      );
}

/// A concrete session ready to be played.
class WorkoutPlan {
  const WorkoutPlan({
    required this.title,
    required this.dayType,
    required this.kind,
    required this.blocks,
    required this.objective,
    this.targetMinutes,
    this.notes = const [],
    this.difficultyLabel = 'Moderate',
  });

  final String title;
  final DayType dayType;
  final SessionKind kind;
  final List<PlanBlock> blocks;

  /// What this session is for — kept when time-compressing.
  final String objective;
  final int? targetMinutes;
  final List<String> notes;
  final String difficultyLabel;

  int get estimatedSeconds => blocks.fold(0, (s, b) => s + b.estimatedSeconds);
  int get estimatedMinutes => (estimatedSeconds / 60).ceil();

  PlanBlock? block(BlockKind k) {
    for (final b in blocks) {
      if (b.kind == k) return b;
    }
    return null;
  }

  PlanBlock get main => block(BlockKind.main) ?? const PlanBlock(kind: BlockKind.main, exercises: []);

  Iterable<PlannedExercise> get allExercises => blocks.expand((b) => b.exercises);

  /// Distinct main + finisher exercises (what the user thinks of as "the workout").
  List<PlannedExercise> get workExercises =>
      [for (final b in blocks) if (b.kind == BlockKind.main || b.kind == BlockKind.finisher) ...b.exercises];

  WorkoutPlan copyWith({
    String? title,
    DayType? dayType,
    SessionKind? kind,
    List<PlanBlock>? blocks,
    String? objective,
    int? targetMinutes,
    List<String>? notes,
    String? difficultyLabel,
  }) =>
      WorkoutPlan(
        title: title ?? this.title,
        dayType: dayType ?? this.dayType,
        kind: kind ?? this.kind,
        blocks: blocks ?? this.blocks,
        objective: objective ?? this.objective,
        targetMinutes: targetMinutes ?? this.targetMinutes,
        notes: notes ?? this.notes,
        difficultyLabel: difficultyLabel ?? this.difficultyLabel,
      );

  WorkoutPlan replaceBlock(PlanBlock b) =>
      copyWith(blocks: [for (final x in blocks) x.kind == b.kind ? b : x]);

  Map<String, Object?> toJson() => {
        'title': title,
        'day': dayType.name,
        'kind': kind.name,
        'obj': objective,
        if (targetMinutes != null) 'min': targetMinutes,
        'notes': notes,
        'diff': difficultyLabel,
        'blocks': [for (final b in blocks) b.toJson()],
      };

  factory WorkoutPlan.fromJson(Map<String, Object?> j) => WorkoutPlan(
        title: j['title'] as String? ?? 'Workout',
        dayType: enumByName(DayType.values, j['day'] as String?, DayType.fullBody),
        kind: enumByName(SessionKind.values, j['kind'] as String?, SessionKind.planned),
        objective: j['obj'] as String? ?? '',
        targetMinutes: (j['min'] as num?)?.toInt(),
        notes: [for (final n in (j['notes'] as List? ?? const [])) n as String],
        difficultyLabel: j['diff'] as String? ?? 'Moderate',
        blocks: [for (final b in (j['blocks'] as List? ?? const [])) PlanBlock.fromJson((b as Map).cast<String, Object?>())],
      );
}

/// One performed (or skipped) set.
class SetResult {
  const SetResult({
    required this.exerciseId,
    required this.setIndex,
    required this.target,
    required this.achieved,
    this.trackKey,
    this.skipped = false,
    this.blockKind = BlockKind.main,
    this.completedAt,
  });

  final String exerciseId;
  final String? trackKey;
  final int setIndex;
  final int target;
  final int achieved;
  final bool skipped;
  final BlockKind blockKind;
  final DateTime? completedAt;

  bool get isTimed => exerciseById(exerciseId).isTimed;

  Map<String, Object?> toJson() => {
        'e': exerciseId,
        if (trackKey != null) 't': trackKey,
        'i': setIndex,
        'tg': target,
        'a': achieved,
        if (skipped) 'sk': true,
        'b': blockKind.name,
        if (completedAt != null) 'at': completedAt!.toUtc().toIso8601String(),
      };

  factory SetResult.fromJson(Map<String, Object?> j) => SetResult(
        exerciseId: j['e']! as String,
        trackKey: j['t'] as String?,
        setIndex: (j['i']! as num).toInt(),
        target: (j['tg']! as num).toInt(),
        achieved: (j['a']! as num).toInt(),
        skipped: j['sk'] == true,
        blockKind: enumByName(BlockKind.values, j['b'] as String?, BlockKind.main),
        completedAt: j['at'] == null ? null : DateTime.parse(j['at']! as String),
      );
}

/// A finished workout as the engine sees it.
class CompletedWorkout {
  const CompletedWorkout({
    required this.id,
    required this.date,
    required this.dayType,
    required this.kind,
    required this.sets,
    required this.durationSec,
    this.rating,
    this.startedAt,
  });

  final String id;
  final LocalDate date;
  final DayType dayType;
  final SessionKind kind;
  final List<SetResult> sets;
  final int durationSec;
  final Rating? rating;
  final DateTime? startedAt;

  bool get isRecovery => kind == SessionKind.recovery || dayType == DayType.recovery;

  int repsForFamily(String family) => sets
      .where((s) => !s.skipped && !s.isTimed && exerciseById(s.exerciseId).family == family)
      .fold(0, (sum, s) => sum + s.achieved * (exerciseById(s.exerciseId).perSide ? 2 : 1));

  int setsInArea(Area area) => sets
      .where((s) => !s.skipped && s.blockKind != BlockKind.warmup && s.blockKind != BlockKind.cooldown)
      .where((s) => exerciseById(s.exerciseId).area == area)
      .length;
}
