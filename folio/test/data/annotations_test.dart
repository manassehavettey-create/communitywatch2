import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/db/database.dart';
import 'package:folio/data/repositories/annotations_repository.dart';
import 'package:folio/data/repositories/books_repository.dart';

import 'test_helpers.dart';

void main() {
  late AppDatabase db;
  late AnnotationsRepository repo;
  late int book;

  setUp(() async {
    db = newDb();
    repo = AnnotationsRepository(db);
    book = await seedBook(db, title: 'Walden');
  });
  tearDown(() => db.close());

  group('highlights', () {
    test('create, read with rects, recolor, delete', () async {
      final id = await repo.addHighlight(
        bookId: book,
        page: 12,
        content: '  I went to the woods  ',
        color: 2,
        startIndex: 10,
        endIndex: 30,
        rects: const [Rect.fromLTRB(10, 700, 200, 688)],
        now: DateTime(2026, 5, 1),
      );
      var h = (await repo.getHighlight(id))!;
      expect(h.content, 'I went to the woods');
      expect(h.page, 12);
      expect(h.createdAt, DateTime(2026, 5, 1));
      expect(decodeRects(h.rects), const [Rect.fromLTRB(10, 700, 200, 688)]);

      await repo.setHighlightColor(id, 4);
      h = (await repo.getHighlight(id))!;
      expect(h.color, 4);

      final all = await repo.watchAllHighlights().first;
      expect(all.single.bookTitle, 'Walden');
      expect((await repo.watchAllHighlights(color: 1).first), isEmpty);

      await repo.deleteHighlight(id);
      expect(await repo.getHighlight(id), isNull);
    });

    test('ordered by page within a book', () async {
      for (final p in [30, 5, 18]) {
        await repo.addHighlight(
            bookId: book, page: p, content: 'x', color: 0, startIndex: 0, endIndex: 1, rects: const []);
      }
      final list = await repo.watchHighlightsForBook(book).first;
      expect(list.map((h) => h.page), [5, 18, 30]);
    });

    test('decodeRects tolerates bad data', () {
      expect(decodeRects('not json'), isEmpty);
    });
  });

  group('notes', () {
    test('create, edit, search, filter by book, delete', () async {
      final other = await seedBook(db, title: 'Other', sha: 'o');
      final id = await repo.addNote(
        bookId: book,
        page: 3,
        passage: 'Simplify, simplify.',
        body: 'Main theme of the chapter',
        now: DateTime(2026, 5, 1),
      );
      await repo.addNote(bookId: other, page: 1, passage: 'p', body: 'unrelated');

      await repo.updateNote(id, 'Main theme — minimalism', now: DateTime(2026, 5, 2));
      final n = (await repo.getNote(id))!;
      expect(n.body, 'Main theme — minimalism');
      expect(n.updatedAt, DateTime(2026, 5, 2));
      expect(n.createdAt, DateTime(2026, 5, 1));

      expect((await repo.watchAllNotes(query: 'minimal').first).single.item.id, id);
      expect((await repo.watchAllNotes(query: 'simplify').first).single.item.id, id);
      expect((await repo.watchAllNotes(query: 'walden').first).single.item.id, id);
      expect(await repo.watchAllNotes(bookId: other).first, hasLength(1));
      expect(await repo.watchAllNotes(query: '100%').first, isEmpty);

      await repo.deleteNote(id);
      expect(await repo.getNote(id), isNull);
    });

    test('note survives deleting its highlight', () async {
      final h = await repo.addHighlight(
          bookId: book, page: 1, content: 'x', color: 0, startIndex: 0, endIndex: 1, rects: const []);
      final n = await repo.addNote(bookId: book, page: 1, passage: 'x', body: 'y', highlightId: h);
      await repo.deleteHighlight(h);
      final note = (await repo.getNote(n))!;
      expect(note.highlightId, isNull);
    });
  });

  group('bookmarks', () {
    test('toggle page bookmark on and off', () async {
      expect(await repo.togglePageBookmark(bookId: book, page: 7, previewText: 'Where I lived'), isTrue);
      final b = (await repo.pageBookmark(book, 7))!;
      expect(b.title, 'Page 7');
      expect(b.previewText, 'Where I lived');
      expect(await repo.togglePageBookmark(bookId: book, page: 7, previewText: ''), isFalse);
      expect(await repo.pageBookmark(book, 7), isNull);
    });

    test('passage bookmarks are separate from the page bookmark', () async {
      await repo.addBookmark(
          bookId: book, page: 7, title: 'Great line', previewText: 'text', isPassage: true);
      expect(await repo.pageBookmark(book, 7), isNull);
      final id = (await repo.watchBookmarksForBook(book).first).single.id;
      await repo.renameBookmark(id, 'Renamed');
      expect((await repo.watchAllBookmarks().first).single.item.title, 'Renamed');
      await repo.deleteBookmark(id);
      expect(await repo.watchAllBookmarks().first, isEmpty);
    });
  });

  test('counts and cascade delete with the book', () async {
    await repo.addHighlight(
        bookId: book, page: 1, content: 'x', color: 0, startIndex: 0, endIndex: 1, rects: const []);
    await repo.addNote(bookId: book, page: 1, passage: 'x', body: 'y');
    await repo.addBookmark(bookId: book, page: 1, title: 't', previewText: 'p');
    final books = BooksRepository(db);
    final c = await books.watchCounts(book).first;
    expect([c.highlights, c.notes, c.bookmarks], [1, 1, 1]);
    await books.deleteBook(book);
    expect(await db.select(db.highlights).get(), isEmpty);
    expect(await db.select(db.notes).get(), isEmpty);
    expect(await db.select(db.bookmarks).get(), isEmpty);
  });
}
