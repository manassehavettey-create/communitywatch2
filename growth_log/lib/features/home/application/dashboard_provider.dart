import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/watch.dart';
import '../../../core/domain/streaks.dart';
import '../../../core/providers.dart';
import '../../../core/utils/day_key.dart';
import '../../skills/application/skill_providers.dart';

@immutable
class Dashboard {
  const Dashboard({
    required this.weekStart,
    required this.weekDaily,
    required this.weekSec,
    required this.lastWeekSec,
    required this.practiceStreak,
    required this.logStreak,
    required this.entryDays,
    required this.entryCountByDay,
    required this.sessionCountByDay,
  });

  final DayKey weekStart;
  final Map<DayKey, int> weekDaily;
  final int weekSec;
  final int lastWeekSec;
  final Streak practiceStreak;
  final Streak logStreak;
  final Set<DayKey> entryDays;
  final Map<DayKey, int> entryCountByDay;
  final Map<DayKey, int> sessionCountByDay;

  List<DayKey> get weekDays => [for (var i = 0; i < 7; i++) Days.add(weekStart, i)];
}

final dashboardProvider = StreamProvider<Dashboard>((ref) {
  final db = ref.watch(databaseProvider);
  final skills = ref.watch(skillRepositoryProvider);
  final entries = ref.watch(entryRepositoryProvider);
  final today = ref.watch(todayProvider);
  final (weekStart, weekEnd) = ref.watch(currentWeekProvider);

  return db.watchTables([db.practiceSessions, db.entries], () async {
    final daily = await skills.dailySeconds(
      from: Days.add(weekStart, -7),
      to: weekEnd,
    );
    var week = 0;
    var last = 0;
    final weekDaily = <DayKey, int>{};
    daily.forEach((day, sec) {
      if (day >= weekStart) {
        week += sec;
        weekDaily[day] = sec;
      } else {
        last += sec;
      }
    });

    final sessions = await skills.sessionsBetween(weekStart, weekEnd);
    final sessionCount = <DayKey, int>{};
    for (final s in sessions) {
      sessionCount[s.dayKey] = (sessionCount[s.dayKey] ?? 0) + 1;
    }
    final weekEntries = await entries.between(weekStart, weekEnd);
    final entryCount = <DayKey, int>{};
    for (final e in weekEntries) {
      entryCount[e.entry.dayKey] = (entryCount[e.entry.dayKey] ?? 0) + 1;
    }
    final entryDays = await entries.entryDays();

    return Dashboard(
      weekStart: weekStart,
      weekDaily: weekDaily,
      weekSec: week,
      lastWeekSec: last,
      practiceStreak: Streaks.compute(await skills.practiceDays(), today),
      logStreak: Streaks.compute(entryDays, today),
      entryDays: entryDays,
      entryCountByDay: entryCount,
      sessionCountByDay: sessionCount,
    );
  });
});
