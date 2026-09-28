import '../catalog/exercises.dart';
import '../models/workout.dart';

enum RecordMetric { maxReps, maxHold }

class PrEvent {
  const PrEvent({required this.exerciseId, required this.metric, required this.previous, required this.current});

  final String exerciseId;
  final RecordMetric metric;

  /// Null when this is the first time the exercise was recorded (a baseline).
  final int? previous;
  final int current;

  /// A baseline isn't celebrated — only beating a previous record is a PR.
  bool get isBaseline => previous == null;
  bool get isPr => previous != null && current > previous!;
  int get delta => previous == null ? 0 : current - previous!;

  String get key => recordKey(exerciseId, metric);
}

String recordKey(String exerciseId, RecordMetric metric) => '$exerciseId|${metric.name}';

RecordMetric metricFor(String exerciseId) =>
    exerciseById(exerciseId).isTimed ? RecordMetric.maxHold : RecordMetric.maxReps;

/// Spec §12. Compares the best set of each exercise in this session against
/// the stored bests (keyed by [recordKey]). Warm-up / cool-down sets never
/// count. Returns baselines (first time) and real PRs.
List<PrEvent> detectRecords(Map<String, int> bests, List<SetResult> sets) {
  final bestThisSession = <String, int>{};
  for (final s in sets) {
    if (s.skipped || s.achieved <= 0) continue;
    if (s.blockKind == BlockKind.warmup || s.blockKind == BlockKind.cooldown) continue;
    final key = recordKey(s.exerciseId, metricFor(s.exerciseId));
    final prev = bestThisSession[key];
    if (prev == null || s.achieved > prev) bestThisSession[key] = s.achieved;
  }

  final events = <PrEvent>[];
  bestThisSession.forEach((key, value) {
    final parts = key.split('|');
    final metric = RecordMetric.values.byName(parts[1]);
    final previous = bests[key];
    if (previous == null) {
      events.add(PrEvent(exerciseId: parts[0], metric: metric, previous: null, current: value));
    } else if (value > previous) {
      events.add(PrEvent(exerciseId: parts[0], metric: metric, previous: previous, current: value));
    }
  });
  events.sort((a, b) => b.delta.compareTo(a.delta));
  return events;
}

/// Formats a record value: reps as "34", holds as "2:15".
String formatRecord(int value, RecordMetric metric) {
  if (metric == RecordMetric.maxReps) return '$value';
  return formatSeconds(value);
}

String formatSeconds(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m == 0) return '${s}s';
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Featured records shown on Home / weekly check (spec §12, §26).
const kFeaturedRecordFamilies = ['push_up', 'plank', 'squat'];
