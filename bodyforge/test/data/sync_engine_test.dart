import 'package:bodyforge/data/local/database.dart';
import 'package:bodyforge/data/sync/remote_store.dart';
import 'package:bodyforge/data/sync/sync_engine.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const uid = 'user-1';

MeasurementsCompanion measurement(String id, double value, DateTime updated) => MeasurementsCompanion.insert(
      id: id,
      userId: uid,
      type: 'weight',
      value: value,
      measuredOn: '2026-09-28',
      updatedAt: updated,
    );

WorkoutsCompanion workout(String id, DateTime at, {String title = 'Upper Body'}) => WorkoutsCompanion.insert(
      id: id,
      userId: uid,
      date: '2026-09-28',
      startedAt: at,
      endedAt: at.add(const Duration(minutes: 30)),
      dayType: 'upper',
      kind: 'planned',
      title: title,
      plan: '{}',
      durationSec: 1800,
      updatedAt: at,
    );

/// A complete remote-shaped row (as another device would have pushed it).
Future<Map<String, Object?>> fullRemoteRow(AppDatabase db, WorkoutsCompanion c) async {
  final scratch = AppDatabase(NativeDatabase.memory());
  await scratch.into(scratch.workouts).insert(c);
  final row = (await scratch.readRemoteShape('workouts', c.id.value))!;
  await scratch.close();
  return row;
}

