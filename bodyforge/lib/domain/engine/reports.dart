import '../catalog/exercises.dart';
import '../catalog/skill_paths.dart';
import '../models/enums.dart';
import '../models/local_date.dart';
import '../models/workout.dart';
import 'calendar.dart';
import 'program_generator.dart';
import 'records.dart';
import 'recovery.dart';

class MeasurementPoint {
  const MeasurementPoint(this.type, this.value, this.date, {this.label});
  final MeasurementType type;
  final String? label;

  /// Always metric (kg / cm).
  final double value;
  final LocalDate date;
}

/// A stored record event (history of PRs and baselines).
class RecordPoint {
  const RecordPoint({
    required this.exerciseId,
    required this.metric,
    required this.previous,
    required this.value,
    required this.date,
  });
  final String exerciseId;
  final RecordMetric metric;
  final int? previous;
  final int value;
  final LocalDate date;
}

class PrDelta {
  const PrDelta(this.exerciseId, this.metric, this.from, this.to);
  final String exerciseId;
  final RecordMetric metric;
  final int from;
  final int to;
  int get delta => to - from;
  String get name => exerciseById(exerciseId).name;
  String get deltaLabel {
    final sign = delta >= 0 ? '+' : '−';
    return metric == RecordMetric.maxHold ? '$sign${formatSeconds(delta.abs())}' : '$sign${delta.abs()} reps';
  }
}

class Milestone {
  const Milestone({required this.date, required this.type, required this.title, this.trackKey, this.exerciseId});
  final LocalDate date;

  /// `unlock`, `path_top`, `pr`, `phase`.
  final String type;
  final String title;
  final String? trackKey;
  final String? exerciseId;
}

class WeeklyReport {
  const WeeklyReport({
    required this.weekStart,
    required this.completed,
    required this.planned,
    required this.consistency,
    required this.prDeltas,
    required this.weightDelta,
    required this.waistDelta,
    required this.recovery,
    required this.modified,
    required this.recoverySessions,
    required this.totalMinutes,
    required this.totalReps,
  });

  final LocalDate weekStart;
  LocalDate get weekEnd => weekStart.addDays(6);
  final int completed;
  final int planned;
  final double consistency;
  final List<PrDelta> prDeltas;
  final double? weightDelta;
  final double? waistDelta;
  final String recovery;
  final int modified;
  final int recoverySessions;
  final int totalMinutes;
  final int totalReps;

  bool get isEmpty => completed == 0 && prDeltas.isEmpty && weightDelta == null && waistDelta == null;
}

