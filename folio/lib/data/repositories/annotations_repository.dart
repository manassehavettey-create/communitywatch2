import 'dart:convert';
import 'dart:ui';

import 'package:drift/drift.dart';

import '../../core/db/database.dart';

/// A highlight, note or bookmark together with its book's title.
class WithBook<T> {
  const WithBook(this.item, this.bookTitle);
  final T item;
  final String bookTitle;
}

/// Rects are stored in PDF page coordinates (points, origin bottom-left).
String encodeRects(List<Rect> rects) => jsonEncode([
      for (final r in rects) [r.left, r.top, r.right, r.bottom],
    ]);

List<Rect> decodeRects(String json) {
  try {
    final list = jsonDecode(json) as List;
    return [
      for (final e in list)
        Rect.fromLTRB(
          (e[0] as num).toDouble(),
          (e[1] as num).toDouble(),
          (e[2] as num).toDouble(),
          (e[3] as num).toDouble(),
        ),
    ];
  } catch (_) {
    return const [];
  }
}

class AnnotationsRepository {
  AnnotationsRepository(this.db);
  final AppDatabase db;

  // ---------------------------------------------------------------- highlights

  Future<int> addHighlight({
    required int bookId,
    required int page,
    required String content,
    required int color,
    required int startIndex,
    required int endIndex,
    required List<Rect> rects,
    DateTime? now,
  }) =>
      db.into(db.highlights).insert(
            HighlightsCompanion.insert(
              bookId: bookId,
              page: page,
              content: content.trim(),
              color: color,
              startIndex: startIndex,
              endIndex: endIndex,
              rects: encodeRects(rects),
              createdAt: now ?? DateTime.now(),
            ),
          );

  Future<void> setHighlightColor(int id, int color) =>
      (db.update(db.highlights)..where((h) => h.id.equals(id)))
          .write(HighlightsCompanion(color: Value(color)));

  Future<void> deleteHighlight(int id) =>
      (db.delete(db.highlights)..where((h) => h.id.equals(id))).go();

  Future<Highlight?> getHighlight(int id) =>
      (db.select(db.highlights)..where((h) => h.id.equals(id))).getSingleOrNull();

  Stream<List<Highlight>> watchHighlightsForBook(int bookId) => (db.select(db.highlights)
        ..where((h) => h.bookId.equals(bookId))
        ..orderBy([(h) => OrderingTerm.asc(h.page), (h) => OrderingTerm.asc(h.startIndex)]))
      .watch();

  Stream<List<WithBook<Highlight>>> watchAllHighlights({int? bookId, int? color}) {
    final q = db.select(db.highlights).join([
      innerJoin(db.books, db.books.id.equalsExp(db.highlights.bookId)),
    ]);
    if (bookId != null) q.where(db.highlights.bookId.equals(bookId));
    if (color != null) q.where(db.highlights.color.equals(color));
    q.orderBy([OrderingTerm.desc(db.highlights.createdAt)]);
    return q.watch().map((rows) => [
          for (final r in rows)
            WithBook(r.readTable(db.highlights), r.readTable(db.books).title),
        ]);
  }

  // --------------------------------------------------------------------- notes

  Future<int> addNote({
    required int bookId,
    required int page,
    required String passage,
    required String body,
    int? highlightId,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    return db.into(db.notes).insert(
          NotesCompanion.insert(
            bookId: bookId,
            page: page,
            passage: passage.trim(),
            body: body.trim(),
            highlightId: Value(highlightId),
            createdAt: t,
            updatedAt: t,
          ),
        );
  }

  Future<void> updateNote(int id, String body, {DateTime? now}) =>
      (db.update(db.notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(body: Value(body.trim()), updatedAt: Value(now ?? DateTime.now())),
      );

  Future<void> deleteNote(int id) => (db.delete(db.notes)..where((n) => n.id.equals(id))).go();

  Future<Note?> getNote(int id) =>
      (db.select(db.notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Stream<List<Note>> watchNotesForBook(int bookId) => (db.select(db.notes)
        ..where((n) => n.bookId.equals(bookId))
        ..orderBy([(n) => OrderingTerm.asc(n.page), (n) => OrderingTerm.desc(n.createdAt)]))
      .watch();

  Stream<List<WithBook<Note>>> watchAllNotes({int? bookId, String query = ''}) {
    final q = db.select(db.notes).join([
      innerJoin(db.books, db.books.id.equalsExp(db.notes.bookId)),
    ]);
    if (bookId != null) q.where(db.notes.bookId.equals(bookId));
    final text = query.trim();
    if (text.isNotEmpty) {
      final like = '%${text.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
      q.where(
        db.notes.body.like(like) | db.notes.passage.like(like) | db.books.title.like(like),
      );
    }
    q.orderBy([OrderingTerm.desc(db.notes.updatedAt)]);
    return q.watch().map((rows) => [
          for (final r in rows) WithBook(r.readTable(db.notes), r.readTable(db.books).title),
        ]);
  }

  // ----------------------------------------------------------------- bookmarks

  Future<int> addBookmark({
    required int bookId,
    required int page,
    required String title,
    required String previewText,
    bool isPassage = false,
    DateTime? now,
  }) =>
      db.into(db.bookmarks).insert(
            BookmarksCompanion.insert(
              bookId: bookId,
              page: page,
              title: title.trim(),
              previewText: previewText.trim(),
              isPassage: Value(isPassage),
              createdAt: now ?? DateTime.now(),
            ),
          );

  Future<void> renameBookmark(int id, String title) =>
      (db.update(db.bookmarks)..where((b) => b.id.equals(id)))
          .write(BookmarksCompanion(title: Value(title.trim())));

  Future<void> deleteBookmark(int id) =>
      (db.delete(db.bookmarks)..where((b) => b.id.equals(id))).go();

  /// Page (non-passage) bookmark on [page], if any.
  Future<Bookmark?> pageBookmark(int bookId, int page) => (db.select(db.bookmarks)
        ..where((b) => b.bookId.equals(bookId) & b.page.equals(page) & b.isPassage.equals(false))
        ..limit(1))
      .getSingleOrNull();

  /// Adds a page bookmark, or removes it if one exists. Returns true when the
  /// page is bookmarked afterwards.
  Future<bool> togglePageBookmark({
    required int bookId,
    required int page,
    required String previewText,
    DateTime? now,
  }) async {
    final existing = await pageBookmark(bookId, page);
    if (existing != null) {
      await deleteBookmark(existing.id);
      return false;
    }
    await addBookmark(
      bookId: bookId,
      page: page,
      title: 'Page $page',
      previewText: previewText,
      now: now,
    );
    return true;
  }

  Stream<List<Bookmark>> watchBookmarksForBook(int bookId) => (db.select(db.bookmarks)
        ..where((b) => b.bookId.equals(bookId))
        ..orderBy([(b) => OrderingTerm.asc(b.page)]))
      .watch();

  Stream<List<WithBook<Bookmark>>> watchAllBookmarks({int? bookId}) {
    final q = db.select(db.bookmarks).join([
      innerJoin(db.books, db.books.id.equalsExp(db.bookmarks.bookId)),
    ]);
    if (bookId != null) q.where(db.bookmarks.bookId.equals(bookId));
    q.orderBy([OrderingTerm.desc(db.bookmarks.createdAt)]);
    return q.watch().map((rows) => [
          for (final r in rows)
            WithBook(r.readTable(db.bookmarks), r.readTable(db.books).title),
        ]);
  }
}
