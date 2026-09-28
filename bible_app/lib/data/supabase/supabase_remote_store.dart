import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../sync/remote_store.dart';

/// [RemoteStore] backed by Supabase tables (see supabase/migrations).
///
/// Every table is keyed by (user_id, id); row-level security limits each
/// user to their own rows; a trigger rejects writes older than the stored
/// row and stamps `server_updated_at`, which pulls page through.
class SupabaseRemoteStore implements RemoteStore {
  SupabaseRemoteStore(this.client);

  final SupabaseClient client;

  @override
  Future<void> upsert(String table, List<Map<String, Object?>> rows) async {
    try {
      await client.from(table).upsert(rows, onConflict: 'user_id,id');
    } on PostgrestException catch (e) {
      throw SyncException('${e.code ?? 'error'}: ${e.message}');
    }
  }

  @override
  Future<RemotePage> fetchChanges(
    String table, {
    required String? cursor,
    int limit = 500,
    bool rewind = false,
  }) async {
    var query = client.from(table).select();
    if (cursor != null && rewind) {
      final c = jsonDecode(cursor) as Map<String, dynamic>;
      final since = DateTime.parse(c['ts'] as String)
          .subtract(const Duration(minutes: 1));
      query = query.gte('server_updated_at', since.toUtc().toIso8601String());
    } else if (cursor != null) {
      // Keyset pagination on (server_updated_at, id), so rows sharing a
      // timestamp are never skipped.
      final c = jsonDecode(cursor) as Map<String, dynamic>;
      final ts = c['ts'] as String, id = c['id'] as String;
      query = query.or(
        'server_updated_at.gt."$ts",'
        'and(server_updated_at.eq."$ts",id.gt."$id")',
      );
    }
    try {
      final rows = await query
          .order('server_updated_at', ascending: true)
          .order('id', ascending: true)
          .limit(limit);
      final list = [for (final r in rows) Map<String, Object?>.from(r)];
      final next = list.isEmpty
          ? cursor
          : jsonEncode({
              'ts': list.last['server_updated_at'],
              'id': list.last['id'],
            });
      return RemotePage(list, next, hasMore: list.length == limit);
    } on PostgrestException catch (e) {
      throw SyncException('${e.code ?? 'error'}: ${e.message}');
    }
  }
}
