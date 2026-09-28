/// A calendar day encoded as an int `yyyymmdd` (e.g. 20260928).
///
/// Every session and entry stores the *local* calendar day it belongs to at
/// the moment it was logged. Grouping, streaks and charts all use this key,
/// so travelling across time zones or DST changes never reshuffles history.
typedef DayKey = int;

abstract final class Days {
  static DayKey keyOf(DateTime local) =>
      local.year * 10000 + local.month * 100 + local.day;

  /// Midnight (local) of the given key.
  static DateTime dateOf(DayKey key) =>
      DateTime(key ~/ 10000, (key ~/ 100) % 100, key % 100);

  /// Adds calendar days. Uses date arithmetic (not Duration) so DST days
  /// that are 23 or 25 hours long are handled correctly.
  static DayKey add(DayKey key, int days) {
    final d = dateOf(key);
    return keyOf(DateTime(d.year, d.month, d.day + days));
  }

  /// Calendar days from [a] to [b] (positive when b is later).
  static int between(DayKey a, DayKey b) {
    final da = dateOf(a);
    final db = dateOf(b);
    // Compare as UTC dates to avoid DST hour offsets.
    return DateTime.utc(db.year, db.month, db.day)
        .difference(DateTime.utc(da.year, da.month, da.day))
        .inDays;
  }

  /// First day of the week containing [key].
  static DayKey weekStart(DayKey key, {bool mondayFirst = true}) {
    final d = dateOf(key);
    final weekday = d.weekday; // Mon=1..Sun=7
    final offset = mondayFirst ? weekday - 1 : weekday % 7;
    return add(key, -offset);
  }

  static DayKey monthStart(DayKey key) => (key ~/ 100) * 100 + 1;

  static DayKey monthEnd(DayKey key) {
    final d = dateOf(key);
    return keyOf(DateTime(d.year, d.month + 1, 0));
  }

  static DayKey yearStart(DayKey key) => (key ~/ 10000) * 10000 + 101;

  /// Shifts by whole months, clamping to the start of the month.
  static DayKey addMonths(DayKey key, int months) {
    final d = dateOf(key);
    return keyOf(DateTime(d.year, d.month + months, 1));
  }

  static Iterable<DayKey> range(DayKey from, DayKey toInclusive) sync* {
    var k = from;
    while (k <= toInclusive) {
      yield k;
      k = add(k, 1);
    }
  }
}
