import 'package:folio/core/db/connection.dart';
import 'package:folio/core/db/database.dart';

/// In-memory databases can't be keyed; encryption is covered by encryption_test.dart.
AppDatabase newDb() => openTestDatabase();

Future<int> seedBook(
  AppDatabase db, {
  String title = 'Test Book',
  String sha = 'sha-1',
  int pages = 100,
  DateTime? addedAt,
}) {
  return db.into(db.books).insert(
        BooksCompanion.insert(
          title: title,
          originalFileName: '$title.pdf',
          filePath: '/tmp/$sha.pdf',
          fileSize: 1000,
          sha256: sha,
          pageCount: pages,
          addedAt: addedAt ?? DateTime(2026, 1, 1),
        ),
      );
}
