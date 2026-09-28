import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import 'remote_store.dart';

/// Counts from one sync pass.
class SyncReport {
  SyncReport({this.pushed = 0, this.pulled = 0, this.conflictCopies = 0});

  int pushed;
  int pulled;
  int conflictCopies;

  @override
  String toString() =>
      'pushed $pushed, pulled $pulled, conflict copies $conflictCopies';
}

/// Tables whose rows hold the user's own writing. When the same row was
/// edited on two devices, the losing local edit is kept as a copy rather
/// than overwritten.
const conflictCopyTables = {
  'notes': 'body',
  'journal_entries': 'title',
  'prayers': 'title',
};

/// Pushes the local outbox and pulls remote changes.
///
/// Local writes go through [LocalWriter], which stamps `updated_at` and
/// records the entity in the outbox in the same transaction. Sync never
/// touches rows it hasn't been told about, and pulling never adds to the
/// outbox (except for conflict copies, which are new local rows).
class SyncEngine {
  SyncEngine(
    this.db,
    this.remote, {
    required this.userId,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final AppDatabase db;
  final RemoteStore remote;
  final String userId;
  final DateTime Function() _now;

  static const _cursorPrefix = 'sync.cursor.';
  static const pushBatch = 200;

  /// Pulls first so conflicts are detected while local edits are still
  /// marked pending; pushing first would let the server silently reject an
  /// older local edit and the following pull would overwrite it.
  Future<SyncReport> sync() async {
    final report = SyncReport();
    await pull(report);
    await push(report);
    return report;
  }

  // ------------------------------------------------------------------ push

  Future<void> push(SyncReport report) async {
    final pending = await (db.select(
      db.outbox,
    )..orderBy([(o) => OrderingTerm(expression: o.seq)])).get();
    if (pending.isEmpty) return;

    final byTable = <String, List<OutboxData>>{};
    for (final e in pending) {
      byTable.putIfAbsent(e.entityTable, () => []).add(e);
    }
    for (final table in syncedTables) {
      final entries = byTable[table];
      if (entries == null) continue;
      for (var i = 0; i < entries.length; i += pushBatch) {
        final batch = entries.skip(i).take(pushBatch).toList();
        final rows = <Map<String, Object?>>[];
        for (final e in batch) {
          final row = await _readLocal(table, e.entityId);
          if (row != null) rows.add(_toRemote(table, row));
        }
        try {
          if (rows.isNotEmpty) await remote.upsert(table, rows);
        } catch (err) {
          await _markFailed(batch, err);
          throw SyncException('Could not upload $table: $err');
        }
        // Remove only entries that weren't re-queued while uploading.
        for (final e in batch) {
          await (db.delete(db.outbox)..where(
                (o) => o.seq.equals(e.seq) & o.enqueuedAt.equals(e.enqueuedAt),
              ))
              .go();
        }
        report.pushed += rows.length;
      }
    }
  }

  Future<void> _markFailed(List<OutboxData> batch, Object err) async {
    for (final e in batch) {
      await (db.update(db.outbox)..where((o) => o.seq.equals(e.seq))).write(
        OutboxCompanion(
          attempts: Value(e.attempts + 1),
          lastError: Value(err.toString()),
        ),
      );
    }
  }

  // ------------------------------------------------------------------ pull

  Future<void> pull(SyncReport report) async {
    for (final table in syncedTables) {
      var cursor = await db.getValue('$_cursorPrefix$table');
      var first = true;
      while (true) {
        final page = await remote.fetchChanges(
          table,
          cursor: cursor,
          rewind: first,
        );
        first = false;
        await db.transaction(() async {
          for (final row in page.rows) {
            await _merge(table, row, report);
          }
          if (page.cursor != null) {
            await db.setValue('$_cursorPrefix$table', page.cursor);
          }
        });
        report.pulled += page.rows.length;
        cursor = page.cursor ?? cursor;
        if (!page.hasMore || page.rows.isEmpty) break;
      }
    }
  }

  Future<void> _merge(
    String table,
    Map<String, Object?> remoteRow,
    SyncReport report,
  ) async {
    final id = remoteRow['id'] as String;
    final incoming = _fromRemote(table, remoteRow);
    final local = await _readLocal(table, id);
    if (local == null) {
      await _writeLocal(table, incoming);
      return;
    }
    final localUpdated = local['updated_at'] as int;
    final remoteUpdated = incoming['updated_at'] as int;
    final pending = await _isPending(table, id);

    if (!pending) {
      // Nothing unsent here: the newer version wins. Equal timestamps mean
      // this is our own write echoing back.
      if (remoteUpdated >= localUpdated) await _writeLocal(table, incoming);
      return;
    }
    if (remoteUpdated <= localUpdated) {
      // Our unsent edit is newer; it will overwrite the server on push.
      return;
    }
    // Both sides changed and the remote edit is newer.
    final field = conflictCopyTables[table];
    final bothLive =
        local['deleted_at'] == null && incoming['deleted_at'] == null;
    if (field != null && bothLive && !_sameContent(table, local, incoming)) {
      await _saveConflictCopy(table, local, field);
      report.conflictCopies++;
    }
    await _writeLocal(table, incoming);
    await (db.delete(
      db.outbox,
    )..where((o) => o.entityTable.equals(table) & o.entityId.equals(id))).go();
  }

  bool _sameContent(
    String table,
    Map<String, Object?> a,
    Map<String, Object?> b,
  ) {
    for (final c in _columns(table)) {
      if (const {'updated_at', 'created_at', 'user_id'}.contains(c)) continue;
      if (a[c] != b[c]) return false;
    }
    return true;
  }

  Future<void> _saveConflictCopy(
    String table,
    Map<String, Object?> local,
    String field,
  ) async {
    final now = _now().toUtc().millisecondsSinceEpoch;
    final copy = Map<String, Object?>.of(local)
      ..['id'] = const Uuid().v4()
      ..['created_at'] = now
      ..['updated_at'] = now
      ..[field] = table == 'notes'
          ? local[field]
          : '${local[field]} (conflict copy)';
    await _writeLocal(table, copy);
    await LocalWriter.enqueue(db, table, copy['id'] as String, now);
  }

  // --------------------------------------------------------------- helpers

  List<String> _columns(String table) => [
    for (final c in db.syncTable(table).$columns) c.name,
  ];

  Set<String> _boolColumns(String table) => {
    for (final c in db.syncTable(table).$columns)
      if (c.type == DriftSqlType.bool) c.name,
  };

  Future<bool> _isPending(String table, String id) async {
    final row =
        await (db.select(db.outbox)..where(
              (o) => o.entityTable.equals(table) & o.entityId.equals(id),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Future<Map<String, Object?>?> _readLocal(String table, String id) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM "$table" WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    return rows.isEmpty ? null : Map.of(rows.first.data);
  }

  Future<void> _writeLocal(String table, Map<String, Object?> row) async {
    final cols = _columns(table).where(row.containsKey).toList();
    final names = cols.map((c) => '"$c"').join(', ');
    final marks = List.filled(cols.length, '?').join(', ');
    final updates = cols
        .where((c) => c != 'id')
        .map((c) => '"$c" = excluded."$c"')
        .join(', ');
    await db.customInsert(
      'INSERT INTO "$table" ($names) VALUES ($marks) '
      'ON CONFLICT(id) DO UPDATE SET $updates',
      variables: [for (final c in cols) _variable(row[c])],
      updates: {db.syncTable(table)},
    );
  }

  Variable<Object> _variable(Object? v) => switch (v) {
    null => const Variable(null),
    final int i => Variable.withInt(i),
    final double d => Variable.withReal(d),
    final bool b => Variable.withBool(b),
    final String s => Variable.withString(s),
    _ => Variable.withString(v.toString()),
  };

  Map<String, Object?> _toRemote(String table, Map<String, Object?> local) {
    final bools = _boolColumns(table);
    return {
      for (final e in local.entries)
        e.key: bools.contains(e.key) && e.value is int
            ? (e.value as int) != 0
            : e.value,
      'user_id': userId,
    };
  }

  Map<String, Object?> _fromRemote(String table, Map<String, Object?> remote) {
    final cols = _columns(table).toSet();
    final bools = _boolColumns(table);
    final out = <String, Object?>{};
    for (final e in remote.entries) {
      if (!cols.contains(e.key)) continue; // e.g. server_updated_at
      var v = e.value;
      if (bools.contains(e.key) && v is bool) v = v ? 1 : 0;
      // JSON numbers for integer columns can arrive as doubles.
      if (v is double && v == v.truncateToDouble() && !_isReal(table, e.key)) {
        v = v.toInt();
      }
      out[e.key] = v;
    }
    return out;
  }

  bool _isReal(String table, String column) => db
      .syncTable(table)
      .$columns
      .any((c) => c.name == column && c.type == DriftSqlType.double);
}

/// Stamps and records local writes for sync.
abstract final class LocalWriter {
  static Future<void> enqueue(
    AppDatabase db,
    String table,
    String id,
    int now,
  ) => db.customInsert(
    'INSERT INTO outbox (entity_table, entity_id, enqueued_at) '
    'VALUES (?, ?, ?) ON CONFLICT(entity_table, entity_id) DO UPDATE SET '
    // Strictly increasing, so a push can tell a re-queued entry apart even
    // within the same millisecond.
    'enqueued_at = MAX(excluded.enqueued_at, outbox.enqueued_at + 1), '
    'attempts = 0, last_error = NULL',
    variables: [
      Variable.withString(table),
      Variable.withString(id),
      Variable.withInt(now),
    ],
    updates: {db.outbox},
  );
}
