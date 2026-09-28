import 'package:bible_app/data/sync/remote_store.dart';

/// In-memory server with the same rules as the Supabase schema:
/// rows keyed by (user_id, id), last-write-wins on `updated_at`, and a
/// server change sequence that pull pages through.
class FakeRemote implements RemoteStore {
  final _tables = <String, Map<String, Map<String, Object?>>>{};
  var _seq = 0;

  /// Set to make the next upsert fail.
  Object? failNextUpsert;

  /// Called during upsert, before rows are applied (to simulate concurrent
  /// local edits).
  void Function(String table)? onUpsert;

  int upsertCalls = 0;

  Map<String, Map<String, Object?>> table(String name) =>
      _tables.putIfAbsent(name, () => {});

  @override
  Future<void> upsert(String table, List<Map<String, Object?>> rows) async {
    upsertCalls++;
    onUpsert?.call(table);
    final err = failNextUpsert;
    if (err != null) {
      failNextUpsert = null;
      throw err;
    }
    final t = this.table(table);
    for (final r in rows) {
      final key = '${r['user_id']}/${r['id']}';
      final existing = t[key];
      if (existing != null &&
          (r['updated_at'] as int) < (existing['updated_at'] as int)) {
        continue; // older write loses
      }
      t[key] = {...r, 'server_updated_at': ++_seq};
    }
  }

  @override
  Future<RemotePage> fetchChanges(
    String table, {
    required String? cursor,
    int limit = 500,
    bool rewind = false,
  }) async {
    // Rewind re-sends a few recent changes, like the real store.
    final after = cursor == null ? 0 : int.parse(cursor) - (rewind ? 3 : 0);
    final rows =
        this
            .table(table)
            .values
            .where((r) => (r['server_updated_at'] as int) > after)
            .toList()
          ..sort(
            (a, b) => (a['server_updated_at'] as int).compareTo(
              b['server_updated_at'] as int,
            ),
          );
    final page = rows.take(limit).toList();
    return RemotePage(
      page,
      page.isEmpty ? cursor : '${page.last['server_updated_at']}',
      hasMore: rows.length > limit,
    );
  }
}
