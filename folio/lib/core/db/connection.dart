import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database.dart';

const _keyName = 'folio.db.key.v1';

/// Returns the database encryption key, creating one on first launch.
/// The key lives in Android Keystore / iOS Keychain (via
/// flutter_secure_storage) and never leaves the device.
Future<String> loadOrCreateDatabaseKey({FlutterSecureStorage? storage}) async {
  final s = storage ?? const FlutterSecureStorage();
  final existing = await s.read(key: _keyName);
  if (existing != null && existing.length >= 32) return existing;
  final rnd = Random.secure();
  final key = List.generate(32, (_) => rnd.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  await s.write(key: _keyName, value: key);
  return key;
}

/// Applies the encryption key. Must be the first statement on a connection.
void applyKey(Database db, String key) {
  // Key is hex only, so quoting is safe.
  assert(RegExp(r'^[0-9a-f]+$').hasMatch(key));
  db.execute("PRAGMA key = '$key'");
  // Fails with "file is not a database" if the key is wrong.
  db.select('SELECT count(*) FROM sqlite_master');
}

/// Opens the encrypted on-device database in a background isolate.
Future<AppDatabase> openAppDatabase() async {
  final key = await loadOrCreateDatabaseKey();
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'folio.db'));
  final tmp = (await getTemporaryDirectory()).path;
  final executor = NativeDatabase.createBackgroundConnection(
    file,
    isolateSetup: () {
      // Android can't write to /tmp; point SQLite at the app cache dir.
      sqlite3.tempDirectory = tmp;
    },
    setup: (db) => applyKey(db, key),
  );
  return AppDatabase(executor);
}

/// In-memory database for tests (SQLite can't encrypt in-memory databases).
AppDatabase openTestDatabase() => AppDatabase(NativeDatabase.memory());

/// Opens an encrypted database at an explicit path (used by tests to verify
/// the on-disk format is encrypted).
AppDatabase openDatabaseAt(File file, String key) =>
    AppDatabase(NativeDatabase(file, setup: (db) => applyKey(db, key)));
