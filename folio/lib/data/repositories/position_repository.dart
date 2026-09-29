import 'package:drift/drift.dart';

import '../../core/db/database.dart';

class PositionRepository {
  PositionRepository(this.db);
  final AppDatabase db;

  Future<ReadingPosition?> get(int bookId) =>
      (db.select(db.readingPositions)..where((p) => p.bookId.equals(bookId))).getSingleOrNull();

  Stream<ReadingPosition?> watch(int bookId) =>
      (db.select(db.readingPositions)..where((p) => p.bookId.equals(bookId))).watchSingleOrNull();

  /// Saves the exact position: page, offset inside the page (0..1) and zoom.
  Future<void> save(int bookId, {required int page, double pageOffset = 0, double zoom = 1, DateTime? now}) => db
      .into(db.readingPositions)
      .insertOnConflictUpdate(
        ReadingPositionsCompanion.insert(
          bookId: Value(bookId),
          page: page,
          pageOffset: Value(pageOffset.clamp(0.0, 1.0)),
          zoom: Value(zoom <= 0 ? 1 : zoom),
          updatedAt: now ?? DateTime.now(),
        ),
      );

  Future<void> reset(int bookId) => (db.delete(db.readingPositions)..where((p) => p.bookId.equals(bookId))).go();
}
