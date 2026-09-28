import 'package:drift/drift.dart';

import '../../core/db/database.dart';

enum LibrarySort {
  recentlyAdded('Recently added'),
  recentlyOpened('Recently opened'),
  lastRead('Last read'),
  title('Title'),
  author('Author'),
  progress('Progress');

  const LibrarySort(this.label);
  final String label;
}

enum LibraryFilter {
  all('All'),
  reading('Reading'),
  finished('Finished'),
  unread('Unread'),
  favorites('Favorites');

  const LibraryFilter(this.label);
  final String label;
}

extension BookX on Book {
  /// Reading progress 0..1 based on the furthest page reached.
  double get progress {
    if (status == BookStatus.finished) return 1;
    if (pageCount <= 0) return 0;
    return (furthestPage / pageCount).clamp(0.0, 1.0);
  }

  int get progressPercent => (progress * 100).round();

  bool get isSearchable => indexStatus == IndexStatus.done && textPages > 0;
  bool get isScanned => indexStatus == IndexStatus.noText;
  bool get isIndexing =>
      indexStatus == IndexStatus.pending || indexStatus == IndexStatus.indexing;
}

class AnnotationCounts {
  const AnnotationCounts(this.highlights, this.notes, this.bookmarks);
  final int highlights;
  final int notes;
  final int bookmarks;
}

class BooksRepository {
  BooksRepository(this.db);
  final AppDatabase db;

  Stream<List<Book>> watchAll() =>
      (db.select(db.books)..orderBy([(b) => OrderingTerm.desc(b.addedAt)])).watch();

  Stream<Book?> watchBook(int id) =>
      (db.select(db.books)..where((b) => b.id.equals(id))).watchSingleOrNull();

