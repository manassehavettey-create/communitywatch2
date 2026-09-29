import 'package:drift/drift.dart';

import '../../core/db/database.dart';

class CollectionWithBooks {
  const CollectionWithBooks(this.collection, this.bookIds);
  final Collection collection;

  /// Most recently added first.
  final List<int> bookIds;
}

class CollectionsRepository {
  CollectionsRepository(this.db);
  final AppDatabase db;

  Future<int> create(String name, int color, {DateTime? now}) => db
      .into(db.collections)
      .insert(CollectionsCompanion.insert(name: name.trim(), color: color, createdAt: now ?? DateTime.now()));

  Future<void> rename(int id, String name, {int? color}) =>
      (db.update(db.collections)..where((c) => c.id.equals(id))).write(
        CollectionsCompanion(name: Value(name.trim()), color: color == null ? const Value.absent() : Value(color)),
      );

  Future<void> delete(int id) => (db.delete(db.collections)..where((c) => c.id.equals(id))).go();

  Future<void> addBook(int collectionId, int bookId, {DateTime? now}) => db
      .into(db.collectionBooks)
      .insert(
        CollectionBooksCompanion.insert(collectionId: collectionId, bookId: bookId, addedAt: now ?? DateTime.now()),
        mode: InsertMode.insertOrIgnore,
      );

  Future<void> removeBook(int collectionId, int bookId) =>
      (db.delete(db.collectionBooks)..where((c) => c.collectionId.equals(collectionId) & c.bookId.equals(bookId))).go();

  /// Sets exactly which collections [bookId] belongs to.
  Future<void> setBookCollections(int bookId, Set<int> collectionIds) async {
    await db.transaction(() async {
      await (db.delete(
        db.collectionBooks,
      )..where((c) => c.bookId.equals(bookId) & c.collectionId.isNotIn(collectionIds))).go();
      for (final id in collectionIds) {
        await addBook(id, bookId);
      }
    });
  }

  Stream<Set<int>> watchCollectionIdsForBook(int bookId) => (db.select(
    db.collectionBooks,
  )..where((c) => c.bookId.equals(bookId))).watch().map((rows) => {for (final r in rows) r.collectionId});

  Stream<List<CollectionWithBooks>> watchAll() {
    final q = db.select(db.collections).join([
      leftOuterJoin(db.collectionBooks, db.collectionBooks.collectionId.equalsExp(db.collections.id)),
    ])..orderBy([OrderingTerm.desc(db.collections.createdAt), OrderingTerm.desc(db.collectionBooks.addedAt)]);
    return q.watch().map((rows) {
      final order = <int>[];
      final byId = <int, Collection>{};
      final books = <int, List<int>>{};
      for (final r in rows) {
        final c = r.readTable(db.collections);
        if (!byId.containsKey(c.id)) {
          byId[c.id] = c;
          order.add(c.id);
          books[c.id] = [];
        }
        final link = r.readTableOrNull(db.collectionBooks);
        if (link != null) books[c.id]!.add(link.bookId);
      }
      return [for (final id in order) CollectionWithBooks(byId[id]!, books[id]!)];
    });
  }

  Stream<Collection?> watchCollection(int id) =>
      (db.select(db.collections)..where((c) => c.id.equals(id))).watchSingleOrNull();
}
