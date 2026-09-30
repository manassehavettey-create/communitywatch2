import 'dart:convert';

import 'package:hive_ce/hive.dart';

/// JSON-in-Hive store for small app state (settings, favourites, seen
/// snapshots, notification log). Provider responses live in the separate
/// cache box via [HiveCacheStore].
class LocalStore {
  LocalStore(this._box);
  final Box<String> _box;

  Map<String, dynamic>? readMap(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  List<dynamic>? readList(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      return v is List ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, Object value) => _box.put(key, jsonEncode(value));
  Future<void> remove(String key) => _box.delete(key);

  Iterable<String> keysWithPrefix(String prefix) => _box.keys.map((k) => '$k').where((k) => k.startsWith(prefix));
}
