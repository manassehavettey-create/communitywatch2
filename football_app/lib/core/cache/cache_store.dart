import 'dart:async';

import 'package:hive_ce/hive.dart';

import '../../data/models/common.dart';

class CacheEntry {
  const CacheEntry(this.value, this.storedAt);
  final String value;
  final DateTime storedAt;
}

/// Minimal persistent key-value cache used for provider responses.
abstract interface class CacheStore {
  CacheEntry? read(String key);
  Future<void> write(String key, String value, DateTime at);
  Future<void> clear();
  int get length;
}

class MemoryCacheStore implements CacheStore {
  final _map = <String, CacheEntry>{};
  @override
  CacheEntry? read(String key) => _map[key];
  @override
  Future<void> write(String key, String value, DateTime at) async => _map[key] = CacheEntry(value, at);
  @override
  Future<void> clear() async => _map.clear();
  @override
  int get length => _map.length;
}

/// Hive-backed store. Values are stored as `<epochMs>|<payload>`. Oldest
/// entries are evicted once [maxEntries] is exceeded.
class HiveCacheStore implements CacheStore {
  HiveCacheStore(this._box, {this.maxEntries = 600});
  final Box<String> _box;
  final int maxEntries;

  @override
  CacheEntry? read(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    final i = raw.indexOf('|');
    if (i <= 0) return null;
    final ms = int.tryParse(raw.substring(0, i));
    if (ms == null) return null;
    return CacheEntry(raw.substring(i + 1), DateTime.fromMillisecondsSinceEpoch(ms));
  }

  @override
  Future<void> write(String key, String value, DateTime at) async {
    await _box.put(key, '${at.millisecondsSinceEpoch}|$value');
    if (_box.length > maxEntries) unawaited(_evict());
  }

  Future<void> _evict() async {
    final stamped = <(dynamic, int)>[];
    for (final k in _box.keys) {
      final raw = _box.get(k);
      final i = raw?.indexOf('|') ?? -1;
      stamped.add((k, i > 0 ? int.tryParse(raw!.substring(0, i)) ?? 0 : 0));
    }
    stamped.sort((a, b) => a.$2.compareTo(b.$2));
    final remove = stamped.take(stamped.length - (maxEntries * 0.85).round()).map((e) => e.$1);
    await _box.deleteAll(remove);
  }

  @override
  Future<void> clear() => _box.clear();

  @override
  int get length => _box.length;
}

class Fetched {
  const Fetched(this.body, this.fetchedAt, {this.fromCache = false, this.stale = false});
  final String body;
  final DateTime fetchedAt;
  final bool fromCache;
  final bool stale;
}

/// Cache-first fetcher with TTL, in-flight de-duplication and offline
/// fallback: if the network fails and any cached copy exists, the cached copy
/// is returned flagged `stale` — never fabricated.
class CachedFetcher {
  CachedFetcher(this.store, this.network, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final CacheStore store;
  final Future<String> Function(String path, Map<String, String> query) network;
  final DateTime Function() _clock;
  final _inflight = <String, Future<Fetched>>{};

  static String keyFor(String path, Map<String, String> query) {
    final keys = query.keys.toList()..sort();
    return '$path?${keys.map((k) => '$k=${query[k]}').join('&')}';
  }

  Future<Fetched> get(String path, Map<String, String> query, {required Duration ttl, bool force = false}) {
    final key = keyFor(path, query);
    final cached = store.read(key);
    final now = _clock();
    if (!force && cached != null && now.difference(cached.storedAt) < ttl) {
      return Future.value(Fetched(cached.value, cached.storedAt, fromCache: true));
    }
    return _inflight[key] ??= _load(key, path, query, cached).whenComplete(() {
      _inflight.remove(key);
    });
  }

  Future<Fetched> _load(String key, String path, Map<String, String> query, CacheEntry? cached) async {
    try {
      final body = await network(path, query);
      final at = _clock();
      await store.write(key, body, at);
      return Fetched(body, at);
    } on DataException catch (e) {
      if (e.allowsStaleFallback && cached != null) {
        return Fetched(cached.value, cached.storedAt, fromCache: true, stale: true);
      }
      rethrow;
    }
  }
}
