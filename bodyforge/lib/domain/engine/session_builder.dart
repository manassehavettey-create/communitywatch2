import '../catalog/exercises.dart';
import '../catalog/skill_paths.dart';
import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/profile.dart';
import '../models/workout.dart';
import 'environment.dart';
import 'recovery.dart';
import 'time_fitter.dart';
import 'training_params.dart';

/// Everything needed to build one session.
class SessionInputs {
  const SessionInputs({
    required this.dayType,
    required this.params,
    required this.progress,
    required this.filter,
    required this.minutes,
    this.weakest,
    this.style = WorkoutStyle.mixed,
    this.focus = const {},
    this.seed = 0,
    this.recovery = RecoveryAdjustment.none,
    this.bestRecords = const {},
    this.kind = SessionKind.planned,
  });

  final DayType dayType;
  final TrainingParams params;
  final Map<String, TrackProgress> progress;
  final ExerciseFilter filter;

  /// Session length to fit into (45 means 45+).
  final int minutes;
  final Area? weakest;
  final WorkoutStyle style;
  final Set<MuscleFocus> focus;

  /// Deterministic variety (e.g. days since epoch) so a day's plan is stable.
  final int seed;
  final RecoveryAdjustment recovery;

  /// Best single-set results by exercise id — targets for benchmark sessions.
  final Map<String, int> bestRecords;
  final SessionKind kind;

  SessionInputs copyWith({
    DayType? dayType,
    int? minutes,
    RecoveryAdjustment? recovery,
    SessionKind? kind,
    Area? weakest,
  }) =>
      SessionInputs(
        dayType: dayType ?? this.dayType,
        params: params,
        progress: progress,
        filter: filter,
        minutes: minutes ?? this.minutes,
        weakest: weakest ?? this.weakest,
        style: style,
        focus: focus,
        seed: seed,
        recovery: recovery ?? this.recovery,
        bestRecords: bestRecords,
        kind: kind ?? this.kind,
      );
}

sealed class _Slot {
  const _Slot(this.role);
  final SlotRole role;
}

class _PathSlot extends _Slot {
  const _PathSlot(this.pathId, super.role);
  final String pathId;
}

class _AccSlot extends _Slot {
  const _AccSlot(this.candidates, super.role);
  final List<String> candidates;
}

const _upperAcc = ['pike_push_up', 'chair_dip', 'plank_up_down', 'towel_curl_hold', 'wall_handstand_hold'];
const _backAcc = ['towel_row_hold', 'towel_pull_apart', 'reverse_snow_angel', 'prone_ytw', 'bent_over_ytw'];
const _legAcc = ['reverse_lunge', 'lateral_lunge', 'curtsy_lunge', 'step_up', 'cossack_squat', 'walking_lunge'];
const _legSmallAcc = ['wall_sit', 'calf_raise', 'single_leg_calf_raise'];
const _coreRotAcc = ['bicycle_crunch', 'russian_twist', 'heel_taps', 'side_plank_hip_dip', 'shoulder_tap'];
const _coreLowerAcc = ['reverse_crunch', 'leg_raise', 'flutter_kicks', 'standing_knee_to_elbow'];
const _coreStabAcc = ['bird_dog', 'dead_bug', 'standing_side_crunch'];
const _condAcc = [
  'mountain_climber', 'high_knees', 'shadow_boxing', 'speed_squat', 'jumping_jack', 'skater_hop', 'plank_jack',
  'step_jack', 'bear_crawl', 'shuttle_run', 'low_impact_skater', 'squat_jump', 'jumping_lunge', 'inchworm',
];