  Future<Book?> getBook(int id) =>
      (db.select(db.books)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<Book?> findBySha(String sha) =>
      (db.select(db.books)..where((b) => b.sha256.equals(sha))).getSingleOrNull();

  Future<int> insertBook(BooksCompanion book) => db.into(db.books).insert(book);

  Future<void> updateBook(int id, BooksCompanion changes) =>
      (db.update(db.books)..where((b) => b.id.equals(id))).write(changes);

  Future<void> rename(int id, {required String title, String? author}) => updateBook(
        id,
        BooksCompanion(
          title: Value(title.trim()),
          author: Value(author?.trim().isEmpty ?? true ? null : author!.trim()),
        ),
      );

  Future<void> setFavorite(int id, bool favorite) =>
      updateBook(id, BooksCompanion(favorite: Value(favorite)));

  Future<void> markOpened(int id, {DateTime? now}) async {
    final book = await getBook(id);
    if (book == null) return;
    await updateBook(
      id,
      BooksCompanion(
        lastOpenedAt: Value(now ?? DateTime.now()),
        status: book.status == BookStatus.unread
            ? const Value(BookStatus.reading)
            : const Value.absent(),
      ),
    );
  }

  /// Records that [page] was reached; finishing the last page marks the book
  /// finished.
  Future<void> recordPageReached(int id, int page, {DateTime? now}) async {
    final book = await getBook(id);
    if (book == null) return;
    final furthest = page > book.furthestPage ? page : book.furthestPage;
    final finishedNow = book.pageCount > 0 &&
        page >= book.pageCount &&
        book.status != BookStatus.finished;
    await updateBook(
      id,
      BooksCompanion(
        furthestPage: Value(furthest),
        status: finishedNow
            ? const Value(BookStatus.finished)
            : (book.status == BookStatus.unread
                ? const Value(BookStatus.reading)
                : const Value.absent()),
        finishedAt: finishedNow ? Value(now ?? DateTime.now()) : const Value.absent(),
      ),
    );
  }

  Future<void> setStatus(int id, BookStatus status, {DateTime? now}) => updateBook(
        id,
        BooksCompanion(
          status: Value(status),
          finishedAt: Value(status == BookStatus.finished ? (now ?? DateTime.now()) : null),
          furthestPage: status == BookStatus.unread ? const Value(0) : const Value.absent(),
        ),
      );

  Future<void> setIndexState(
    int id,
    IndexStatus status, {
    int? indexedPages,
    int? textPages,
  }) =>
      updateBook(
        id,
        BooksCompanion(
          indexStatus: Value(status),
          indexedPages: indexedPages == null ? const Value.absent() : Value(indexedPages),
          textPages: textPages == null ? const Value.absent() : Value(textPages),
        ),
      );

  Future<List<Book>> booksNeedingIndex() => (db.select(db.books)
        ..where((b) => b.indexStatus.isIn([IndexStatus.pending.index, IndexStatus.indexing.index])))
      .get();

  /// Removes the book and everything attached to it (highlights, notes,
  /// bookmarks, positions, search index) from the database. File cleanup is
  /// the caller's job. Reading history (daily totals) is kept.
  Future<Book?> deleteBook(int id) async {
    final book = await getBook(id);
    if (book == null) return null;
    await db.transaction(() async {
      // page_texts deletion also clears FTS rows via trigger.
      await (db.delete(db.pageTexts)..where((t) => t.bookId.equals(id))).go();
      await (db.delete(db.books)..where((b) => b.id.equals(id))).go();
    });
    return book;
  }

  Stream<AnnotationCounts> watchCounts(int bookId) {
    final q = db.customSelect(
      'SELECT '
      '(SELECT count(*) FROM highlights WHERE book_id = ?1) AS h, '
      '(SELECT count(*) FROM notes WHERE book_id = ?1) AS n, '
      '(SELECT count(*) FROM bookmarks WHERE book_id = ?1) AS b',
      variables: [Variable.withInt(bookId)],
      readsFrom: {db.highlights, db.notes, db.bookmarks},
    );
    return q.watchSingle().map(
          (r) => AnnotationCounts(r.read<int>('h'), r.read<int>('n'), r.read<int>('b')),
        );
  }

  static List<Book> sortAndFilter(
    List<Book> books, {
    required LibrarySort sort,
    required LibraryFilter filter,
    String query = '',
    Set<int>? onlyIds,
  }) {
    final q = query.trim().toLowerCase();
    final out = books.where((b) {
      if (onlyIds != null && !onlyIds.contains(b.id)) return false;
      final okFilter = switch (filter) {
        LibraryFilter.all => true,
        LibraryFilter.reading => b.status == BookStatus.reading,
        LibraryFilter.finished => b.status == BookStatus.finished,
        LibraryFilter.unread => b.status == BookStatus.unread,
        LibraryFilter.favorites => b.favorite,
      };
      if (!okFilter) return false;
      if (q.isEmpty) return true;
      return b.title.toLowerCase().contains(q) ||
          (b.author?.toLowerCase().contains(q) ?? false) ||
          b.originalFileName.toLowerCase().contains(q);
    }).toList();

    int byDateDesc(DateTime? a, DateTime? b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return b.compareTo(a);
    }

    out.sort(switch (sort) {
      LibrarySort.recentlyAdded => (a, b) => b.addedAt.compareTo(a.addedAt),
      LibrarySort.recentlyOpened => (a, b) {
          final c = byDateDesc(a.lastOpenedAt, b.lastOpenedAt);
          return c != 0 ? c : b.addedAt.compareTo(a.addedAt);
        },
      LibrarySort.lastRead => (a, b) {
          final c = byDateDesc(a.lastReadAt, b.lastReadAt);
          return c != 0 ? c : byDateDesc(a.lastOpenedAt, b.lastOpenedAt);
        },
      LibrarySort.title => (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      LibrarySort.author => (a, b) {
          final aa = a.author?.toLowerCase();
          final bb = b.author?.toLowerCase();
          if (aa == null && bb == null) return a.title.compareTo(b.title);
          if (aa == null) return 1;
          if (bb == null) return -1;
          final c = aa.compareTo(bb);
          return c != 0 ? c : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        },
      LibrarySort.progress => (a, b) {
          final c = b.progress.compareTo(a.progress);
          return c != 0 ? c : byDateDesc(a.lastOpenedAt, b.lastOpenedAt);
        },
    });
    return out;
  }
}
