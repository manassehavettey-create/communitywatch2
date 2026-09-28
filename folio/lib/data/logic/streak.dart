import '../../core/utils/day.dart';

/// Minimum activity for a day to count toward a streak.
const int kStreakMinSeconds = 60;

bool qualifiesForStreak({required int pagesRead, required int seconds}) =>
    pagesRead > 0 || seconds >= kStreakMinSeconds;

class StreakResult {
  const StreakResult({
    required this.current,
    required this.longest,
    required this.readToday,
  });

  /// Consecutive reading days ending today, or ending yesterday when today
  /// has no reading yet (the streak is still alive until the day is over).
  final int current;
  final int longest;
  final bool readToday;

  static const empty = StreakResult(current: 0, longest: 0, readToday: false);
}

/// Computes current and longest streaks from the set of qualifying days.
StreakResult computeStreak(Iterable<DateTime> readingDays, DateTime now) {
  final days = readingDays.map(dateOnly).toSet();
  if (days.isEmpty) return StreakResult.empty;

  final today = dateOnly(now);
  final readToday = days.contains(today);

  var current = 0;
  var cursor = readToday ? today : addDays(today, -1);
  while (days.contains(cursor)) {
    current++;
    cursor = addDays(cursor, -1);
  }

  final sorted = days.toList()..sort();
  var longest = 0;
  var run = 0;
  DateTime? prev;
  for (final d in sorted) {
    if (prev != null && addDays(prev, 1) == d) {
      run++;
    } else {
      run = 1;
    }
    if (run > longest) longest = run;
    prev = d;
  }

  return StreakResult(current: current, longest: longest, readToday: readToday);
}
