import 'package:intl/intl.dart';

import 'day.dart';

String formatDuration(Duration d, {bool short = false}) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return m == 0 ? '${h}h' : '${h}h ${m}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m';
  if (short) return '0m';
  return '${d.inSeconds}s';
}

String formatClock(Duration d) {
  final neg = d.isNegative;
  final a = d.abs();
  final m = a.inMinutes;
  final s = a.inSeconds.remainder(60);
  return '${neg ? '-' : ''}${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String relativeDay(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final days = dateOnly(n).difference(dateOnly(t)).inDays;
  if (days <= 0) {
    final mins = n.difference(t).inMinutes;
    if (mins < 1) return 'Just now';
    if (mins < 60) return '$mins min ago';
    return 'Today';
  }
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  if (t.year == n.year) return DateFormat.MMMd().format(t);
  return DateFormat.yMMMd().format(t);
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var v = bytes / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

String greeting(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Good night';
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';
