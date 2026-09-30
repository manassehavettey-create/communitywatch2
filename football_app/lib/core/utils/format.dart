import 'package:intl/intl.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String kickoffTime(DateTime d) => DateFormat.Hm().format(d.toLocal());

String shortDate(DateTime d) => DateFormat('d MMM').format(d.toLocal());

String longDate(DateTime d) => DateFormat('EEE d MMM yyyy').format(d.toLocal());

String dayLabel(DateTime d, {DateTime? now}) {
  final n = dateOnly(now ?? DateTime.now());
  final x = dateOnly(d.toLocal());
  final diff = x.difference(n).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return DateFormat('EEE d MMM').format(x);
}

/// "3 min ago", "2 h ago" — used for stale-data notices.
String ago(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inSeconds < 45) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 5) return 'Good night';
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
}

/// Season label: 2026 → "2026/27" for split-year competitions.
String seasonLabel(int season, {DateTime? start, DateTime? end}) {
  if (start != null && end != null && start.year == end.year) return '$season';
  return '$season/${((season + 1) % 100).toString().padLeft(2, '0')}';
}

String fmtNum(num? v, {int decimals = 0}) {
  if (v == null) return '—';
  if (decimals == 0) return v.round().toString();
  return v.toStringAsFixed(decimals);
}

/// "Robert Lewandowski" → "R. Lewandowski"; keeps provider short names as-is.
String shortName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length < 2 || parts.first.endsWith('.')) return name;
  return '${parts.first[0]}. ${parts.sublist(1).join(' ')}';
}

/// Surname-ish display for tight pitch labels.
String pitchName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.length == 1 ? name : parts.sublist(1).join(' ');
}
