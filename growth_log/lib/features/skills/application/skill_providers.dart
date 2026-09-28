import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/streaks.dart';
import '../../../core/providers.dart';
import '../../../core/utils/day_key.dart';
import '../domain/levels.dart';

@immutable
class SkillStats {
  const SkillStats({
    required this.skill,
    required this.totalSec,
    required this.weekSec,
    required this.streak,
  });

  final SkillRow skill;
  final int totalSec;
  final int weekSec;
  final Streak streak;

  LevelProgress get level => Levels.progress(totalSec);

  double get targetFraction =>
      (totalSec / 3600 / skill.targetHours).clamp(0.0, 1.0);
}

/// Current week bounds honouring the user's week-start preference.
final currentWeekProvider = Provider<(DayKey, DayKey)>((ref) {
  final today = ref.watch(todayProvider);
  final monday = ref.watch(settingsProvider.select((s) => s.weekStartsMonday));
  final start = Days.weekStart(today, mondayFirst: monday);
  return (start, Days.add(start, 6));
});

Stream<List<SkillStats>> _skillStats(Ref ref, {required bool archived}) {
  final repo = ref.watch(skillRepositoryProvider);
  final today = ref.watch(todayProvider);
  final (weekStart, weekEnd) = ref.watch(currentWeekProvider);
  return repo.watch(() async {
    final skills = await repo.listSkills(archived: archived);
    final totals = await repo.totalsBySkill();
    final week = await repo.totalsBySkill(from: weekStart, to: weekEnd);
    final days = await repo.practiceDaysBySkill();
    return [
      for (final s in skills)
        SkillStats(
          skill: s,
          totalSec: totals[s.id] ?? 0,
          weekSec: week[s.id] ?? 0,
          streak: Streaks.compute(days[s.id] ?? const {}, today),
        ),
    ];
  });
}

final skillsOverviewProvider = StreamProvider<List<SkillStats>>(
  (ref) => _skillStats(ref, archived: false),
);

final archivedSkillsProvider = StreamProvider.autoDispose<List<SkillStats>>(
  (ref) => _skillStats(ref, archived: true),
);

@immutable
class SkillDetail {
  const SkillDetail({
    required this.stats,
    required this.sessions,
    required this.milestones,
    required this.daily,
  });

  final SkillStats stats;
  final List<SessionRow> sessions;
  final List<MilestoneRow> milestones;

  /// dayKey → seconds, all time.
  final Map<DayKey, int> daily;

  SkillRow get skill => stats.skill;

  int get avgSessionSec =>
      sessions.isEmpty ? 0 : stats.totalSec ~/ sessions.length;
}

final skillDetailProvider =
    StreamProvider.autoDispose.family<SkillDetail?, int>((ref, id) {
  final repo = ref.watch(skillRepositoryProvider);
  final milestoneRepo = ref.watch(milestoneRepositoryProvider);
  final today = ref.watch(todayProvider);
  final (weekStart, weekEnd) = ref.watch(currentWeekProvider);
  return repo.watch(() async {
    final skill = await repo.getSkill(id);
    if (skill == null) return null;
    final daily = await repo.dailySeconds(skillId: id);
    final total = daily.values.fold<int>(0, (a, b) => a + b);
    final week = daily.entries
        .where((e) => e.key >= weekStart && e.key <= weekEnd)
        .fold<int>(0, (a, e) => a + e.value);
    final sessions = await repo.watchSessions(skillId: id).first;
    final milestones = await milestoneRepo.watchForSkill(id).first;
    return SkillDetail(
      stats: SkillStats(
        skill: skill,
        totalSec: total,
        weekSec: week,
        streak: Streaks.compute(daily.keys, today),
      ),
      sessions: sessions,
      milestones: milestones,
      daily: daily,
    );
  });
});
