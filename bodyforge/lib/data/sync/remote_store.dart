/// The server side of sync, abstracted so the sync engine can be tested
/// against an in-memory fake and run against Supabase in the app.
abstract class RemoteStore {
  /// Upsert rows (full row snapshots) into [table], keyed by `id`.
  Future<void> upsert(String table, List<Map<String, Object?>> rows);

  /// Rows of [table] for [userId] whose server `synced_at` is after [since]
  /// (all rows when null), oldest first. Each row includes `synced_at`.
  Future<List<Map<String, Object?>>> pullSince(String table, String userId, DateTime? since, {int limit = 500});
}

/// Thrown for connectivity problems — the queue keeps its entries and retries.
class RemoteUnavailable implements Exception {
  RemoteUnavailable(this.message);
  final String message;
  @override
  String toString() => 'RemoteUnavailable: $message';
}

/// In-memory remote used by tests and demo mode. Mimics the Supabase trigger
/// that stamps `synced_at` on every write.
class InMemoryRemoteStore implements RemoteStore {
  InMemoryRemoteStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, Map<String, Map<String, Object?>>> tables = {};
  bool online = true;
  int upsertCalls = 0;
  DateTime? _last;

  DateTime _stamp() {
    var t = _clock().toUtc();
    // Strictly increasing, like a DB sequence.
    if (_last != null && !t.isAfter(_last!)) t = _last!.add(const Duration(milliseconds: 1));
    _last = t;
    return t;
  }

  @override
  Future<void> upsert(String table, List<Map<String, Object?>> rows) async {
    if (!online) throw RemoteUnavailable('offline');
    upsertCalls++;
    final t = tables.putIfAbsent(table, () => {});
    for (final r in rows) {
      final id = r['id']! as String;
      final next = {...r, 'synced_at': _stamp().toIso8601String()};
      final existing = t[id];
      // Mirrors the `bf_last_write_wins` trigger: stale updates are ignored.
      if (existing != null &&
          DateTime.parse(r['updated_at']! as String).isBefore(DateTime.parse(existing['updated_at']! as String))) {
        continue;
      }
      // Mirrors the `keep_earliest_unlock` trigger in the Supabase migration.
      if (table == 'user_achievements' && existing != null) {
        final a = DateTime.parse(existing['unlocked_at']! as String);
        final b = DateTime.parse(r['unlocked_at']! as String);
        if (a.isBefore(b)) next['unlocked_at'] = existing['unlocked_at'];
      }
      t[id] = next;
    }
  }

  @override
  Future<List<Map<String, Object?>>> pullSince(String table, String userId, DateTime? since, {int limit = 500}) async {
    if (!online) throw RemoteUnavailable('offline');
    final rows = (tables[table]?.values ?? const <Map<String, Object?>>[])
        .where((r) => r['user_id'] == userId)
        .where((r) => since == null || DateTime.parse(r['synced_at']! as String).isAfter(since))
        .toList()
      ..sort((a, b) => (a['synced_at']! as String).compareTo(b['synced_at']! as String));
    return rows.take(limit).map((r) => {...r}).toList();
  }

  /// Simulate another device writing directly to the server.
  void writeFromOtherDevice(String table, Map<String, Object?> row) {
    tables.putIfAbsent(table, () => {})[row['id']! as String] = {...row, 'synced_at': _stamp().toIso8601String()};
  }
}