const Map<DayType, List<_Slot>> _templates = {
  DayType.upper: [
    _PathSlot(PathIds.push, SlotRole.primary),
    _PathSlot(PathIds.back, SlotRole.primary),
    _AccSlot(_upperAcc, SlotRole.secondary),
    _AccSlot(_backAcc, SlotRole.accessory),
    _AccSlot(['shoulder_tap', 'plank_up_down'], SlotRole.accessory),
  ],
  DayType.lower: [
    _PathSlot(PathIds.legs, SlotRole.primary),
    _PathSlot(PathIds.hips, SlotRole.primary),
    _AccSlot(_legAcc, SlotRole.secondary),
    _AccSlot(_legSmallAcc, SlotRole.accessory),
  ],
  DayType.core: [
    _PathSlot(PathIds.core, SlotRole.primary),
    _AccSlot(_coreRotAcc, SlotRole.secondary),
    _AccSlot(_coreLowerAcc, SlotRole.secondary),
    _AccSlot(_coreStabAcc, SlotRole.accessory),
    _PathSlot(PathIds.back, SlotRole.accessory),
  ],
  DayType.upperCore: [
    _PathSlot(PathIds.push, SlotRole.primary),
    _PathSlot(PathIds.back, SlotRole.primary),
    _PathSlot(PathIds.core, SlotRole.secondary),
    _AccSlot(_coreLowerAcc, SlotRole.accessory),
    _AccSlot(_upperAcc, SlotRole.accessory),
  ],
  DayType.fullBody: [
    _PathSlot(PathIds.push, SlotRole.primary),
    _PathSlot(PathIds.legs, SlotRole.primary),
    _PathSlot(PathIds.core, SlotRole.secondary),
    _PathSlot(PathIds.hips, SlotRole.secondary),
    _PathSlot(PathIds.back, SlotRole.accessory),
  ],
  DayType.conditioning: [
    _PathSlot(PathIds.conditioning, SlotRole.primary),
    _AccSlot(_condAcc, SlotRole.secondary),
    _PathSlot(PathIds.core, SlotRole.secondary),
    _AccSlot(_condAcc, SlotRole.secondary),
    _AccSlot(_coreRotAcc, SlotRole.accessory),
  ],
};

const Map<DayType, List<String>> _warmups = {
  DayType.upper: ['arm_circles', 'wall_angel', 'march_in_place', 'inchworm', 'cat_cow'],
  DayType.upperCore: ['arm_circles', 'march_in_place', 'wall_angel', 'cat_cow', 'inchworm'],
  DayType.lower: ['march_in_place', 'leg_swings', 'hip_circles', 'good_morning', 'standing_glute_kickback'],
  DayType.core: ['march_in_place', 'cat_cow', 'hip_circles', 'standing_knee_to_elbow'],
  DayType.fullBody: ['march_in_place', 'arm_circles', 'leg_swings', 'hip_circles', 'inchworm'],
  DayType.conditioning: ['march_in_place', 'step_jack', 'arm_circles', 'leg_swings', 'hip_circles'],
  DayType.benchmark: ['march_in_place', 'arm_circles', 'leg_swings', 'hip_circles', 'inchworm'],
};

const Map<DayType, List<String>> _cooldowns = {
  DayType.upper: ['chest_opener', 'childs_pose', 'thoracic_rotation', 'box_breathing'],
  DayType.upperCore: ['chest_opener', 'childs_pose', 'thoracic_rotation', 'box_breathing'],
  DayType.lower: ['standing_quad_stretch', 'standing_hamstring_stretch', 'hip_flexor_stretch', 'box_breathing'],
  DayType.core: ['childs_pose', 'cat_cow', 'box_breathing'],
  DayType.fullBody: ['standing_hamstring_stretch', 'chest_opener', 'hip_flexor_stretch', 'box_breathing'],
  DayType.conditioning: ['standing_quad_stretch', 'standing_hamstring_stretch', 'box_breathing'],
  DayType.benchmark: ['chest_opener', 'standing_quad_stretch', 'box_breathing'],
};

const _recoveryFlow = [
  'march_in_place', 'cat_cow', 'worlds_greatest_stretch', 'hip_flexor_stretch', 'standing_quad_stretch',
  'thoracic_rotation', 'childs_pose', 'deep_squat_hold', 'standing_hamstring_stretch', 'lying_hamstring_stretch',
  'chest_opener', 'hip_90_90', 'leg_swings', 'arm_circles', 'wall_angel', 'box_breathing',
];

