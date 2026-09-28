import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/watch.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/day_key.dart';

/// Validation limits shared by the UI and the repository.
abstract final class SkillLimits {
  static const nameMax = 40;
  static const descriptionMax = 200;
  static const noteMax = 500;
  static const minTargetHours = 1.0;
  static const maxTargetHours = 100000.0;
  static const maxSessionSec = 24 * 3600;
}

class SkillDraft {
  const SkillDraft({
    required this.name,
    required this.iconKey,
    required this.colorValue,
    this.description,
    this.targetHours = 10000,
    this.reminderEnabled = false,
    this.reminderMinutes = 19 * 60,
  });

  final String name;
  final String? description;
  final String iconKey;
  final int colorValue;
  final double targetHours;
  final bool reminderEnabled;
  final int reminderMinutes;
}

class ValidationException implements Exception {
  const ValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SkillRepository {
  SkillRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  // ---------------------------------------------------------------- skills

  Stream<List<SkillRow>> watchSkills({bool archived = false}) {
    final q = _db.select(_db.skills)
      ..where(
        (s) => archived ? s.archivedAt.isNotNull() : s.archivedAt.isNull(),
      )
      ..orderBy([
        (s) => OrderingTerm.asc(s.sortOrder),
        (s) => OrderingTerm.asc(s.id),
      ]);
    return q.watch();
  }

  Future<List<SkillRow>> allSkills() => (_db.select(_db.skills)
        ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
      .get();

  Stream<SkillRow?> watchSkill(int id) =>
      (_db.select(_db.skills)..where((s) => s.id.equals(id)))
          .watchSingleOrNull();

  Future<SkillRow?> getSkill(int id) =>
      (_db.select(_db.skills)..where((s) => s.id.equals(id))).getSingleOrNull();

  SkillsCompanion _companion(SkillDraft d) {
    final name = d.name.trim();
    if (name.isEmpty) throw const ValidationException('Give your skill a name.');
    if (name.length > SkillLimits.nameMax) {
      throw const ValidationException('That name is a little long.');
    }
    final desc = d.description?.trim();
    if (desc != null && desc.length > SkillLimits.descriptionMax) {
      throw const ValidationException('Description is too long.');
    }
    if (d.targetHours < SkillLimits.minTargetHours ||
        d.targetHours > SkillLimits.maxTargetHours) {
      throw const ValidationException('Target must be 1 – 100,000 hours.');
    }
    return SkillsCompanion(
      name: Value(name),
      description: Value(desc == null || desc.isEmpty ? null : desc),
      iconKey: Value(d.iconKey),
      colorValue: Value(d.colorValue),
      targetHours: Value(d.targetHours),
      reminderEnabled: Value(d.reminderEnabled),
      reminderMinutes: Value(d.reminderMinutes.clamp(0, 24 * 60 - 1)),
    );
  }

  Future<int> createSkill(SkillDraft draft) async {
    final companion = _companion(draft);
    final maxOrder = _db.skills.sortOrder.max();
    final row = await (_db.selectOnly(_db.skills)..addColumns([maxOrder]))
        .getSingle();
    final next = (row.read(maxOrder) ?? -1) + 1;
    return _db.into(_db.skills).insert(
          companion.copyWith(
            sortOrder: Value(next),
            createdAt: Value(_clock.now()),
          ),
        );
  }

  Future<void> updateSkill(int id, SkillDraft draft) async {
    final updated = await (_db.update(_db.skills)
          ..where((s) => s.id.equals(id)))
        .write(_companion(draft));
    if (updated == 0) throw const ValidationException('Skill not found.');
  }

  Future<void> setReminder(int id, {required bool enabled, int? minutes}) =>
      (_db.update(_db.skills)..where((s) => s.id.equals(id))).write(
        SkillsCompanion(
          reminderEnabled: Value(enabled),
          reminderMinutes:
              minutes == null ? const Value.absent() : Value(minutes),
        ),
      );

  Future<void> setArchived(int id, {required bool archived}) async {
    await _db.transaction(() async {
      await (_db.update(_db.skills)..where((s) => s.id.equals(id))).write(
        SkillsCompanion(
          archivedAt: Value(archived ? _clock.now() : null),
          // Archived skills don't nag.
          reminderEnabled:
              archived ? const Value(false) : const Value.absent(),
        ),
      );
      if (archived) {
        await (_db.delete(_db.activeTimers)
              ..where((t) => t.skillId.equals(id)))
            .go();
      }
    });
  }

  /// Deletes the skill, its sessions, milestones and a running timer.
  /// Journal entries linked to it are kept (the link is cleared).
  Future<void> deleteSkill(int id) =>
      (_db.delete(_db.skills)..where((s) => s.id.equals(id))).go();

  Future<void> reorder(List<int> orderedIds) => _db.transaction(() async {
        for (var i = 0; i < orderedIds.length; i++) {
          await (_db.update(_db.skills)
                ..where((s) => s.id.equals(orderedIds[i])))
              .write(SkillsCompanion(sortOrder: Value(i)));
        }
      });

  // -------------------------------------------------------------- sessions

  Stream<List<SessionRow>> watchSessions({int? skillId, int? limit}) {
    final q = _db.select(_db.practiceSessions)
      ..orderBy([
        (s) => OrderingTerm.desc(s.dayKey),
        (s) => OrderingTerm.desc(s.startedAt),
        (s) => OrderingTerm.desc(s.id),
      ]);
    if (skillId != null) q.where((s) => s.skillId.equals(skillId));
    if (limit != null) q.limit(limit);
    return q.watch();
  }

  Future<SessionRow?> getSession(int id) =>
      (_db.select(_db.practiceSessions)..where((s) => s.id.equals(id)))
          .getSingleOrNull();

  void _checkSession(int durationSec, String? note, DayKey dayKey) {
    if (durationSec < 60) {
      throw const ValidationException('Sessions need to be at least 1 minute.');
    }
    if (durationSec > SkillLimits.maxSessionSec) {
      throw const ValidationException('A session can be at most 24 hours.');
    }
    if (note != null && note.trim().length > SkillLimits.noteMax) {
      throw const ValidationException('Note is too long.');
    }
    if (dayKey > _clock.today()) {
      throw const ValidationException("You can't log practice in the future.");
    }
  }

  String? _cleanNote(String? note) {
    final n = note?.trim();
    return n == null || n.isEmpty ? null : n;
  }

  Future<int> addSession({
    required int skillId,
    required DayKey dayKey,
    required int durationSec,
    DateTime? startedAt,
    String? note,
    String source = 'manual',
  }) {
    _checkSession(durationSec, note, dayKey);
    final now = _clock.now();
    final date = Days.dateOf(dayKey);
    final start = startedAt ??
        (dayKey == Days.keyOf(now)
            ? now.subtract(Duration(seconds: durationSec))
            : DateTime(date.year, date.month, date.day, 12));
    return _db.into(_db.practiceSessions).insert(
          PracticeSessionsCompanion.insert(
            skillId: skillId,
            startedAt: start,
            dayKey: dayKey,
            durationSec: durationSec,
            note: Value(_cleanNote(note)),
            source: Value(source),
            createdAt: now,
          ),
        );
  }

  Future<void> updateSession(
    int id, {
    required int skillId,
    required DayKey dayKey,
    required int durationSec,
    String? note,
  }) async {
    _checkSession(durationSec, note, dayKey);
    final existing = await getSession(id);
    if (existing == null) throw const ValidationException('Session not found.');
    var start = existing.startedAt;
    if (existing.dayKey != dayKey) {
      final d = Days.dateOf(dayKey);
      start = DateTime(d.year, d.month, d.day, start.hour, start.minute);
    }
    await (_db.update(_db.practiceSessions)..where((s) => s.id.equals(id)))
        .write(
      PracticeSessionsCompanion(
        skillId: Value(skillId),
        dayKey: Value(dayKey),
        startedAt: Value(start),
        durationSec: Value(durationSec),
        note: Value(_cleanNote(note)),
      ),
    );
  }

  Future<void> deleteSession(int id) =>
      (_db.delete(_db.practiceSessions)..where((s) => s.id.equals(id))).go();

  /// Re-inserts a previously deleted session (for "Undo").
  Future<void> restoreSession(SessionRow row) =>
      _db.into(_db.practiceSessions).insert(row, mode: InsertMode.insertOrReplace);

  Future<int> sessionCount(int skillId) async {
    final count = _db.practiceSessions.id.count();
    final row = await (_db.selectOnly(_db.practiceSessions)
          ..addColumns([count])
          ..where(_db.practiceSessions.skillId.equals(skillId)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  // ------------------------------------------------------------ aggregates

  Future<int> totalSeconds(int skillId) async {
    final sum = _db.practiceSessions.durationSec.sum();
    final row = await (_db.selectOnly(_db.practiceSessions)
          ..addColumns([sum])
          ..where(_db.practiceSessions.skillId.equals(skillId)))
        .getSingle();
    return row.read(sum) ?? 0;
  }

  /// skillId → total seconds across all time.
  Future<Map<int, int>> totalsBySkill({DayKey? from, DayKey? to}) async {
    final t = _db.practiceSessions;
    final sum = t.durationSec.sum();
    final q = _db.selectOnly(t)
      ..addColumns([t.skillId, sum])
      ..groupBy([t.skillId]);
    if (from != null) q.where(t.dayKey.isBiggerOrEqualValue(from));
    if (to != null) q.where(t.dayKey.isSmallerOrEqualValue(to));
    final rows = await q.get();
    return {for (final r in rows) r.read(t.skillId)!: r.read(sum) ?? 0};
  }

  /// dayKey → seconds, optionally for one skill and a day range.
  Future<Map<DayKey, int>> dailySeconds({
    int? skillId,
    DayKey? from,
    DayKey? to,
  }) async {
    final t = _db.practiceSessions;
    final sum = t.durationSec.sum();
    final q = _db.selectOnly(t)
      ..addColumns([t.dayKey, sum])
      ..groupBy([t.dayKey]);
    if (skillId != null) q.where(t.skillId.equals(skillId));
    if (from != null) q.where(t.dayKey.isBiggerOrEqualValue(from));
    if (to != null) q.where(t.dayKey.isSmallerOrEqualValue(to));
    final rows = await q.get();
    return {for (final r in rows) r.read(t.dayKey)!: r.read(sum) ?? 0};
  }

  /// Distinct days with practice, optionally per skill.
  Future<Set<DayKey>> practiceDays({int? skillId}) async {
    final t = _db.practiceSessions;
    final q = _db.selectOnly(t, distinct: true)..addColumns([t.dayKey]);
    if (skillId != null) q.where(t.skillId.equals(skillId));
    final rows = await q.get();
    return {for (final r in rows) r.read(t.dayKey)!};
  }

  /// skillId → set of practice days (for per-skill streaks in one query).
  Future<Map<int, Set<DayKey>>> practiceDaysBySkill() async {
    final t = _db.practiceSessions;
    final q = _db.selectOnly(t, distinct: true)
      ..addColumns([t.skillId, t.dayKey]);
    final result = <int, Set<DayKey>>{};
    for (final r in await q.get()) {
      result.putIfAbsent(r.read(t.skillId)!, () => {}).add(r.read(t.dayKey)!);
    }
    return result;
  }

  Future<List<SessionRow>> sessionsBetween(DayKey from, DayKey to) =>
      (_db.select(_db.practiceSessions)
            ..where((s) => s.dayKey.isBetweenValues(from, to)))
          .get();

  Stream<T> watch<T>(Future<T> Function() load) => _db.watchTables(
        [_db.skills, _db.practiceSessions, _db.milestones],
        load,
      );
}
