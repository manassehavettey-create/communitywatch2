import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/db/connection.dart';

import 'test_helpers.dart';

void main() {
  test('database file on disk is encrypted and needs the key', () async {
    final dir = await Directory.systemTemp.createTemp('folio_enc');
    final file = File('${dir.path}/folio.db');
    const key = 'aabbccddeeff00112233445566778899';
    final db = openDatabaseAt(file, key);
    await seedBook(db, title: 'Secret Diary');
    await db.close();

    final bytes = file.readAsBytesSync();
    expect(String.fromCharCodes(bytes.take(15)), isNot('SQLite format 3'));
    expect(String.fromCharCodes(bytes).contains('Secret Diary'), isFalse);

    final wrong = openDatabaseAt(file, '00000000000000000000000000000000');
    await expectLater(wrong.customSelect('SELECT 1').get(), throwsA(anything));
    await wrong.close().catchError((_) {});

    final again = openDatabaseAt(file, key);
    final rows = await again.select(again.books).get();
    expect(rows.single.title, 'Secret Diary');
    await again.close();
    await dir.delete(recursive: true);
  });
}
