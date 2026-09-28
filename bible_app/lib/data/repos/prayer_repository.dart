import 'package:drift/drift.dart';

import '../db/database.dart';
import '../sync/sync_writer.dart';

enum PrayerCategory {
  personal('Personal'),
  family('Family'),
  friends('Friends'),
  work('Work'),
  school('School'),
  relationships('Relationships'),
  gratitude('Gratitude'),
  other('Other');

  const PrayerCategory(this.label);
  final String label;

  static PrayerCategory fromName(String n) => PrayerCategory.values.firstWhere(
    (c) => c.name == n,
    orElse: () => PrayerCategory.other,
  );
}

enum ReminderKind {
  none,
  once,
  daily;

  static ReminderKind fromName(String n) =>
      ReminderKind.values.firstWhere((k) => k.name == n, orElse: () => none);
}

/// Fields for creating or editing a prayer.
class PrayerDraft {
  const PrayerDraft({
    required this.title,
    this.body = '',
    this.category = PrayerCategory.personal,
    this.scriptureRef,
    this.reminderKind = ReminderKind.none,
    this.reminderValue,
  });

  final String title;
  final String body;
  final PrayerCategory category;
  final String? scriptureRef;
  final ReminderKind reminderKind;

  /// once: UTC ms; daily: minutes after local midnight.
  final int? reminderValue;
}

class PrayerRepository {
  PrayerRepository(this._w);

  final SyncWriter _w;
  AppDatabase get _db => _w.db;

  Stream<List<Prayer>> watchAll() =>
      (_db.select(_db.prayers)
            ..where((p) => p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
          .watch();

  Stream<Prayer?> watch(String id) => (_db.select(
    _db.prayers,
  )..where((p) => p.id.equals(id) & p.deletedAt.isNull())).watchSingleOrNull();

  Future<List<Prayer>> withReminders() =>
      (_db.select(_db.prayers)..where(
            (p) =>
                p.deletedAt.isNull() &
                p.status.equals('active') &
                p.reminderKind.isNotValue('none'),
          ))
          .get();

  Future<String> save(PrayerDraft d, {String? id}) async {
    final pid = id ?? _w.newId();
    await _w.write('prayers', pid, (t) async {
      final fields = PrayersCompanion(
        title: Value(d.title.trim()),
        body: Value(d.body.trim()),
        category: Value(d.category.name),
        scriptureRef: Value(d.scriptureRef),
        reminderKind: Value(d.reminderKind.name),
        reminderValue: Value(
          d.reminderKind == ReminderKind.none ? null : d.reminderValue,
        ),
        updatedAt: Value(t),
      );
      if (id == null) {
        await _db
            .into(_db.prayers)
            .insert(
              fields.copyWith(
                id: Value(pid),
                userId: Value(_w.userId),
                createdAt: Value(t),
              ),
            );
      } else {
        await (_db.update(
          _db.prayers,
        )..where((p) => p.id.equals(id))).write(fields);
      }
    });
    return pid;
  }

  Future<void> markAnswered(String id, {String? note}) => _w.write(
    'prayers',
    id,
    (t) => (_db.update(_db.prayers)..where((p) => p.id.equals(id))).write(
      PrayersCompanion(
        status: const Value('answered'),
        answeredAt: Value(t),
        answerNote: Value(note?.trim().isEmpty ?? true ? null : note!.trim()),
        updatedAt: Value(t),
      ),
    ),
  );

  Future<void> reopen(String id) => _w.write(
    'prayers',
    id,
    (t) => (_db.update(_db.prayers)..where((p) => p.id.equals(id))).write(
      PrayersCompanion(
        status: const Value('active'),
        answeredAt: const Value(null),
        answerNote: const Value(null),
        updatedAt: Value(t),
      ),
    ),
  );

  Future<void> delete(String id) => _w.softDelete('prayers', id);
}
