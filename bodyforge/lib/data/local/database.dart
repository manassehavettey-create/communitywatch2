import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Profiles,
  Goals,
  Programs,
  ProgramDays,
  Workouts,
  WorkoutSets,
  PersonalRecords,
  Measurements,
  SkillProgress,
  RecoveryChecks,
  ChallengeProgress,
  ChallengeCheckins,
  UserAchievements,
  JourneyProgress,
  Milestones,
  FoodPrices,
  SyncOutbox,
  SyncCursors,
  ActiveSessions,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// On-device database (SQLite file in the app documents folder).
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'bodyforge'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('CREATE INDEX IF NOT EXISTS idx_workouts_user_date ON workouts(user_id, date)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_sets_workout ON workout_sets(workout_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_records_user_ex ON personal_records(user_id, exercise_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_measure_user_type ON measurements(user_id, type)');
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Every table that is mirrored to Supabase, in dependency order
  /// (parents before children) for pushing.
  List<TableInfo<Table, Object?>> get syncedTables => [
        profiles,
        goals,
        programs,
        programDays,
        workouts,
        workoutSets,
        personalRecords,
        measurements,
        skillProgress,
        recoveryChecks,
        challengeProgress,
        challengeCheckins,
        userAchievements,
        journeyProgress,
        milestones,
        foodPrices,
      ];

  TableInfo<Table, Object?>? syncedTable(String name) {
    for (final t in syncedTables) {
      if (t.actualTableName == name) return t;
    }
    return null;
  }

  // ───────────────────────── outbox ─────────────────────────

  /// Queue a row for pushing. Re-queuing the same row keeps one entry.
  Future<void> enqueue(String table, String rowId, {DateTime? at}) async {
    await into(syncOutbox).insert(
      SyncOutboxCompanion.insert(tableName_: table, rowId: rowId, queuedAt: (at ?? DateTime.now()).toUtc()),
      onConflict: DoUpdate(
        (old) => SyncOutboxCompanion(queuedAt: Value((at ?? DateTime.now()).toUtc()), attempts: const Value(0)),
        target: [syncOutbox.tableName_, syncOutbox.rowId],
      ),
    );
  }

  /// Insert-or-replace a synced row and queue it, in one transaction.
  Future<void> write<T extends Table, D>(TableInfo<T, D> table, Insertable<D> row, String id) {
    return transaction(() async {
      await into(table).insertOnConflictUpdate(row);
      await enqueue(table.actualTableName, id);
    });
  }

  Future<int> pendingChanges() async {
    final c = countAll();
    final q = selectOnly(syncOutbox)..addColumns([c]);
    return (await q.getSingle()).read(c) ?? 0;
  }

  Stream<int> watchPendingChanges() {
    final c = countAll();
    final q = selectOnly(syncOutbox)..addColumns([c]);
    return q.watchSingle().map((r) => r.read(c) ?? 0);
  }

  // ───────────────────────── remote mapping ─────────────────────────

  /// Converts a local row to the JSON shape stored in Supabase.
  Map<String, Object?> toRemote(Insertable<Object?> row) {
    final cols = row.toColumns(false);
    return cols.map((key, expr) {
      Object? v;
      if (expr is Variable) {
        v = expr.value;
      } else if (expr is Constant) {
        v = expr.value;
      }
      if (v is DateTime) v = v.toUtc().toIso8601String();
      return MapEntry(key, v);
    });
  }

  /// Converts Supabase JSON to a local data row for [table].
  Future<D> fromRemote<D>(TableInfo<Table, D> table, Map<String, Object?> json) async {
    final data = <String, Object?>{};
    for (final col in table.$columns) {
      final name = col.name;
      var v = json[name];
      if (v is Map || v is List) v = jsonEncode(v);
      data[name] = v;
    }
    return await table.map(data);
  }

  Future<Map<String, Object?>?> readRemoteShape(String tableName, String id) async {
    final table = syncedTable(tableName);
    if (table == null) return null;
    final idCol = table.$columns.firstWhere((c) => c.name == 'id') as GeneratedColumn<String>;
    final row = await (select(table)..where((_) => idCol.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return toRemote(row as Insertable<Object?>);
  }

  /// Local `updated_at` for a row, if it exists.
  Future<DateTime?> localUpdatedAt(String tableName, String id) async {
    final r = await customSelect('SELECT updated_at FROM "$tableName" WHERE id = ?', variables: [Variable(id)])
        .getSingleOrNull();
    if (r == null) return null;
    final raw = r.data['updated_at'];
    return raw == null ? null : DateTime.parse(raw.toString());
  }

  // ───────────────────────── account housekeeping ─────────────────────────

  /// Move every row from a local-only user to [newUserId] (after sign-up) and
  /// queue everything for upload.
  Future<void> rekeyUser(String oldUserId, String newUserId) async {
    if (oldUserId == newUserId) return;
    await transaction(() async {
      for (final t in syncedTables) {
        final name = t.actualTableName;
        await customStatement('UPDATE "$name" SET user_id = ? WHERE user_id = ?', [newUserId, oldUserId]);
      }
      await customStatement('UPDATE profiles SET id = ? WHERE id = ?', [newUserId, oldUserId]);
      await customStatement('UPDATE journey_progress SET id = ? WHERE id = ?', [newUserId, oldUserId]);
      // Composite ids that embed the user id.
      for (final name in ['skill_progress', 'user_achievements', 'food_prices']) {
        await customStatement(
            'UPDATE "$name" SET id = ? || substr(id, ?) WHERE id LIKE ?', [newUserId, oldUserId.length + 1, '$oldUserId:%']);
      }
      await customStatement('UPDATE active_sessions SET user_id = ? WHERE user_id = ?', [newUserId, oldUserId]);
      await enqueueEverything(newUserId);
    });
  }

  Future<void> enqueueEverything(String userId) async {
    for (final t in syncedTables) {
      final name = t.actualTableName;
      final rows = await customSelect('SELECT id FROM "$name" WHERE user_id = ?', variables: [Variable(userId)]).get();
      for (final r in rows) {
        await enqueue(name, r.data['id'] as String);
      }
    }
  }

  /// Remove all local data (sign-out / account deletion).
  Future<void> wipe() async {
    await transaction(() async {
      for (final t in [...syncedTables, syncOutbox, syncCursors, activeSessions]) {
        await delete(t).go();
      }
    });
  }
}

/// Re-runs [load] initially and whenever any of [tables] changes.
Stream<T> watchTables<T>(AppDatabase db, Set<ResultSetImplementation<dynamic, dynamic>> tables, Future<T> Function() load) =>
    db.customSelect('SELECT 1', readsFrom: tables).watch().asyncMap((_) => load());
