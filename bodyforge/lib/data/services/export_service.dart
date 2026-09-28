import 'dart:convert';

import 'package:drift/drift.dart';

import '../local/database.dart';

/// Exports every row the user owns as one JSON document (Settings → Export).
class ExportService {
  ExportService(this.db, this.userId);
  final AppDatabase db;
  final String userId;

  Future<Map<String, Object?>> collect() async {
    final out = <String, Object?>{
      'app': 'BODYFORGE',
      'format': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'user_id': userId,
    };
    for (final t in db.syncedTables) {
      final name = t.actualTableName;
      final rows = await db
          .customSelect('SELECT * FROM "$name" WHERE user_id = ? AND deleted_at IS NULL', variables: [Variable(userId)])
          .get();
      out[name] = [for (final r in rows) r.data];
    }
    return out;
  }

  Future<String> toJson() async => const JsonEncoder.withIndent('  ').convert(await collect());
}
