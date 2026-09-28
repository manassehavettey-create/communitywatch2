/// A calendar date without time or time zone. All day-based logic (calendar,
/// weeks, journey) uses this so time-zone and DST changes can't shift a
/// workout onto the wrong day. Stored as `yyyy-MM-dd`.
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  factory LocalDate.fromDateTime(DateTime dt) => LocalDate(dt.year, dt.month, dt.day);

  /// Parses `yyyy-MM-dd`.
  factory LocalDate.parse(String s) {
    final p = s.split('-');
    if (p.length != 3) throw FormatException('Bad date: $s');
    return LocalDate(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  static LocalDate? tryParse(String? s) {
    if (s == null) return null;
    try {
      return LocalDate.parse(s);
    } on FormatException {
      return null;
    }
  }

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// 1 = Monday … 7 = Sunday.
  int get weekday => _utc.weekday;

  LocalDate addDays(int days) => LocalDate.fromDateTime(_utc.add(Duration(days: days)));

  /// Whole days from [other] to this (positive if this is later).
  int daysSince(LocalDate other) => _utc.difference(other._utc).inDays;

  /// Monday of this date's week.
  LocalDate get startOfWeek => addDays(1 - weekday);

  bool isBefore(LocalDate o) => compareTo(o) < 0;
  bool isAfter(LocalDate o) => compareTo(o) > 0;
  bool isSameOrBefore(LocalDate o) => compareTo(o) <= 0;
  bool isSameOrAfter(LocalDate o) => compareTo(o) >= 0;

  /// Local midnight as a DateTime in the device zone.
  DateTime toLocalDateTime() => DateTime(year, month, day);

  @override
  int compareTo(LocalDate o) => _utc.compareTo(o._utc);

  @override
  bool operator ==(Object other) =>
      other is LocalDate && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

/// Abstract clock so the engine and UI can be tested at any date/time.
abstract class Clock {
  const Clock();
  DateTime now();
  LocalDate today() => LocalDate.fromDateTime(now());
}

class SystemClock extends Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now();
}

class FixedClock extends Clock {
  FixedClock(this.value);
  DateTime value;
  @override
  DateTime now() => value;
  void advance(Duration d) => value = value.add(d);
}
