import 'package:intl/intl.dart';

import 'day_key.dart';

abstract final class Fmt {
  /// "1h 25m", "45m", "0m".
  static String duration(int seconds) {
    if (seconds < 60) return seconds <= 0 ? '0m' : '<1m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Hours with sensible precision: "0.5", "12.4", "1,240".
  static String hours(num seconds) {
    final h = seconds / 3600;
    if (h >= 100) return NumberFormat.decimalPattern().format(h.floor());
    return h.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }

  /// "01:05:09" style stopwatch readout.
  static String clock(Duration d) {
    final s = d.inSeconds.clamp(0, 359999);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
  }

  static String number(num n) => NumberFormat.decimalPattern().format(n);

  static String timeOfDay(int minutes) {
    final dt = DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60);
    return DateFormat.jm().format(dt);
  }

  /// "Today", "Yesterday", or "Mon, 22 Sep" (adds year when not current).
  static String dayLabel(DayKey key, DayKey today) {
    final diff = Days.between(key, today);
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    final d = Days.dateOf(key);
    final sameYear = key ~/ 10000 == today ~/ 10000;
    return sameYear
        ? DateFormat('EEE, d MMM').format(d)
        : DateFormat('EEE, d MMM y').format(d);
  }

  static String shortDate(DayKey key) =>
      DateFormat('d MMM').format(Days.dateOf(key));

  static String monthYear(DayKey key) =>
      DateFormat('MMMM y').format(Days.dateOf(key));

  static String monthShort(DayKey key) =>
      DateFormat('MMM').format(Days.dateOf(key));

  static String weekdayShort(DayKey key) =>
      DateFormat('EEE').format(Days.dateOf(key));

  static String time(DateTime dt) => DateFormat.jm().format(dt);

  static String percentChange(num current, num previous) {
    if (previous == 0) return current == 0 ? '0%' : 'New';
    final pct = ((current - previous) / previous * 100).round();
    return '${pct >= 0 ? '+' : ''}$pct%';
  }

  static String plural(int n, String one, [String? many]) =>
      '${number(n)} ${n == 1 ? one : (many ?? '${one}s')}';
}
