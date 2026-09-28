import 'days.dart';

class StreakStats {
  const StreakStats({
    required this.current,
    required this.longest,
    required this.totalDays,
    required this.readToday,
  });

  /// Consecutive days read, ending today — or yesterday, since today isn't
  /// over yet and an unread today doesn't break the streak.
  final int current;
  final int longest;
  final int totalDays;
  final bool readToday;

  static const none = StreakStats(
    current: 0,
    longest: 0,
    totalDays: 0,
    readToday: false,
  );
}

/// Computes streaks from the set of days with reading.
StreakStats computeStreaks(Iterable<String> readDays, String today) {
  final days = readDays.toSet();
  if (days.isEmpty) return StreakStats.none;

  final sorted = days.toList()..sort();
  var longest = 1, run = 1;
  for (var i = 1; i < sorted.length; i++) {
    run = Days.between(sorted[i - 1], sorted[i]) == 1 ? run + 1 : 1;
    if (run > longest) longest = run;
  }

  final readToday = days.contains(today);
  var cursor = readToday ? today : Days.add(today, -1);
  var current = 0;
  while (days.contains(cursor)) {
    current++;
    cursor = Days.add(cursor, -1);
  }

  return StreakStats(
    current: current,
    longest: longest < current ? current : longest,
    totalDays: days.length,
    readToday: readToday,
  );
}
