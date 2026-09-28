import 'dart:io';

import 'package:bible_app/data/db/database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parses `create table public.<name> ( ... );` blocks into
/// column → (sql type, nullable).
Map<String, Map<String, (String, bool)>> parseMigrations() {
  final sql = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .map((f) => f.readAsStringSync())
      .join('\n');
  final tables = <String, Map<String, (String, bool)>>{};
  final block = RegExp(
    r'create table public\.(\w+) \((.*?)\n\);',
    dotAll: true,
  );
  for (final m in block.allMatches(sql)) {
    final cols = <String, (String, bool)>{};
    for (final raw in m.group(2)!.split('\n')) {
      final line = raw.trim();
      final c = RegExp(
        r'^(\w+) (text|integer|bigint|boolean|double precision|uuid|jsonb|timestamptz)\b',
      ).firstMatch(line);
      if (c == null) continue;
      cols[c.group(1)!] = (c.group(2)!, !line.contains('not null'));
    }
    tables[m.group(1)!] = cols;
  }
  return tables;
}

void main() {
  test('every synced local table matches its Supabase table', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final remote = parseMigrations();

    for (final table in syncedTables) {
      final remoteCols = remote[table];
      expect(remoteCols, isNotNull, reason: 'missing remote table $table');

      final local = {for (final c in db.syncTable(table).$columns) c.name: c};
      // Server-only columns.
      final expectedRemote = {...local.keys, 'server_updated_at'};
      expect(
        remoteCols!.keys.toSet(),
        expectedRemote,
        reason: 'columns differ for $table',
      );

      for (final entry in local.entries) {
        final name = entry.key;
        final col = entry.value;
        final (sqlType, nullable) = remoteCols[name]!;
        final okTypes = switch (col.type) {
          DriftSqlType.string => {'text'},
          DriftSqlType.int => {'integer', 'bigint'},
          DriftSqlType.bool => {'boolean'},
          DriftSqlType.double => {'double precision'},
          _ => <String>{},
        };
        if (name == 'user_id') {
          expect(sqlType, 'uuid');
          continue; // always set remotely, nullable only on the device
        }
        expect(okTypes, contains(sqlType), reason: '$table.$name type');
        expect(nullable, col.$nullable, reason: '$table.$name nullability');
      }
    }
  });

  test('epoch-millisecond columns are bigint remotely', () {
    final remote = parseMigrations();
    for (final table in syncedTables) {
      for (final e in remote[table]!.entries) {
        if (e.key.endsWith('_at') && e.key != 'server_updated_at') {
          expect(e.value.$1, 'bigint', reason: '$table.${e.key}');
        }
      }
    }
  });
}
