import 'package:flutter_test/flutter_test.dart';
import 'package:growth_log/core/domain/streaks.dart';
import 'package:growth_log/core/utils/day_key.dart';

void main() {
  const today = 20260928;

  test('no activity', () {
    expect(Streaks.compute([], today), Streak.zero);
  });

  test('active today only', () {
    expect(
      Streaks.compute([today], today),
      const Streak(current: 1, longest: 1, activeToday: true),
    );
  });

  test('streak is still alive when the last activity was yesterday', () {
    final s = Streaks.compute([20260926, 20260927], today);
    expect(s.current, 2);
    expect(s.activeToday, isFalse);
  });

  test('streak breaks after a missed day', () {
    final s = Streaks.compute([20260925, 20260926], today);
    expect(s.current, 0);
    expect(s.longest, 2);
  });

  test('longest streak is tracked separately from current', () {
    final s = Streaks.compute(
      [20260901, 20260902, 20260903, 20260904, 20260927, 20260928],
      today,
    );
    expect(s.current, 2);
    expect(s.longest, 4);
  });

  test('crosses month and year boundaries', () {
    final s = Streaks.compute(
      [20251230, 20251231, 20260101, 20260102],
      20260102,
    );
    expect(s.current, 4);
  });

  test('handles leap day', () {
    final s = Streaks.compute([20280228, 20280229, 20280301], 20280301);
    expect(s.current, 3);
  });

  test('duplicate days and unsorted input are fine', () {
    final s = Streaks.compute([today, 20260927, today, 20260927], today);
    expect(s.current, 2);
  });

  test('days in the future (clock moved back) are ignored', () {
    final s = Streaks.compute([20260927, 20261005], today);
    expect(s.current, 1);
    expect(s.longest, 1);
  });

  group('Days helpers', () {
    test('add across DST changes uses calendar days', () {
      // Europe/US DST shifts happen in March/Oct/Nov; calendar maths
      // must not be affected by 23h/25h days.
      expect(Days.add(20260328, 1), 20260329);
      expect(Days.add(20260329, 1), 20260330);
      expect(Days.add(20261031, 1), 20261101);
      expect(Days.add(20261101, 1), 20261102);
      expect(Days.between(20260301, 20260401), 31);
    });

    test('week start honours preference', () {
      // 2026-09-28 is a Monday.
      expect(Days.weekStart(20260928), 20260928);
      expect(Days.weekStart(20261004), 20260928); // Sunday
      expect(Days.weekStart(20261004, mondayFirst: false), 20261004);
      expect(Days.weekStart(20260930, mondayFirst: false), 20260927);
    });

    test('month helpers', () {
      expect(Days.monthStart(20260228), 20260201);
      expect(Days.monthEnd(20260210), 20260228);
      expect(Days.monthEnd(20280210), 20280229);
      expect(Days.addMonths(20260131, 1), 20260201);
      expect(Days.addMonths(20260115, -1), 20251201);
    });
  });
}
