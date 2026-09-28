import 'package:bible_app/data/db/database.dart';
import 'package:bible_app/data/sync/remote_store.dart';
import 'package:bible_app/data/sync/sync_engine.dart';
import 'package:bible_app/data/sync/sync_writer.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_remote.dart';

const user = 'user-1';

/// One simulated device: its own database, clock and writer.
class Device {
  Device(this.remote) : db = AppDatabase(NativeDatabase.memory()) {
    writer = SyncWriter(db, () => user, clock: () => clock);
  }

  final FakeRemote remote;
  final AppDatabase db;
  late final SyncWriter writer;
  DateTime clock = DateTime.utc(2026, 9, 1, 12);

  void tick([int ms = 1000]) => clock = clock.add(Duration(milliseconds: ms));

  SyncEngine engine() =>
      SyncEngine(db, remote, userId: user, clock: () => clock);

  Future<SyncReport> sync() => engine().sync();

  Future<void> writeNote(String id, String body) => writer.write(
    'notes',
    id,
    (t) => db
        .into(db.notes)
        .insertOnConflictUpdate(
          NotesCompanion.insert(
            id: id,
            userId: Value(user),
            createdAt: t,
            updatedAt: t,
            startRef: 'JHN.3.16',
            endRef: 'JHN.3.16',
            startKey: 42003016,
            endKey: 42003016,
            body: body,
          ),
        ),
  );

  Future<List<Note>> liveNotes() =>
      (db.select(db.notes)..where((n) => n.deletedAt.isNull())).get();

  Future<int> outboxCount() async => (await db.select(db.outbox).get()).length;
}

