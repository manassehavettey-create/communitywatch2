import 'package:flutter/foundation.dart';

@immutable
class Level {
  const Level(this.index, this.name, this.minHours, this.badgeAsset);

  final int index;
  final String name;
  final int minHours;
  final String badgeAsset;

  @override
  String toString() => 'Level($name)';
}

@immutable
class LevelProgress {
  const LevelProgress({
    required this.current,
    required this.next,
    required this.fraction,
    required this.secondsToNext,
  });

  final Level current;

  /// Null when the top level has been reached.
  final Level? next;

  /// 0..1 progress from [current] to [next]; 1 at max level.
  final double fraction;
  final int secondsToNext;

  bool get isMax => next == null;
}

abstract final class Levels {
  static const novice =
      Level(0, 'Novice', 0, 'assets/images/badges/badge_novice.png');
  static const apprentice =
      Level(1, 'Apprentice', 20, 'assets/images/badges/badge_apprentice.png');
  static const skilled =
      Level(2, 'Skilled', 100, 'assets/images/badges/badge_skilled.png');
  static const expert =
      Level(3, 'Expert', 1000, 'assets/images/badges/badge_expert.png');
  static const master =
      Level(4, 'Master', 10000, 'assets/images/badges/badge_master.png');

  static const all = [novice, apprentice, skilled, expert, master];

  /// Every hour mark that auto-logs a win. Level thresholds are included.
  static const milestoneHours = [
    1, 5, 10, 20, 50, 100, 250, 500, 1000, 2500, 5000, 10000, //
  ];

  static Level forSeconds(int seconds) {
    final hours = seconds / 3600;
    var result = novice;
    for (final l in all) {
      if (hours >= l.minHours) result = l;
    }
    return result;
  }

  static LevelProgress progress(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final current = forSeconds(safe);
    final next = current.index + 1 < all.length ? all[current.index + 1] : null;
    if (next == null) {
      return LevelProgress(
        current: current,
        next: null,
        fraction: 1,
        secondsToNext: 0,
      );
    }
    final start = current.minHours * 3600;
    final end = next.minHours * 3600;
    return LevelProgress(
      current: current,
      next: next,
      fraction: ((safe - start) / (end - start)).clamp(0.0, 1.0),
      secondsToNext: end - safe,
    );
  }

  /// Milestone hour marks reached with [seconds] of practice.
  static List<int> reachedMilestones(int seconds) =>
      milestoneHours.where((h) => seconds >= h * 3600).toList();

  static Level? levelAtExactly(int hours) {
    for (final l in all) {
      if (l.minHours == hours && l.minHours > 0) return l;
    }
    return null;
  }

  static String milestoneTitle(int hours, String skillName) {
    final level = levelAtExactly(hours);
    if (level != null) {
      return 'Reached ${level.name} in $skillName — $hours hours of practice!';
    }
    return 'Hit $hours ${hours == 1 ? 'hour' : 'hours'} of $skillName practice!';
  }
}
