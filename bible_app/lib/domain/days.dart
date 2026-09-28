/// Local calendar days as "yyyy-mm-dd" keys. Day arithmetic goes through
/// UTC dates so daylight-saving changes never skip or repeat a day.
abstract final class Days {
  static String key(DateTime local) =>
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';

  static String today([DateTime? now]) => key(now ?? DateTime.now());

  /// The day as a UTC midnight, for arithmetic.
  static DateTime parse(String key) {
    final p = key.split('-');
    return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  /// Whole days from [a] to [b] (positive when b is later).
  static int between(String a, String b) =>
      parse(b).difference(parse(a)).inDays;

  static String add(String key, int days) {
    final d = parse(key).add(Duration(days: days));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Local-midnight epoch milliseconds of a day key (for storage).
  static int toLocalMillis(String key) {
    final p = key.split('-');
    return DateTime(
      int.parse(p[0]),
      int.parse(p[1]),
      int.parse(p[2]),
    ).millisecondsSinceEpoch;
  }
}
