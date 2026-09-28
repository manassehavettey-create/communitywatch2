import 'day_key.dart';

/// Injectable time source so repositories and tests agree on "now".
class Clock {
  const Clock();

  DateTime now() => DateTime.now();

  DayKey today() => Days.keyOf(now());
}

/// A clock whose time can be set and advanced. Used by tests and the
/// debug demo-data seeder.
class FixedClock extends Clock {
  FixedClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime value) => _now = value;

  void advance(Duration d) => _now = _now.add(d);
}
