import 'package:flutter/foundation.dart';

import '../utils/day_key.dart';

@immutable
class Streak {
  const Streak({
    required this.current,
    required this.longest,
    required this.activeToday,
  });

  static const zero = Streak(current: 0, longest: 0, activeToday: false);

  /// Consecutive active days ending today — or ending yesterday, since a
  /// streak is still alive until the current day is over.
  final int current;
  final int longest;
  final bool activeToday;

  @override
  bool operator ==(Object other) =>
      other is Streak &&
      other.current == current &&
      other.longest == longest &&
      other.activeToday == activeToday;

  @override
  int get hashCode => Object.hash(current, longest, activeToday);

  @override
  String toString() =>
      'Streak(current: $current, longest: $longest, today: $activeToday)';
}

abstract final class Streaks {
  /// Computes streaks from the set of days that had activity.
  ///
  /// Days after [today] (e.g. from a clock that moved backwards) are ignored.
  static Streak compute(Iterable<DayKey> activeDays, DayKey today) {
    final days = activeDays.where((d) => d <= today).toSet().toList()..sort();
    if (days.isEmpty) return Streak.zero;

    var longest = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      if (Days.between(days[i - 1], days[i]) == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
    }

    final activeToday = days.last == today;
    final yesterday = Days.add(today, -1);
    var current = 0;
    if (activeToday || days.last == yesterday) {
      current = 1;
      for (var i = days.length - 1; i > 0; i--) {
        if (Days.between(days[i - 1], days[i]) == 1) {
          current++;
        } else {
          break;
        }
      }
    }

    return Streak(current: current, longest: longest, activeToday: activeToday);
  }
}
