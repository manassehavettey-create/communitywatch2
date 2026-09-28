import 'dart:async';

import 'package:drift/drift.dart';

import '../local/database.dart';
import 'remote_store.dart';

enum SyncPhase { idle, offline, syncing, synced, error, localOnly }

class SyncStatus {
  const SyncStatus(this.phase, {this.pending = 0, this.lastSynced, this.message});
  final SyncPhase phase;
  final int pending;
  final DateTime? lastSynced;
  final String? message;

  SyncStatus copyWith({SyncPhase? phase, int? pending, DateTime? lastSynced, String? message}) => SyncStatus(
        phase ?? this.phase,
        pending: pending ?? this.pending,
        lastSynced: lastSynced ?? this.lastSynced,
        message: message,
      );
}

class SyncReport {
  const SyncReport({this.pushed = 0, this.pulled = 0, this.keptLocal = 0, this.failed = 0});
  final int pushed;
  final int pulled;

  /// Remote rows ignored because the local copy was newer (last-write-wins).
  final int keptLocal;
  final int failed;
}

/// Tables where rows are append-only logs. Merging them is a union by id: a
/// remote copy never overwrites a local row, it only fills in rows we don't
/// have. (Deletion is always an explicit tombstone.)
const kAppendOnlyTables = {'workouts', 'workout_sets', 'personal_records', 'milestones', 'user_achievements'};

/// Offline-first sync: the local database is the working copy; an outbox of
/// changed rows is pushed when online, then remote changes are pulled with a
/// per-table cursor on the server's `synced_at` stamp.
///
/// Conflicts
/// - Mutable rows: last write wins on `updated_at` (a newer local row is
///   kept and re-pushed; a newer remote row replaces the local one).
/// - Workout logs & other append-only rows: safe union by id.
/// - Achievements: the earliest unlock time is kept.
class SyncEngine {
  SyncEngine(this.db, this.remote, {this.batchSize = 200});

  final AppDatabase db;
  final RemoteStore remote;
  final int batchSize;

  bool _running = false;

  /// Push then pull. Safe to call repeatedly; concurrent calls are coalesced.
  Future<SyncReport> sync(String userId) async {
    if (_running) return const SyncReport();
    _running = true;
    try {
      final pushed = await _push(userId);
      final (pulled, kept) = await _pull(userId);
      return SyncReport(pushed: pushed, pulled: pulled, keptLocal: kept);
    } finally {
      _running = false;
    }
  }

  Future<int> _push(String userId) async {
    var total = 0;
    final order = {for (var i = 0; i < db.syncedTables.length; i++) db.syncedTables[i].actualTableName: i};
    while (true) {
      final entries = await (db.select(db.syncOutbox)
            ..orderBy([(o) => OrderingTerm.asc(o.seq)])
            ..limit(batchSize))
          .get();
      if (entries.isEmpty) break;

      final byTable = <String, List<OutboxRow>>{};
      for (final e in entries) {
        byTable.putIfAbsent(e.tableName_, () => []).add(e);
      }
      final tables = byTable.keys.toList()..sort((a, b) => (order[a] ?? 99).compareTo(order[b] ?? 99));

      for (final table in tables) {
        final list = byTable[table]!;
        final rows = <Map<String, Object?>>[];
        final sent = <OutboxRow>[];
        for (final e in list) {
          final row = await db.readRemoteShape(table, e.rowId);
          if (row == null || row['user_id'] != userId) {
            // Row vanished or belongs to someone else (e.g. after sign-out): drop the entry.
            await (db.delete(db.syncOutbox)..where((o) => o.seq.equals(e.seq))).go();
            continue;
          }
          rows.add(row);
          sent.add(e);
        }
        if (rows.isEmpty) continue;
        try {
          await remote.upsert(table, rows);
        } on RemoteUnavailable {
          rethrow;
        } catch (err) {
          for (final e in sent) {
            await (db.update(db.syncOutbox)..where((o) => o.seq.equals(e.seq))).write(
              SyncOutboxCompanion(attempts: Value(e.attempts + 1), lastError: Value(err.toString())),
            );
          }
          rethrow;
        }
        // Only remove entries that weren't re-queued while we were pushing.
        for (final e in sent) {
          await (db.delete(db.syncOutbox)
                ..where((o) => o.seq.equals(e.seq) & o.queuedAt.equals(e.queuedAt)))
              .go();
        }
        total += rows.length;
      }
      if (entries.length < batchSize) break;
    }
    return total;
  }

  Future<(int, int)> _pull(String userId) async {
    var pulled = 0;
    var kept = 0;
    for (final table in db.syncedTables) {
      final name = table.actualTableName;
      final cursorRow =
          await (db.select(db.syncCursors)..where((c) => c.tableName_.equals(name))).getSingleOrNull();
      var cursor = cursorRow?.lastPulledAt;
      while (true) {
        final rows = await remote.pullSince(name, userId, cursor, limit: batchSize);
        if (rows.isEmpty) break;
        await db.transaction(() async {
          for (final r in rows) {
            final applied = await _merge(table, name, r);
            if (applied) {
              pulled++;
            } else {
              kept++;
            }
            final stamp = DateTime.parse(r['synced_at']! as String).toUtc();
            if (cursor == null || stamp.isAfter(cursor!)) cursor = stamp;
          }
          await db.into(db.syncCursors).insertOnConflictUpdate(
                SyncCursorsCompanion.insert(tableName_: name, lastPulledAt: Value(cursor)),
              );
        });
        if (rows.length < batchSize) break;
      }
    }
    return (pulled, kept);
  }

  /// Returns true if the remote row was applied locally.
  Future<bool> _merge(TableInfo<Table, Object?> table, String name, Map<String, Object?> remoteRow) async {
    final id = remoteRow['id']! as String;
    final localUpdated = await db.localUpdatedAt(name, id);

    if (localUpdated != null) {
      if (kAppendOnlyTables.contains(name)) {
        if (name == 'user_achievements') return _mergeAchievement(table, remoteRow);
        // Union: keep the local log. A remote tombstone still applies.
        if (remoteRow['deleted_at'] == null) return false;
      }
      final remoteUpdated = DateTime.parse(remoteRow['updated_at']! as String);
      if (localUpdated.isAfter(remoteUpdated)) {
        // Local is newer: keep it and make sure it gets pushed.
        await db.enqueue(name, id);
        return false;
      }
      if (localUpdated.isAtSameMomentAs(remoteUpdated)) return false;
    }
    final row = await db.fromRemote(table, remoteRow);
    await db.into(table).insertOnConflictUpdate(row as Insertable<Object?>);
    // A remote write supersedes any stale local queue entry for this row.
    if (localUpdated != null) {
      await (db.delete(db.syncOutbox)..where((o) => o.tableName_.equals(name) & o.rowId.equals(id))).go();
    }
    return true;
  }

  Future<bool> _mergeAchievement(TableInfo<Table, Object?> table, Map<String, Object?> remoteRow) async {
    final id = remoteRow['id']! as String;
    final local = await (db.select(db.userAchievements)..where((a) => a.id.equals(id))).getSingleOrNull();
    if (local == null) return false;
    final remoteAt = DateTime.parse(remoteRow['unlocked_at']! as String);
    if (remoteAt.isBefore(local.unlockedAt)) {
      final row = await db.fromRemote(table, remoteRow);
      await db.into(table).insertOnConflictUpdate(row as Insertable<Object?>);
      return true;
    }
    return false;
  }
}