const Map<DayType, String> _objectives = {
  DayType.upper: 'Build pushing and pulling strength',
  DayType.lower: 'Stronger legs and glutes',
  DayType.core: 'A stronger, more stable core',
  DayType.upperCore: 'Upper-body strength with core focus',
  DayType.fullBody: 'Train everything, efficiently',
  DayType.conditioning: 'Fitness, stamina and fat-loss support',
  DayType.recovery: 'Recover and move better',
  DayType.benchmark: 'Test your records',
  DayType.rest: 'Rest and recover',
};

String objectiveFor(DayType d) => _objectives[d] ?? '';

const Map<Area, List<String>> _areaPaths = {
  Area.upper: [PathIds.push, PathIds.back],
  Area.legs: [PathIds.legs, PathIds.hips],
  Area.core: [PathIds.core],
  Area.conditioning: [PathIds.conditioning],
};

class SessionBuilder {
  SessionBuilder(this.inputs);
  final SessionInputs inputs;

  TrainingParams get _params => inputs.params;
  ExerciseFilter get _filter => inputs.filter;

  /// Build the full session for [inputs.dayType], adjusted for recovery and
  /// fitted to [inputs.minutes].
  WorkoutPlan build() {
    final day = inputs.dayType;
    if (day == DayType.rest) {
      throw ArgumentError('Rest days have no session. Build a recovery or quick session instead.');
    }
    if (day == DayType.recovery || inputs.recovery.mode == RecoveryMode.recovery) {
      return buildRecovery(inputs.minutes.clamp(5, 30), note: inputs.recovery.mode == RecoveryMode.recovery ? inputs.recovery.message : null);
    }
    if (day == DayType.benchmark) return _benchmark();

    final used = <String>{};
    final main = <PlannedExercise>[];
    final notes = <String>[];
    final template = _templates[day]!;

    for (var i = 0; i < template.length; i++) {
      final e = _fillSlot(template[i], i, used);
      if (e != null) {
        main.add(e);
        used.add(e.exerciseId);
      }
    }

    // Visible-abs goal: make sure every session has direct core work.
    final hasCore = main.any((e) => exerciseById(e.exerciseId).area == Area.core);
    if (_params.extraCore && !hasCore) {
      final e = _fillSlot(const _AccSlot([..._coreLowerAcc, ..._coreRotAcc], SlotRole.accessory), 7, used);
      if (e != null) {
        main.add(e);
        used.add(e.exerciseId);
      }
    }

    // Weakest link bias (spec §11).
    PlannedExercise? weakFinisher;
    final weak = inputs.weakest;
    if (weak != null) {
      final idx = main.indexWhere((e) =>
          exerciseById(e.exerciseId).area == weak && (e.role == SlotRole.primary || e.role == SlotRole.secondary));
      if (idx >= 0) {
        final e = main[idx];
        if (e.sets < _params.maxSets + 1) {
          main[idx] = e.copyWith(sets: e.sets + 1);
          notes.add('+1 set of ${exerciseById(e.exerciseId).name}: ${weak.label.toLowerCase()} is your weakest link right now.');
        }
      } else {
        for (final pathId in _areaPaths[weak]!) {
          final e = _fillSlot(_PathSlot(pathId, SlotRole.accessory), 8, used);
          if (e == null) continue;
          if (weak == Area.conditioning) {
            weakFinisher = e;
          } else {
            main.add(e);
          }
          used.add(e.exerciseId);
          notes.add('Extra ${weak.label.toLowerCase()} work — it\'s your weakest link right now.');
          break;
        }
      }
    }

    final circuit = inputs.style == WorkoutStyle.circuits ||
        (inputs.style == WorkoutStyle.mixed && (_params.preferCircuit || day == DayType.conditioning));

    var mainBlock = PlanBlock(kind: BlockKind.main, exercises: main);
    if (circuit && main.length >= 2) {
      final rounds = main
          .where((e) => e.role != SlotRole.accessory)
          .fold<int>(2, (m, e) => e.sets > m ? e.sets : m)
          .clamp(2, 5);
      mainBlock = PlanBlock(
        kind: BlockKind.main,
        circuit: true,
        rounds: rounds,
        roundRestSec: _params.repMode == RepMode.strength ? 90 : 60,
        exercises: [for (final e in main) e.copyWith(sets: rounds, restSec: 15)],
      );
    }

    final blocks = <PlanBlock>[
      _warmupBlock(day),
      mainBlock,
      if ((_params.finisher || weakFinisher != null) &&
          day != DayType.conditioning &&
          !inputs.recovery.dropFinisher)
        _finisherBlock(used, weakFinisher),
      _cooldownBlock(day),
    ].where((b) => !b.isEmpty).toList();

    var plan = WorkoutPlan(
      title: day.label,
      dayType: day,
      kind: inputs.kind,
      blocks: blocks,
      objective: objectiveFor(day),
      notes: notes,
    );

    plan = _applyRecovery(plan);
    plan = fitToTime(plan, inputs.minutes,
        params: _params, expansionPool: _expansionPool(day, used), allowExpand: !inputs.recovery.changesPlan);
    return plan.copyWith(difficultyLabel: _difficulty(plan));
  }

