import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import 'sync_engine.dart';

/// The only way repositories write user data. Every write stamps
/// `updated_at` and the current user, and queues the row for upload in the
/// same transaction, whether or not anyone is signed in (rows written while
/// signed out are claimed on sign-in).
class SyncWriter {
  SyncWriter(this.db, this._userId, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final String? Function() _userId;
  final DateTime Function() _clock;

  static const _uuid = Uuid();

  String newId() => _uuid.v4();

  int now() => _clock().toUtc().millisecondsSinceEpoch;

  String? get userId => _userId();

  /// Runs [apply] (which should insert or update row [id] in [table] using
  /// the provided timestamp) and queues the row for sync.
  Future<void> write(
    String table,
    String id,
    Future<void> Function(int now) apply,
  ) {
    return db.transaction(() async {
      final t = now();
      await apply(t);
      await LocalWriter.enqueue(db, table, id, t);
    });
  }

  /// Marks a row deleted (a tombstone that syncs).
  Future<void> softDelete(String table, String id) => write(
    table,
    id,
    (t) => db.customUpdate(
      'UPDATE "$table" SET deleted_at = ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable.withInt(t),
        Variable.withInt(t),
        Variable.withString(id),
      ],
      updates: {db.syncTable(table)},
      updateKind: UpdateKind.update,
    ),
  );

  /// On sign-in: gives every row written while signed out to [userId] and
  /// queues all of them for upload.
  Future<int> claimLocalRows(String userId) async {
    var claimed = 0;
    await db.transaction(() async {
      final t = now();
      for (final table in syncedTables) {
        final rows = await db
            .customSelect(
              'SELECT id FROM "$table" WHERE user_id IS NULL OR user_id != ?',
              variables: [Variable.withString(userId)],
            )
            .get();
        if (rows.isEmpty) continue;
        await db.customUpdate(
          'UPDATE "$table" SET user_id = ? WHERE user_id IS NULL OR user_id != ?',
          variables: [Variable.withString(userId), Variable.withString(userId)],
          updates: {db.syncTable(table)},
          updateKind: UpdateKind.update,
        );
        for (final r in rows) {
          await LocalWriter.enqueue(db, table, r.read<String>('id'), t);
        }
        claimed += rows.length;
      }
    });
    return claimed;
  }

  /// On sign-out: removes the account's data from this device.
  Future<void> wipeUserData() async {
    await db.transaction(() async {
      for (final table in syncedTables) {
        await db.customStatement('DELETE FROM "$table"');
      }
      await db.customStatement('DELETE FROM outbox');
      await db.customStatement(
        "DELETE FROM key_values WHERE key LIKE 'sync.%'",
      );
    });
    db.notifyUpdates({
      for (final t in syncedTables)
        TableUpdate.onTable(db.syncTable(t), kind: UpdateKind.delete),
    });
  }
}
