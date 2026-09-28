import 'package:bible_app/domain/days.dart';
import 'package:bible_app/domain/streaks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const today = '2026-09-28';

  test('no reading means no streak', () {
    final s = computeStreaks(const [], today);
    expect(s.current, 0);
    expect(s.longest, 0);
    expect(s.totalDays, 0);
    expect(s.readToday, isFalse);
  });

  test('consecutive days ending today', () {
    final s = computeStreaks(['2026-09-26', '2026-09-27', '2026-09-28'], today);
    expect(s.current, 3);
    expect(s.longest, 3);
    expect(s.readToday, isTrue);
  });

  test('an unread today does not break a streak that ran to yesterday', () {
    final s = computeStreaks(['2026-09-26', '2026-09-27'], today);
    expect(s.current, 2);
    expect(s.readToday, isFalse);
  });

  test('a missed day resets the current streak but not the longest', () {
    final s = computeStreaks([
      '2026-09-01', '2026-09-02', '2026-09-03', '2026-09-04', // 4
      '2026-09-20', // 1
      '2026-09-27', '2026-09-28', // 2
    ], today);
    expect(s.current, 2);
    expect(s.longest, 4);
    expect(s.totalDays, 7);
  });

  test('streak ended two days ago is broken', () {
    final s = computeStreaks(['2026-09-25', '2026-09-26'], today);
    expect(s.current, 0);
    expect(s.longest, 2);
  });

  test('duplicates and unsorted input are handled', () {
    final s = computeStreaks([
      '2026-09-28',
      '2026-09-27',
      '2026-09-28',
      '2026-09-26',
    ], today);
    expect(s.current, 3);
    expect(s.totalDays, 3);
  });

  test('streaks span month, year and daylight-saving boundaries', () {
    // Europe and the US change clocks in late March and early November.
    final days = [for (var i = 0; i < 10; i++) Days.add('2026-03-25', i)];
    expect(computeStreaks(days, '2026-04-03').current, 10);
    expect(
      computeStreaks([
        '2025-12-30',
        '2025-12-31',
        '2026-01-01',
      ], '2026-01-01').current,
      3,
    );
    expect(
      computeStreaks([
        '2028-02-28',
        '2028-02-29',
        '2028-03-01',
      ], '2028-03-01').current,
      3,
    );
  });

  test('day keys use the local calendar date', () {
    expect(Days.key(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    expect(Days.between('2026-02-27', '2026-03-01'), 2);
    expect(Days.add('2026-12-31', 1), '2027-01-01');
  });
}
