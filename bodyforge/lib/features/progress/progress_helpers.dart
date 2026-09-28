import '../../domain/catalog/exercises.dart';
import '../../domain/engine/records.dart';
import '../../domain/engine/reports.dart';

/// "Push-ups 28 → 34": first recorded value vs best for the most-trained
/// exercise of a family.
class FeaturedRecord {
  const FeaturedRecord({required this.family, required this.exerciseId, required this.first, required this.best, required this.metric});
  final String family;
  final String exerciseId;
  final int first;
  final int best;
  final RecordMetric metric;

  String get label => switch (family) {
        'push_up' => 'Push-ups',
        'plank' => 'Plank',
        'squat' => 'Squats',
        _ => exerciseById(exerciseId).name,
      };
  String get exerciseName => exerciseById(exerciseId).name;
  String format(int v) => formatRecord(v, metric);
}

List<FeaturedRecord> featuredRecords(List<RecordPoint> history) {
  final out = <FeaturedRecord>[];
  for (final family in kFeaturedRecordFamilies) {
    final points = history.where((r) => exerciseById(r.exerciseId).family == family).toList();
    if (points.isEmpty) continue;
    final counts = <String, int>{};
    for (final p in points) {
      counts[p.exerciseId] = (counts[p.exerciseId] ?? 0) + 1;
    }
    final id = (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    final mine = points.where((p) => p.exerciseId == id).toList()..sort((a, b) => a.date.compareTo(b.date));
    final first = mine.first.previous ?? mine.first.value;
    final best = mine.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    out.add(FeaturedRecord(family: family, exerciseId: id, first: first, best: best, metric: mine.first.metric));
  }
  return out;
}
