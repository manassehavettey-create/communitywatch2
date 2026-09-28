import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/watch.dart';
import '../../../core/domain/streaks.dart';
import '../../../core/providers.dart';
import '../../../core/utils/day_key.dart';
import '../../../core/utils/format.dart';
import '../../log/data/entry_repository.dart';

enum InsightPeriod {
  week('Week'),
  month('Month'),
  year('Year');

  const InsightPeriod(this.label);
  final String label;
}

@immutable
class ChartBucket {
  const ChartBucket(this.label, this.seconds, {this.highlight = false});
  final String label;
  final int seconds;
  final bool highlight;
}

@immutable
class SkillShare {
  const SkillShare(this.skill, this.seconds);
  final SkillRow skill;
  final int seconds;
}

@immutable
class InsightsData {
  const InsightsData({
    required this.period,
    required this.from,
    required this.to,
    required this.seconds,
    required this.prevSeconds,
    required this.buckets,
    required this.bySkill,
    required this.counts,
    required this.topTags,
    required this.practiceStreak,
    required this.logStreak,
    required this.activeDays,
    required this.sessions,
  });

  final InsightPeriod period;
  final DayKey from;
  final DayKey to;
  final int seconds;
  final int prevSeconds;
  final List<ChartBucket> buckets;
  final List<SkillShare> bySkill;
  final Map<EntryType, int> counts;
  final List<TagCount> topTags;
  final Streak practiceStreak;
  final Streak logStreak;
  final int activeDays;
  final int sessions;

  bool get isEmpty =>
      seconds == 0 && counts.values.every((c) => c == 0) && sessions == 0;
}

(DayKey, DayKey) periodRange(InsightPeriod p, DayKey today, bool mondayFirst) {
  switch (p) {
    case InsightPeriod.week:
      final s = Days.weekStart(today, mondayFirst: mondayFirst);
      return (s, Days.add(s, 6));
    case InsightPeriod.month:
      return (Days.monthStart(today), Days.monthEnd(today));
    case InsightPeriod.year:
      final s = Days.yearStart(today);
      return (s, (s ~/ 10000) * 10000 + 1231);
  }
}

(DayKey, DayKey) previousRange(InsightPeriod p, DayKey from) {
  switch (p) {
    case InsightPeriod.week:
      return (Days.add(from, -7), Days.add(from, -1));
    case InsightPeriod.month:
      final s = Days.addMonths(from, -1);
      return (s, Days.monthEnd(s));
    case InsightPeriod.year:
      final s = from - 10000;
      return (s, (s ~/ 10000) * 10000 + 1231);
  }
}

final insightsProvider =
    StreamProvider.autoDispose.family<InsightsData, InsightPeriod>((ref, period) {
  final db = ref.watch(databaseProvider);
  final skillsRepo = ref.watch(skillRepositoryProvider);
  final entries = ref.watch(entryRepositoryProvider);
  final today = ref.watch(todayProvider);
  final monday = ref.watch(settingsProvider.select((s) => s.weekStartsMonday));

  return db.watchTables(
    [db.skills, db.practiceSessions, db.entries, db.entryTags, db.tags],
    () async {
      final (from, to) = periodRange(period, today, monday);
      final (pFrom, pTo) = previousRange(period, from);
      final daily = await skillsRepo.dailySeconds(from: from, to: to);
      final prev = await skillsRepo.dailySeconds(from: pFrom, to: pTo);
      final seconds = daily.values.fold<int>(0, (a, b) => a + b);

      final buckets = <ChartBucket>[];
      switch (period) {
        case InsightPeriod.week:
          for (var i = 0; i < 7; i++) {
            final d = Days.add(from, i);
            buckets.add(ChartBucket(
              Fmt.weekdayShort(d).substring(0, 2),
              daily[d] ?? 0,
              highlight: d == today,
            ));
          }
        case InsightPeriod.month:
          for (final d in Days.range(from, to)) {
            final day = d % 100;
            buckets.add(ChartBucket(
              day == 1 || day % 5 == 0 ? '$day' : '',
              daily[d] ?? 0,
              highlight: d == today,
            ));
          }
        case InsightPeriod.year:
          for (var m = 0; m < 12; m++) {
            final start = Days.addMonths(from, m);
            final end = Days.monthEnd(start);
            var sum = 0;
            daily.forEach((d, s) {
              if (d >= start && d <= end) sum += s;
            });
            buckets.add(ChartBucket(
              Fmt.monthShort(start).substring(0, 1),
              sum,
              highlight: today >= start && today <= end,
            ));
          }
      }

      final totals = await skillsRepo.totalsBySkill(from: from, to: to);
      final allSkills = {for (final s in await skillsRepo.allSkills()) s.id: s};
      final bySkill = [
        for (final e in totals.entries)
          if (allSkills[e.key] != null) SkillShare(allSkills[e.key]!, e.value),
      ]..sort((a, b) => b.seconds.compareTo(a.seconds));

      final sessions = await skillsRepo.sessionsBetween(from, to);
      final entryDays = await entries.entryDays();
      final practiceDays = await skillsRepo.practiceDays();

      return InsightsData(
        period: period,
        from: from,
        to: to,
        seconds: seconds,
        prevSeconds: prev.values.fold<int>(0, (a, b) => a + b),
        buckets: buckets,
        bySkill: bySkill,
        counts: await entries.countsBetween(from, to),
        topTags: (await entries.tagCounts(from: from, to: to)).take(8).toList(),
        practiceStreak: Streaks.compute(practiceDays, today),
        logStreak: Streaks.compute(entryDays, today),
        activeDays: {
          ...daily.keys,
          ...entryDays.where((d) => d >= from && d <= to),
        }.length,
        sessions: sessions.length,
      );
    },
  );
});

