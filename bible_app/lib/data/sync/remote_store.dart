/// One page of remote changes.
class RemotePage {
  const RemotePage(this.rows, this.cursor, {required this.hasMore});

  /// Rows in remote (snake_case) form.
  final List<Map<String, Object?>> rows;

  /// Opaque position after the last row, passed to the next fetch.
  final String? cursor;
  final bool hasMore;
}

/// The server side of sync. Every table is keyed by (user_id, id).
///
/// Implementations must:
///  * apply an upserted row only if its `updated_at` is not older than the
///    stored row's (last write wins; the Supabase trigger enforces this), and
///  * stamp every applied write with a server-side change time, which
///    [fetchChanges] pages through in order.
abstract class RemoteStore {
  Future<void> upsert(String table, List<Map<String, Object?>> rows);

  /// Changes after [cursor]. With [rewind], the store also re-sends the
  /// last minute before the cursor, covering writes that committed late
  /// with an earlier server time. Re-applying a row is harmless.
  Future<RemotePage> fetchChanges(
    String table, {
    required String? cursor,
    int limit = 500,
    bool rewind = false,
  });
}

class SyncException implements Exception {
  SyncException(this.message);
  final String message;

  @override
  String toString() => message;
}