void main() {
  // Two simulated devices means two databases in one isolate, on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeRemote remote;
  late Device a;
  late Device b;

  setUp(() {
    remote = FakeRemote();
    a = Device(remote);
    b = Device(remote);
  });

  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  test(
    'local writes are queued, pushed once, and the outbox empties',
    () async {
      await a.writeNote('n1', 'first');
      await a.writeNote('n1', 'edited'); // same entity: one outbox entry
      expect(await a.outboxCount(), 1);

      final report = await a.sync();
      expect(report.pushed, 1);
      expect(await a.outboxCount(), 0);
      final stored = remote.table('notes').values.single;
      expect(stored['body'], 'edited');
      expect(stored['user_id'], user);

      // Nothing pending: a second sync uploads nothing.
      final again = await a.sync();
      expect(again.pushed, 0);
    },
  );

  test('changes reach another device without queueing uploads there', () async {
    await a.writeNote('n1', 'from A');
    await a.sync();

    final report = await b.sync();
    expect(report.pulled, 1);
    expect((await b.liveNotes()).single.body, 'from A');
    expect(await b.outboxCount(), 0);
  });

  test('deletes sync as tombstones', () async {
    await a.writeNote('n1', 'to delete');
    await a.sync();
    await b.sync();
    expect(await b.liveNotes(), hasLength(1));

    a.tick();
    await a.writer.softDelete('notes', 'n1');
    await a.sync();
    await b.sync();
    expect(await b.liveNotes(), isEmpty);
  });

  test('last write wins for plain rows edited on two devices', () async {
    Future<void> setColor(Device d, String color) => d.writer.write(
      'highlights',
      'h1',
      (t) => d.db
          .into(d.db.highlights)
          .insertOnConflictUpdate(
            HighlightsCompanion.insert(
              id: 'h1',
              userId: Value(user),
              createdAt: t,
              updatedAt: t,
              startRef: 'PSA.23.1',
              endRef: 'PSA.23.1',
              startKey: 18023001,
              endKey: 18023001,
              color: color,
            ),
          ),
    );

    await setColor(a, 'butter');
    await a.sync();
    await b.sync();

    // Both edit while offline; B's edit is later.
    a.tick(1000);
    await setColor(a, 'sage');
    b.tick(5000);
    await setColor(b, 'sky');

    await a.sync(); // A uploads sage
    await b
        .sync(); // B pulls sage (older than its own edit), keeps sky, uploads
    await a.sync(); // A pulls sky

    for (final d in [a, b]) {
      final h = await d.db.select(d.db.highlights).getSingle();
      expect(h.color, 'sky');
      expect(await d.outboxCount(), 0);
    }
  });

  test('conflicting note edits keep the losing edit as a copy', () async {
    await a.writeNote('n1', 'original');
    await a.sync();
    await b.sync();

    a.tick(1000);
    await a.writeNote('n1', 'A version');
    b.tick(5000);
    await b.writeNote('n1', 'B version');

    await b.sync(); // B's later edit reaches the server first
    final report = await a.sync(); // A must not silently lose its edit
    expect(report.conflictCopies, 1);

    final bodies = (await a.liveNotes()).map((n) => n.body).toSet();
    expect(bodies, {'B version', 'A version'});

    // The copy syncs to B as well.
    await b.sync();
    expect((await b.liveNotes()).map((n) => n.body).toSet(), {
      'B version',
      'A version',
    });
  });

  test('a failed upload keeps the outbox and records the error', () async {
    await a.writeNote('n1', 'offline');
    remote.failNextUpsert = Exception('network down');
    await expectLater(a.sync(), throwsA(isA<SyncException>()));

    final entry = await a.db.select(a.db.outbox).getSingle();
    expect(entry.attempts, 1);
    expect(entry.lastError, contains('network down'));

    // Retry succeeds and clears it.
    await a.sync();
    expect(await a.outboxCount(), 0);
    expect(remote.table('notes'), hasLength(1));
  });

  test('an edit made during an upload is not lost', () async {
    await a.writeNote('n1', 'v1');
    var edited = false;
    remote.onUpsert = (table) {
      if (edited) return;
      edited = true;
      // Queue a new edit while the upload is in flight.
      a.writeNote('n1', 'v2');
    };
    await a.sync();
    remote.onUpsert = null;
    await Future<void>.delayed(Duration.zero);
    expect(await a.outboxCount(), 1, reason: 'v2 still needs uploading');

    await a.sync();
    expect(remote.table('notes').values.single['body'], 'v2');
  });

  test('pull pages through many changes', () async {
    for (var i = 0; i < 1234; i++) {
      await a.writeNote('n$i', 'note $i');
    }
    await a.sync();
    final report = await b.sync();
    expect(report.pulled, 1234);
    expect(await b.liveNotes(), hasLength(1234));
  });

  test('booleans round-trip through the remote as true/false', () async {
    await a.writer.write(
      'preferences',
      'preferences',
      (t) => a.db
          .into(a.db.preferences)
          .insertOnConflictUpdate(
            PreferencesCompanion.insert(
              id: 'preferences',
              userId: Value(user),
              createdAt: t,
              updatedAt: t,
              showVerseNumbers: const Value(false),
              fontSize: const Value(22),
            ),
          ),
    );
    await a.sync();
    final remoteRow = remote.table('preferences').values.single;
    expect(remoteRow['show_verse_numbers'], false);

    await b.sync();
    final prefs = await b.db.select(b.db.preferences).getSingle();
    expect(prefs.showVerseNumbers, isFalse);
    expect(prefs.fontSize, 22);
  });

  test('rows written while signed out are claimed on sign-in', () async {
    final device = Device(remote);
    final signedOut = SyncWriter(
      device.db,
      () => null,
      clock: () => device.clock,
    );
    await signedOut.write(
      'notes',
      'local',
      (t) => device.db
          .into(device.db.notes)
          .insert(
            NotesCompanion.insert(
              id: 'local',
              createdAt: t,
              updatedAt: t,
              startRef: 'GEN.1.1',
              endRef: 'GEN.1.1',
              startKey: 1001,
              endKey: 1001,
              body: 'before account',
            ),
          ),
    );
    expect(await device.writer.claimLocalRows(user), 1);
    await device.sync();
    expect(remote.table('notes')['$user/local']?['body'], 'before account');
    await device.db.close();
  });

  test('sign-out wipes account data from the device', () async {
    await a.writeNote('n1', 'private');
    await a.db.setValue('sync.cursor.notes', '5');
    await a.db.setValue('onboarding.done', '1');
    await a.writer.wipeUserData();
    expect(await a.db.select(a.db.notes).get(), isEmpty);
    expect(await a.outboxCount(), 0);
    expect(await a.db.getValue('sync.cursor.notes'), isNull);
    expect(await a.db.getValue('onboarding.done'), '1');
  });
}
