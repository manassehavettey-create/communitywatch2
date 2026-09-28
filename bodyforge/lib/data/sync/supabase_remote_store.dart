import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'remote_store.dart';

/// Supabase implementation. Uses only the anon key + the signed-in user's JWT;
/// Row Level Security on the server limits every query to the user's own rows.
class SupabaseRemoteStore implements RemoteStore {
  SupabaseRemoteStore(this.client);
  final SupabaseClient client;

  static bool _isConnectivity(Object e) =>
      e is SocketException || e is TimeoutException || e is HttpException || e.toString().contains('ClientException');

  @override
  Future<void> upsert(String table, List<Map<String, Object?>> rows) async {
    try {
      await client.from(table).upsert(rows, onConflict: 'id').timeout(const Duration(seconds: 30));
    } catch (e) {
      if (_isConnectivity(e)) throw RemoteUnavailable(e.toString());
      rethrow;
    }
  }

  @override
  Future<List<Map<String, Object?>>> pullSince(String table, String userId, DateTime? since, {int limit = 500}) async {
    try {
      var q = client.from(table).select().eq('user_id', userId);
      if (since != null) q = q.gt('synced_at', since.toUtc().toIso8601String());
      final rows = await q.order('synced_at', ascending: true).limit(limit).timeout(const Duration(seconds: 30));
      return [for (final r in rows) Map<String, Object?>.from(r)];
    } catch (e) {
      if (_isConnectivity(e)) throw RemoteUnavailable(e.toString());
      rethrow;
    }
  }

  /// Deletes the account and all data server-side via a SECURITY DEFINER
  /// function that only ever deletes `auth.uid()` — no service key needed.
  Future<void> deleteMyAccount() async {
    try {
      await client.rpc('delete_my_account').timeout(const Duration(seconds: 30));
    } catch (e) {
      if (_isConnectivity(e)) throw RemoteUnavailable(e.toString());
      rethrow;
    }
  }
}
