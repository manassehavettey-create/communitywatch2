import '../catalog/skill_paths.dart';
import '../models/enums.dart';
import '../models/profile.dart';
import 'training_params.dart';

enum AreaRating {
  strong('Strong'),
  good('Good'),
  needsWork('Needs work');

  const AreaRating(this.label);
  final String label;
}

class AreaScore {
  const AreaScore(this.area, this.score, this.rating);
  final Area area;

  /// 0–100: how far along the area's skill paths the user is.
  final double score;
  final AreaRating rating;
}

class WeakestLinkReport {
  const WeakestLinkReport(this.scores, this.weakest);
  final Map<Area, AreaScore> scores;

  /// Null when the areas are balanced.
  final Area? weakest;
}

const Map<Area, List<String>> kAreaPaths = {
  Area.upper: [PathIds.push, PathIds.back],
  Area.core: [PathIds.core],
  Area.legs: [PathIds.legs, PathIds.hips],
  Area.conditioning: [PathIds.conditioning],
};

/// Points either side of the personal average that make an area "strong" or
/// "needs work".
const kWeakLinkMargin = 8.0;

/// Spec §11. Scores each area by skill-path position (node + progress within
/// the node's rep range), adjusted by recent completion rates, then rates each
/// area relative to the user's own average.
WeakestLinkReport assessWeakestLink(
  Map<String, TrackProgress> progress,
  TrainingParams params, {
  Map<Area, double> recentCompletion = const {},
}) {
  final raw = <Area, double>{};
  kAreaPaths.forEach((area, paths) {
    final values = <double>[];
    for (final id in paths) {
      final p = progress[id];
      if (p == null) continue;
      final path = pathById(id);
      final (lo, hi) = params.nodeWindow(path, p.nodeIndex);
      final within = hi == lo ? 0.0 : ((p.amount - lo) / (hi - lo)).clamp(0.0, 0.95);
      values.add((p.nodeIndex + within) / path.length * 100);
    }
    if (values.isEmpty) return;
    var score = values.reduce((a, b) => a + b) / values.length;
    final completion = recentCompletion[area];
    if (completion != null && completion < 0.85) {
      score -= (0.85 - completion) * 30; // up to ~ -25 for very low completion
    }
    raw[area] = score.clamp(0, 100).toDouble();
  });

  if (raw.isEmpty) return const WeakestLinkReport({}, null);
  final mean = raw.values.reduce((a, b) => a + b) / raw.length;
  final scores = <Area, AreaScore>{};
  raw.forEach((area, s) {
    final rating = s >= mean + kWeakLinkMargin
        ? AreaRating.strong
        : s <= mean - kWeakLinkMargin
            ? AreaRating.needsWork
            : AreaRating.good;
    scores[area] = AreaScore(area, s, rating);
  });

  Area? weakest;
  double lowest = double.infinity;
  scores.forEach((area, s) {
    if (s.rating == AreaRating.needsWork && s.score < lowest) {
      lowest = s.score;
      weakest = area;
    }
  });
  return WeakestLinkReport(scores, weakest);
}