  /// Re-fit an existing plan to a different time budget, reusing this
  /// builder's expansion pool.
  WorkoutPlan refit(WorkoutPlan plan, int minutes) {
    final used = {for (final e in plan.allExercises) e.exerciseId};
    final fitted = fitToTime(plan, minutes,
        allowExpand: plan.kind != SessionKind.recoveryReduced,
        params: _params,
        expansionPool: plan.dayType == DayType.recovery ? _recoveryPool(used) : _expansionPool(plan.dayType, used));
    final kind = minutes < (plan.targetMinutes ?? minutes) && plan.kind == SessionKind.planned
        ? SessionKind.timeAdjusted
        : plan.kind;
    return fitted.copyWith(kind: kind, difficultyLabel: _difficulty(fitted));
  }

  // ─────────────────────────────── slots ───────────────────────────────

  PlannedExercise? _fillSlot(_Slot slot, int slotIndex, Set<String> used) {
    return switch (slot) {
      _PathSlot s => _pathExercise(s.pathId, s.role, used),
      _AccSlot s => _accessory(s.candidates, s.role, slotIndex, used),
    };
  }

  PlannedExercise? _pathExercise(String pathId, SlotRole role, Set<String> used) {
    final path = pathById(pathId);
    final prog = inputs.progress[pathId];
    if (prog == null) return null;
    var index = prog.nodeIndex;
    if (inputs.recovery.regressOneLevel && index > 0) index -= 1;
    final resolved = _filter.resolve(path, index);
    if (resolved == null || used.contains(resolved.exerciseId)) return null;

    final nodeEx = exerciseById(path.node(prog.nodeIndex).exerciseId);
    final chosen = exerciseById(resolved.exerciseId);
    int amount;
    if (resolved.index < prog.nodeIndex) {
      // Using an easier variation than the user's level: push the reps up.
      final (lo, hi) = _params.window(chosen, path);
      amount = (lo + (hi - lo) * 0.75).round();
    } else {
      amount = _params.convertAmount(prog.amount, nodeEx, chosen, path);
    }
    final sets = role == SlotRole.accessory ? (prog.sets < _params.baseSets ? prog.sets : _params.baseSets) : prog.sets;
    return PlannedExercise(
      exerciseId: chosen.id,
      trackKey: pathId,
      sets: sets,
      amount: amount,
      restSec: role == SlotRole.accessory ? _params.accessoryRestSec : _params.restSec,
      role: role,
    );
  }

  /// Maximum accessory difficulty for an area: roughly the user's level on
  /// that area's main path, plus one.
  int _areaCap(Area area) {
    final pathId = _areaPaths[area]!.first;
    final prog = inputs.progress[pathId];
    if (prog == null) return 3;
    final d = exerciseById(pathById(pathId).node(prog.nodeIndex).exerciseId).difficulty;
    return d + 1 < 3 ? 3 : d + 1;
  }

  PlannedExercise? _accessory(List<String> candidates, SlotRole role, int slotIndex, Set<String> used) {
    var pool = [
      for (final id in candidates)
        if (!used.contains(id) && _filter.allowsId(id) && exerciseById(id).difficulty <= _areaCap(exerciseById(id).area))
          exerciseById(id)
    ];
    if (pool.isEmpty) return null;
    if (inputs.focus.isNotEmpty) {
      final focused = pool.where((e) => e.focus.intersection(inputs.focus).isNotEmpty).toList();
      if (focused.isNotEmpty) pool = focused;
    }
    final ex = pool[(inputs.seed + slotIndex) % pool.length];
    return _accessoryPrescription(ex, role);
  }