double? _deltaAcross(List<MeasurementPoint> points, MeasurementType type, LocalDate start, LocalDate end) {
  final list = points.where((p) => p.type == type && !p.date.isAfter(end)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final inRange = list.where((p) => !p.date.isBefore(start)).toList();
  if (inRange.isEmpty) return null;
  final before = list.where((p) => p.date.isBefore(start)).toList();
  final baseline = before.isNotEmpty ? before.last : inRange.first;
  final latest = inRange.last;
  if (identical(baseline, latest)) return null;
  return double.parse((latest.value - baseline.value).toStringAsFixed(1));
}

List<PrDelta> _prDeltas(List<RecordPoint> records, LocalDate start, LocalDate end) {
  final byKey = <String, List<RecordPoint>>{};
  for (final r in records) {
    if (r.date.isBefore(start) || r.date.isAfter(end) || r.previous == null) continue;
    byKey.putIfAbsent('${r.exerciseId}|${r.metric.name}', () => []).add(r);
  }
  final out = <PrDelta>[];
  byKey.forEach((_, list) {
    list.sort((a, b) => a.date.compareTo(b.date));
    final from = list.map((e) => e.previous!).reduce((a, b) => a < b ? a : b);
    final to = list.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    out.add(PrDelta(list.first.exerciseId, list.first.metric, from, to));
  });
  out.sort((a, b) => b.delta.compareTo(a.delta));
  return out;
}

/// Spec §17: the weekly reality check.
WeeklyReport buildWeeklyReport({
  required LocalDate weekStart,
  required List<CompletedWorkout> workouts,
  required List<RecordPoint> records,
  required List<MeasurementPoint> measurements,
  required List<(LocalDate, int)> recoveryScores,
  required ProgramSpec? program,
  required LocalDate programStart,
}) {
  final end = weekStart.addDays(6);
  final inWeek = workouts.where((w) => !w.date.isBefore(weekStart) && !w.date.isAfter(end)).toList();
  var planned = 0;
  if (program != null) {
    for (var d = weekStart; !d.isAfter(end); d = d.addDays(1)) {
      if (!d.isBefore(programStart) && program.isTrainingDay(d)) planned++;
    }
  }
  final scores = [for (final (d, s) in recoveryScores) if (!d.isBefore(weekStart) && !d.isAfter(end)) s];
  final avg = scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length;
  final days = {for (final w in inWeek) w.date};

  return WeeklyReport(
    weekStart: weekStart,
    completed: inWeek.length,
    planned: planned,
    consistency: consistency(
        from: weekStart, to: end, sessionDates: days.toList(), program: program, programStart: programStart),
    prDeltas: _prDeltas(records, weekStart, end),
    weightDelta: _deltaAcross(measurements, MeasurementType.weight, weekStart, end),
    waistDelta: _deltaAcross(measurements, MeasurementType.waist, weekStart, end),
    recovery: recoveryLabel(avg),
    modified: inWeek.where((w) => w.kind.isModified).length,
    recoverySessions: inWeek.where((w) => w.isRecovery).length,
    totalMinutes: (inWeek.fold<int>(0, (s, w) => s + w.durationSec) / 60).round(),
    totalReps: inWeek.fold<int>(
        0, (s, w) => s + w.sets.where((x) => !x.skipped && !x.isTimed).fold<int>(0, (a, x) => a + x.achieved)),
  );
}

class PathChange {
  const PathChange(this.pathId, this.fromNode, this.toNode);
  final String pathId;
  final int fromNode;
  final int toNode;
  SkillPath get path => pathById(pathId);
  String get fromName => exerciseById(path.node(fromNode).exerciseId).name;
  String get toName => exerciseById(path.node(toNode).exerciseId).name;
  int get levelsGained => toNode - fromNode;
}

class FinalReport {
  const FinalReport({
    required this.workouts,
    required this.consistency,
    required this.strength,
    required this.records,
    required this.prCount,
    required this.weightStart,
    required this.weightEnd,
    required this.waistStart,
    required this.waistEnd,
    required this.milestones,
    required this.achievementIds,
    required this.totalMinutes,
    required this.totalReps,
  });

  final int workouts;
  final double consistency;
  final List<PathChange> strength;
  final List<PrDelta> records;
  final int prCount;
  final double? weightStart;
  final double? weightEnd;
  final double? waistStart;
  final double? waistEnd;
  final List<Milestone> milestones;
  final List<String> achievementIds;
  final int totalMinutes;
  final int totalReps;

  double? get weightChange => weightStart == null || weightEnd == null ? null : weightEnd! - weightStart!;
  double? get waistChange => waistStart == null || waistEnd == null ? null : waistEnd! - waistStart!;
}

/// Spec §21: the 12-week performance report.
FinalReport buildFinalReport({
  required LocalDate start,
  required LocalDate end,
  required List<CompletedWorkout> workouts,
  required List<RecordPoint> records,
  required List<MeasurementPoint> measurements,
  required Map<String, int> startNodes,
  required Map<String, int> currentNodes,
  required List<Milestone> milestones,
  required List<String> achievementIds,
  required ProgramSpec? program,
}) {
  final inRange = workouts.where((w) => !w.date.isBefore(start) && !w.date.isAfter(end)).toList();

  // First recorded value vs best, per exercise.
  final firstByKey = <String, RecordPoint>{};
  final bestByKey = <String, RecordPoint>{};
  final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
  for (final r in sorted) {
    if (r.date.isAfter(end)) continue;
    final key = '${r.exerciseId}|${r.metric.name}';
    firstByKey.putIfAbsent(key, () => r);
    final b = bestByKey[key];
    if (b == null || r.value > b.value) bestByKey[key] = r;
  }
  final recordDeltas = <PrDelta>[];
  bestByKey.forEach((key, best) {
    final first = firstByKey[key]!;
    final from = first.previous ?? first.value;
    if (best.value > from) recordDeltas.add(PrDelta(best.exerciseId, best.metric, from, best.value));
  });
  recordDeltas.sort((a, b) => b.delta.compareTo(a.delta));

  double? firstOf(MeasurementType t) {
    final l = measurements.where((m) => m.type == t && !m.date.isAfter(end)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return l.isEmpty ? null : l.first.value;
  }

  double? lastOf(MeasurementType t) {
    final l = measurements.where((m) => m.type == t && !m.date.isAfter(end)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return l.length < 2 ? null : l.last.value;
  }

  return FinalReport(
    workouts: inRange.length,
    consistency: consistency(
        from: start,
        to: end,
        sessionDates: [for (final w in inRange) w.date],
        program: program,
        programStart: start),
    strength: [
      for (final id in PathIds.all)
        if (startNodes[id] != null && currentNodes[id] != null) PathChange(id, startNodes[id]!, currentNodes[id]!)
    ],
    records: recordDeltas,
    prCount: records.where((r) => r.previous != null && !r.date.isAfter(end)).length,
    weightStart: firstOf(MeasurementType.weight),
    weightEnd: lastOf(MeasurementType.weight),
    waistStart: firstOf(MeasurementType.waist),
    waistEnd: lastOf(MeasurementType.waist),
    milestones: milestones.where((m) => !m.date.isAfter(end)).toList(),
    achievementIds: achievementIds,
    totalMinutes: (inRange.fold<int>(0, (s, w) => s + w.durationSec) / 60).round(),
    totalReps: inRange.fold<int>(
        0, (s, w) => s + w.sets.where((x) => !x.skipped && !x.isTimed).fold<int>(0, (a, x) => a + x.achieved)),
  );
}
