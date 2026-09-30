import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/core/cache/cache_store.dart';
import 'package:touchline/data/models/models.dart';

void main() {
  late MemoryCacheStore store;
  late DateTime now;
  late int calls;
  late Object? failWith;

  CachedFetcher fetcher() => CachedFetcher(store, (p, q) async {
        calls++;
        if (failWith != null) throw failWith!;
        return 'body$calls';
      }, clock: () => now);

  setUp(() {
    store = MemoryCacheStore();
    now = DateTime(2026, 9, 30, 12);
    calls = 0;
    failWith = null;
  });

  test('fresh cache is used within TTL', () async {
    final f = fetcher();
    final a = await f.get('/x', {'b': '1', 'a': '2'}, ttl: const Duration(minutes: 5));
    now = now.add(const Duration(minutes: 4));
    final b = await f.get('/x', {'a': '2', 'b': '1'}, ttl: const Duration(minutes: 5));
    expect(calls, 1);
    expect(b.body, a.body);
    expect(b.fromCache, isTrue);
  });

  test('expired cache refetches', () async {
    final f = fetcher();
    await f.get('/x', const {}, ttl: const Duration(minutes: 1));
    now = now.add(const Duration(minutes: 2));
    final r = await f.get('/x', const {}, ttl: const Duration(minutes: 1));
    expect(calls, 2);
    expect(r.body, 'body2');
    expect(r.stale, isFalse);
  });

  test('network failure falls back to last-known data flagged stale', () async {
    final f = fetcher();
    await f.get('/live', const {}, ttl: const Duration(seconds: 15));
    now = now.add(const Duration(minutes: 3));
    failWith = const DataException(DataErrorKind.network, 'offline');
    final r = await f.get('/live', const {}, ttl: const Duration(seconds: 15));
    expect(r.stale, isTrue);
    expect(r.body, 'body1');
    expect(r.fetchedAt, DateTime(2026, 9, 30, 12));
  });

  test('no cache + offline rethrows (never fabricates)', () async {
    failWith = const DataException(DataErrorKind.network, 'offline');
    expect(fetcher().get('/y', const {}, ttl: const Duration(minutes: 1)), throwsA(isA<DataException>()));
  });

  test('auth/plan errors are not masked by stale cache', () async {
    final f = fetcher();
    await f.get('/z', const {}, ttl: Duration.zero);
    failWith = const DataException(DataErrorKind.plan, 'plan');
    expect(f.get('/z', const {}, ttl: Duration.zero), throwsA(isA<DataException>()));
  });

  test('concurrent requests are de-duplicated', () async {
    final f = fetcher();
    await Future.wait([f.get('/d', const {}, ttl: Duration.zero), f.get('/d', const {}, ttl: Duration.zero)]);
    expect(calls, 1);
  });
}
