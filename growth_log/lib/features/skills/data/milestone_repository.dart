import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../../../core/utils/clock.dart';
import '../../log/data/entry_repository.dart';
import '../domain/levels.dart';

@immutable
class Achievement {
  const Achievement({
    required this.skillId,
    required this.skillName,
    required this.hours,
    required this.skillColor,
  });

  final int skillId;
  final String skillName;
  final int hours;
  final int skillColor;

  /// Set when this milestone is also a level threshold.
  Level? get level => Levels.levelAtExactly(hours);

  @override
  String toString() => 'Achievement($skillName, ${hours}h)';
}

/// Keeps achieved milestones in sync with a skill's practice total and
/// auto-logs a win for new ones.
class MilestoneRepository {
  MilestoneRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  static String ref(int skillId, int hours) => '$skillId:$hours';

  Stream<List<MilestoneRow>> watchForSkill(int skillId) =>
      (_db.select(_db.milestones)
            ..where((m) => m.skillId.equals(skillId))
            ..orderBy([(m) => OrderingTerm.asc(m.hours)]))
          .watch();

  Future<List<MilestoneRow>> between(int from, int to) =>
      (_db.select(_db.milestones)
            ..where((m) => m.dayKey.isBetweenValues(from, to))
            ..orderBy([(m) => OrderingTerm.desc(m.hours)]))
          .get();

  /// Reconciles milestones for [skillId] and returns the newly reached ones
  /// (ascending). Milestones no longer reached — because sessions were
  /// edited or deleted — are removed along with their untouched auto wins.
  ///
  /// When several milestones are crossed at once (e.g. back-filling 30 h),
  /// all are recorded but only the highest gets a journal win, so the log
  /// isn't flooded.
  Future<List<Achievement>> reconcile(int skillId) {
    return _db.transaction(() async {
      final skill = await (_db.select(
        _db.skills,
      )..where((s) => s.id.equals(skillId))).getSingleOrNull();
      if (skill == null) return const <Achievement>[];

      final sum = _db.practiceSessions.durationSec.sum();
      final totalRow =
          await (_db.selectOnly(_db.practiceSessions)
                ..addColumns([sum])
                ..where(_db.practiceSessions.skillId.equals(skillId)))
              .getSingle();
      final total = totalRow.read(sum) ?? 0;

      final reached = Levels.reachedMilestones(total).toSet();
      final existing = {
        for (final m in await (_db.select(
          _db.milestones,
        )..where((m) => m.skillId.equals(skillId))).get())
          m.hours,
      };

      final removed = existing.difference(reached);
      if (removed.isNotEmpty) {
        await (_db.delete(_db.milestones)
              ..where((m) => m.skillId.equals(skillId) & m.hours.isIn(removed)))
            .go();
        await (_db.delete(_db.entries)..where(
              (e) =>
                  e.isAuto.equals(true) &
                  e.milestoneRef.isIn(removed.map((h) => ref(skillId, h))),
            ))
            .go();
      }

      final added = reached.difference(existing).toList()..sort();
      if (added.isEmpty) return const <Achievement>[];

      final now = _clock.now();
      final today = _clock.today();
      for (final h in added) {
        await _db
            .into(_db.milestones)
            .insert(
              MilestonesCompanion.insert(
                skillId: skillId,
                hours: h,
                achievedAt: now,
                dayKey: today,
              ),
            );
      }

      final top = added.last;
      final entries = EntryRepository(_db, _clock);
      await entries.addEntry(
        EntryDraft(
          type: EntryType.win,
          body: Levels.milestoneTitle(top, skill.name),
          dayKey: today,
          mood: Levels.levelAtExactly(top) != null ? '🏆' : '🎉',
          skillId: skillId,
          tags: const ['milestone'],
        ),
        isAuto: true,
        milestoneRef: ref(skillId, top),
      );

      return [
        for (final h in added)
          Achievement(
            skillId: skillId,
            skillName: skill.name,
            hours: h,
            skillColor: skill.colorValue,
          ),
      ];
    });
  }
}