void main() {
  late AppDatabase db;
  late InMemoryRemoteStore remote;
  late SyncEngine engine;
  final t0 = DateTime.utc(2026, 9, 28, 8);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remote = InMemoryRemoteStore(clock: () => DateTime.now());
    engine = SyncEngine(db, remote);
  });
  tearDown(() => db.close());

  test('a local write is queued, pushed and the queue is emptied', () async {
    await db.write(db.measurements, measurement('m1', 78, t0), 'm1');
    expect(await db.pendingChanges(), 1);
    final r = await engine.sync(uid);
    expect(r.pushed, 1);
    expect(await db.pendingChanges(), 0);
    expect(remote.tables['measurements']!['m1']!['value'], 78.0);
    expect(remote.tables['measurements']!['m1']!['updated_at'], t0.toIso8601String());
  });

  test('offline for days: many edits collapse to one entry and push on reconnect', () async {
    remote.online = false;
    for (var i = 0; i < 5; i++) {
      await db.write(db.measurements, measurement('m1', 78.0 - i, t0.add(Duration(days: i))), 'm1');
    }
    await db.write(db.workouts, workout('w1', t0), 'w1');
    expect(await db.pendingChanges(), 2);
    await expectLater(engine.sync(uid), throwsA(isA<RemoteUnavailable>()));
    expect(await db.pendingChanges(), 2, reason: 'nothing is lost while offline');

    remote.online = true;
    final r = await engine.sync(uid);
    expect(r.pushed, 2);
    expect(remote.tables['measurements']!['m1']!['value'], 74.0);
    expect(await db.pendingChanges(), 0);
  });

  test('last-write-wins: a newer remote row replaces the local copy', () async {
    await db.write(db.measurements, measurement('m1', 78, t0), 'm1');
    await engine.sync(uid);
    final newer = {...remote.tables['measurements']!['m1']!}
      ..['value'] = 76.5
      ..['updated_at'] = t0.add(const Duration(hours: 1)).toIso8601String();
    remote.writeFromOtherDevice('measurements', newer);

    final r = await engine.sync(uid);
    expect(r.pulled, 1);
    final local = await (db.select(db.measurements)..where((m) => m.id.equals('m1'))).getSingle();
    expect(local.value, 76.5);
  });

  test('last-write-wins: a newer local row is kept and re-pushed', () async {
    await db.write(db.measurements, measurement('m1', 78, t0), 'm1');
    await engine.sync(uid);
    // Other device wrote an older edit that reached the server later (clock skew / offline).
    final older = {...remote.tables['measurements']!['m1']!}
      ..['value'] = 80.0
      ..['updated_at'] = t0.subtract(const Duration(hours: 1)).toIso8601String();
    remote.writeFromOtherDevice('measurements', older);
    // Meanwhile this device edits again, offline.
    await db.into(db.measurements).insertOnConflictUpdate(measurement('m1', 77, t0.add(const Duration(hours: 2))));

    final r = await engine.sync(uid);
    expect(r.keptLocal, greaterThanOrEqualTo(1));
    final local = await (db.select(db.measurements)..where((m) => m.id.equals('m1'))).getSingle();
    expect(local.value, 77);
    await engine.sync(uid);
    expect(remote.tables['measurements']!['m1']!['value'], 77.0, reason: 'the winner is pushed back');
  });

  test('rows written late with old timestamps are still pulled (server cursor, not client clock)', () async {
    await db.write(db.measurements, measurement('m1', 78, t0), 'm1');
    await engine.sync(uid); // cursor now at the latest synced_at
    remote.writeFromOtherDevice('measurements', {
      'id': 'm2',
      'user_id': uid,
      'type': 'waist',
      'label': null,
      'value': 90.0,
      'measured_on': '2026-09-01',
      'created_at': DateTime.utc(2026, 9, 1).toIso8601String(),
      'updated_at': DateTime.utc(2026, 9, 1).toIso8601String(),
      'deleted_at': null,
    });
    final r = await engine.sync(uid);
    expect(r.pulled, 1);
    expect(await (db.select(db.measurements)..where((m) => m.id.equals('m2'))).getSingleOrNull(), isNotNull);
  });

  test('workout logs merge safely: union by id, local logs never overwritten', () async {
    await db.write(db.workouts, workout('w-local', t0, title: 'Local'), 'w-local');
    remote.writeFromOtherDevice('workouts', await fullRemoteRow(db, workout('w-remote', t0.add(const Duration(hours: 3)), title: 'Remote')));
    await engine.sync(uid);

    // Remote copy of the local workout with a later timestamp must not clobber it.
    final tampered = {...remote.tables['workouts']!['w-local']!}
      ..['title'] = 'Overwritten'
      ..['updated_at'] = t0.add(const Duration(days: 1)).toIso8601String();
    remote.writeFromOtherDevice('workouts', tampered);
    await engine.sync(uid);

    final all = await db.select(db.workouts).get();
    expect(all.map((w) => w.id), containsAll(['w-local', 'w-remote']));
    expect(all.firstWhere((w) => w.id == 'w-local').title, 'Local');
  });

  test('a remote tombstone deletes an append-only row', () async {
    await db.write(db.workouts, workout('w1', t0), 'w1');
    await engine.sync(uid);
    final tomb = {...remote.tables['workouts']!['w1']!}
      ..['deleted_at'] = t0.add(const Duration(hours: 1)).toIso8601String()
      ..['updated_at'] = t0.add(const Duration(hours: 1)).toIso8601String();
    remote.writeFromOtherDevice('workouts', tomb);
    await engine.sync(uid);
    final w = await (db.select(db.workouts)..where((x) => x.id.equals('w1'))).getSingle();
    expect(w.deletedAt, isNotNull);
  });

  test('achievements keep the earliest unlock time', () async {
    final late_ = t0.add(const Duration(days: 2));
    await db.write(
        db.userAchievements,
        UserAchievementsCompanion.insert(
            id: '$uid:first_rep', userId: uid, achievementId: 'first_rep', unlockedAt: late_, updatedAt: late_),
        '$uid:first_rep');
    remote.writeFromOtherDevice('user_achievements', {
      'id': '$uid:first_rep',
      'user_id': uid,
      'achievement_id': 'first_rep',
      'unlocked_at': t0.toIso8601String(),
      'created_at': t0.toIso8601String(),
      'updated_at': t0.toIso8601String(),
      'deleted_at': null,
    });
    await engine.sync(uid);
    expect(remote.tables['user_achievements']!['$uid:first_rep']!['unlocked_at'], t0.toIso8601String(),
        reason: 'the server keeps the earliest unlock');
    final a = await db.select(db.userAchievements).getSingle();
    expect(a.unlockedAt.toUtc(), t0);
  });

  test('entries for rows owned by another user are dropped, not pushed', () async {
    await db.write(
        db.measurements,
        MeasurementsCompanion.insert(
            id: 'x', userId: 'someone-else', type: 'weight', value: 1, measuredOn: '2026-09-28', updatedAt: t0),
        'x');
    final r = await engine.sync(uid);
    expect(r.pushed, 0);
    expect(await db.pendingChanges(), 0);
    expect(remote.tables['measurements'], isNull);
  });

  test('sign-up re-keys a local-only account and queues everything', () async {
    const local = 'local-abc';
    await db.into(db.measurements).insert(MeasurementsCompanion.insert(
        id: 'm1', userId: local, type: 'weight', value: 70, measuredOn: '2026-09-28', updatedAt: t0));
    await db.into(db.skillProgress).insert(SkillProgressCompanion.insert(
        id: '$local:push', userId: local, trackKey: 'push', nodeIndex: 3, sets: 3, amount: 10, updatedAt: t0));
    await db.rekeyUser(local, uid);
    final m = await db.select(db.measurements).getSingle();
    expect(m.userId, uid);
    final s = await db.select(db.skillProgress).getSingle();
    expect(s.id, '$uid:push');
    expect(await db.pendingChanges(), 2);
    await engine.sync(uid);
    expect(remote.tables['skill_progress']!.keys, ['$uid:push']);
  });

  test('row JSON round-trips between local and remote shapes', () async {
    final c = workout('w1', t0);
    await db.into(db.workouts).insert(c);
    final shape = (await db.readRemoteShape('workouts', 'w1'))!;
    expect(shape['day_type'], 'upper');
    expect(shape['started_at'], t0.toIso8601String());
    final back = await db.fromRemote(db.workouts, {...shape, 'synced_at': 'ignored'});
    expect(back.startedAt.toUtc(), t0);
    expect(back.title, 'Upper Body');
  });

  test('concurrent sync calls are coalesced', () async {
    await db.write(db.measurements, measurement('m1', 78, t0), 'm1');
    final results = await Future.wait([engine.sync(uid), engine.sync(uid)]);
    expect(results.map((r) => r.pushed).reduce((a, b) => a + b), 1);
  });

  test('wipe clears all local data', () async {
    await db.write(db.measurements, measurement('m1', 78, t0), 'm1');
    await db.wipe();
    expect(await db.select(db.measurements).get(), isEmpty);
    expect(await db.pendingChanges(), 0);
  });
}