  PlannedExercise _accessoryPrescription(Exercise ex, SlotRole role) {
    final key = TrackProgress.accessoryKey(ex.id);
    final prog = inputs.progress[key];
    final (lo, hi) = _params.window(ex);
    final baseSets = role == SlotRole.accessory ? (_params.baseSets > 3 ? 3 : _params.baseSets) : _params.baseSets;
    return PlannedExercise(
      exerciseId: ex.id,
      trackKey: key,
      sets: prog?.sets ?? baseSets,
      amount: prog?.amount ?? (lo + (hi - lo) * 0.3).round(),
      restSec: _params.accessoryRestSec,
      role: role,
    );
  }

  List<PlannedExercise> _expansionPool(DayType day, Set<String> used) {
    final template = _templates[day] ?? const [];
    final ids = <String>{};
    final out = <PlannedExercise>[];
    for (final slot in template) {
      if (slot is! _AccSlot) continue;
      for (final id in slot.candidates) {
        if (used.contains(id) || ids.contains(id) || !_filter.allowsId(id)) continue;
        final ex = exerciseById(id);
        if (ex.difficulty > _areaCap(ex.area)) continue;
        ids.add(id);
        out.add(_accessoryPrescription(ex, SlotRole.accessory));
      }
    }
    return out;
  }

  // ─────────────────────────────── blocks ───────────────────────────────

  PlanBlock _timedBlock(BlockKind kind, List<String> ids, {int count = 3, int seconds = 30}) {
    final list = <PlannedExercise>[];
    for (final id in ids) {
      if (list.length >= count) break;
      if (!_filter.allowsId(id)) continue;
      final ex = exerciseById(id);
      list.add(PlannedExercise(
        exerciseId: id,
        sets: 1,
        amount: ex.isTimed ? seconds : 10,
        restSec: 5,
        role: kind == BlockKind.warmup ? SlotRole.warmup : SlotRole.cooldown,
      ));
    }
    return PlanBlock(kind: kind, exercises: list, circuit: true, rounds: 1);
  }

  PlanBlock _warmupBlock(DayType day) => _timedBlock(BlockKind.warmup, _warmups[day] ?? _warmups[DayType.fullBody]!);

  PlanBlock _cooldownBlock(DayType day) =>
      _timedBlock(BlockKind.cooldown, _cooldowns[day] ?? _cooldowns[DayType.fullBody]!, count: 3);

  PlanBlock _finisherBlock(Set<String> used, PlannedExercise? weakFinisher) {
    final list = <PlannedExercise>[];
    final cond = weakFinisher ?? _pathExercise(PathIds.conditioning, SlotRole.finisher, used);
    if (cond != null) {
      list.add(cond.copyWith(role: SlotRole.finisher, sets: 2, restSec: 15));
      used.add(cond.exerciseId);
    }
    final acc = _accessory(_condAcc, SlotRole.finisher, 11, used);
    if (acc != null) {
      final ex = exerciseById(acc.exerciseId);
      list.add(acc.copyWith(sets: 2, restSec: 15, amount: ex.isTimed ? 30 : acc.amount));
      used.add(acc.exerciseId);
    }
    if (_params.extraCore) {
      final core = _accessory(_coreLowerAcc, SlotRole.finisher, 12, used);
      if (core != null) {
        list.add(core.copyWith(sets: 2, restSec: 15));
        used.add(core.exerciseId);
      }
    }
    return PlanBlock(kind: BlockKind.finisher, exercises: list, circuit: true, rounds: 2, roundRestSec: 30);
  }

  List<PlannedExercise> _recoveryPool(Set<String> used) => [
        for (final id in _recoveryFlow)
          if (!used.contains(id) && _filter.allowsId(id))
            PlannedExercise(exerciseId: id, sets: 1, amount: exerciseById(id).isTimed ? 45 : 10, restSec: 10, role: SlotRole.cooldown)
      ];

