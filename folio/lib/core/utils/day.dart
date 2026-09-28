/// Local calendar-day helpers. Days are stored as `yyyy-MM-dd` strings so
/// streaks follow the reader's own calendar, not UTC.
String dayKey(DateTime t) {
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year.toString().padLeft(4, '0')}-${two(l.month)}-${two(l.day)}';
}

DateTime parseDayKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

DateTime dateOnly(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Calendar-safe day arithmetic (ignores DST hour shifts).
DateTime addDays(DateTime day, int n) => DateTime(day.year, day.month, day.day + n);

/// Monday of the week containing [day].
DateTime startOfWeek(DateTime day) => addDays(dateOnly(day), -(day.weekday - 1));