// ------------------------------------------------------------------ recap

@immutable
class RecapMilestone {
  const RecapMilestone(this.skill, this.hours);
  final SkillRow skill;
  final int hours;
}

@immutable
class RecapData {
  const RecapData({
    required this.month,
    required this.gratitudeCount,
    required this.winCount,
    required this.seconds,
    required this.sessions,
    required this.activeDays,
    required this.topTags,
    required this.milestones,
    required this.wins,
    required this.topSkill,
    required this.topSkillSeconds,
    required this.hasOlder,
  });

  final DayKey month;
  final int gratitudeCount;
  final int winCount;
  final int seconds;
  final int sessions;
  final int activeDays;
  final List<TagCount> topTags;
  final List<RecapMilestone> milestones;
  final List<EntryView> wins;
  final SkillRow? topSkill;
  final int topSkillSeconds;
  final bool hasOlder;

  int get entryCount => gratitudeCount + winCount;
  bool get isEmpty => entryCount == 0 && sessions == 0;
}

final recapProvider =
    FutureProvider.autoDispose.family<RecapData, DayKey>((ref, month) async {
  final skillsRepo = ref.watch(skillRepositoryProvider);
  final entries = ref.watch(entryRepositoryProvider);
  final milestones = ref.watch(milestoneRepositoryProvider);
  // Recompute when data changes while the screen is open.
  ref.watch(_recapTickProvider);

  final from = Days.monthStart(month);
  final to = Days.monthEnd(month);
  final daily = await skillsRepo.dailySeconds(from: from, to: to);
  final sessions = await skillsRepo.sessionsBetween(from, to);
  final counts = await entries.countsBetween(from, to);
  final monthEntries = await entries.between(from, to);
  final totals = await skillsRepo.totalsBySkill(from: from, to: to);
  final skills = {for (final s in await skillsRepo.allSkills()) s.id: s};

  final wins = monthEntries.where((e) => e.type == EntryType.win).toList()
    // Personal wins first, then milestone wins; newest first within each.
    ..sort((a, b) {
      if (a.entry.isAuto != b.entry.isAuto) return a.entry.isAuto ? 1 : -1;
      return b.entry.dayKey.compareTo(a.entry.dayKey);
    });

  final ms = [
    for (final m in await milestones.between(from, to))
      if (skills[m.skillId] != null) RecapMilestone(skills[m.skillId]!, m.hours),
  ];

  MapEntry<int, int>? top;
  for (final e in totals.entries) {
    if (top == null || e.value > top.value) top = e;
  }

  final allDays = {...await skillsRepo.practiceDays(), ...await entries.entryDays()};
  return RecapData(
    month: from,
    gratitudeCount: counts[EntryType.gratitude] ?? 0,
    winCount: counts[EntryType.win] ?? 0,
    seconds: daily.values.fold<int>(0, (a, b) => a + b),
    sessions: sessions.length,
    activeDays: {
      ...daily.keys,
      ...monthEntries.map((e) => e.entry.dayKey),
    }.length,
    topTags: (await entries.tagCounts(from: from, to: to))
        .where((t) => t.name != 'milestone')
        .take(6)
        .toList(),
    milestones: ms,
    wins: wins.take(12).toList(),
    topSkill: top == null ? null : skills[top.key],
    topSkillSeconds: top?.value ?? 0,
    hasOlder: allDays.any((d) => d < from),
  );
});

final _recapTickProvider = StreamProvider.autoDispose<int>((ref) {
  final db = ref.watch(databaseProvider);
  var i = 0;
  return db.watchTables(
    [db.practiceSessions, db.entries, db.milestones],
    () async => i++,
  );
});