  /// A mobility-based recovery session (spec §9 "provide a recovery session").
  WorkoutPlan buildRecovery(int minutes, {String? note}) {
    final pool = _recoveryPool(const {});
    // Always end with box breathing when available.
    final breathing = pool.where((e) => e.exerciseId == 'box_breathing').toList();
    final rest = pool.where((e) => e.exerciseId != 'box_breathing').toList();
    final start = [...rest.take(5), ...breathing];
    var plan = WorkoutPlan(
      title: 'Recovery Flow',
      dayType: DayType.recovery,
      kind: SessionKind.recovery,
      objective: objectiveFor(DayType.recovery),
      difficultyLabel: 'Gentle',
      notes: [?note],
      blocks: [PlanBlock(kind: BlockKind.main, exercises: start, circuit: true, rounds: 1)],
    );
    plan = fitToTime(plan, minutes, params: _params, expansionPool: rest.skip(5).toList());
    return plan;
  }

  WorkoutPlan _benchmark() {
    final used = <String>{};
    final tests = <PlannedExercise>[];
    for (final pathId in [PathIds.push, PathIds.legs, PathIds.core]) {
      final e = _pathExercise(pathId, SlotRole.primary, used);
      if (e == null) continue;
      var id = e.exerciseId;
      // Plank is the classic core benchmark when possible.
      if (pathId == PathIds.core && _filter.allowsId('plank')) id = 'plank';
      final ex = exerciseById(id);
      final best = inputs.bestRecords[id];
      final target = best != null ? best + (ex.isTimed ? 5 : 1) : (ex.isTimed ? 60 : 20);
      tests.add(PlannedExercise(exerciseId: id, trackKey: pathId, sets: 1, amount: target, restSec: 120, role: SlotRole.primary));
      used.add(id);
    }
    return WorkoutPlan(
      title: 'Benchmark Test',
      dayType: DayType.benchmark,
      kind: SessionKind.benchmark,
      objective: objectiveFor(DayType.benchmark),
      difficultyLabel: 'Max effort',
      notes: const ['One all-out set of each. Stop when your form breaks — that\'s your score.'],
      blocks: [
        _warmupBlock(DayType.benchmark),
        PlanBlock(kind: BlockKind.main, exercises: tests),
        _cooldownBlock(DayType.benchmark),
      ].where((b) => !b.isEmpty).toList(),
    );
  }

  // ─────────────────────────────── adjustments ───────────────────────────────

  WorkoutPlan _applyRecovery(WorkoutPlan plan) {
    final r = inputs.recovery;
    if (!r.changesPlan) return plan;
    final main = plan.main;
    int scale(int sets) => (sets * r.volumeFactor).round().clamp(1, 99);
    final b = main.circuit
        ? main.copyWith(
            rounds: scale(main.rounds),
            roundRestSec: main.roundRestSec + r.restBonusSec,
            exercises: [for (final e in main.exercises) e.copyWith(sets: scale(main.rounds))],
          )
        : main.copyWith(exercises: [
            for (final e in main.exercises) e.copyWith(sets: scale(e.sets), restSec: e.restSec + r.restBonusSec)
          ]);
    final kind = plan.kind == SessionKind.planned ? SessionKind.recoveryReduced : plan.kind;
    return plan.replaceBlock(b).copyWith(kind: kind, notes: [r.message, ...plan.notes]);
  }

  String _difficulty(WorkoutPlan plan) {
    if (plan.dayType == DayType.recovery) return 'Gentle';
    if (plan.dayType == DayType.benchmark) return 'Max effort';
    if (inputs.recovery.mode == RecoveryMode.reduced) return 'Easy';
    final main = plan.main;
    final sets = main.circuit
        ? main.rounds * main.exercises.length
        : main.exercises.fold<int>(0, (s, e) => s + e.sets);
    final avgDiff = main.exercises.isEmpty
        ? 0
        : main.exercises.fold<int>(0, (s, e) => s + exerciseById(e.exerciseId).difficulty) / main.exercises.length;
    final load = sets + avgDiff;
    if (load >= 20) return 'Hard';
    if (load >= 11) return 'Moderate';
    return 'Easy';
  }
}
