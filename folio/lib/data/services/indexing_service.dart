import 'dart:async';
import 'dart:collection';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:pdfrx/pdfrx.dart';

import '../../core/db/database.dart';
import '../repositories/books_repository.dart';
import '../repositories/search_repository.dart';

/// Builds each book's local full-text index once, right after import.
///
/// Text is extracted page by page on pdfrx's PDFium worker isolate and saved
/// in small batches, so memory stays flat for books with thousands of pages
/// and the UI thread is never blocked. Progress is written to the `books`
/// row (indexedPages) so the UI can show it reactively.
class IndexingService {
  IndexingService({required this.db, required this.books, required this.search});

  final AppDatabase db;
  final BooksRepository books;
  final SearchRepository search;

  static const int _batchSize = 16;

  /// Pages with fewer meaningful characters than this are treated as
  /// image-only (scanned) pages.
  static const int _minTextChars = 12;

  final Queue<int> _queue = Queue<int>();
  bool _running = false;
  final _idle = StreamController<void>.broadcast();

  /// Emits whenever the queue drains.
  Stream<void> get onIdle => _idle.stream;
  bool get isBusy => _running || _queue.isNotEmpty;

  void enqueue(int bookId) {
    if (_queue.contains(bookId)) return;
    _queue.add(bookId);
    _pump();
  }

  /// Picks up books whose indexing was interrupted (e.g. the app was closed).
  Future<void> resumePending() async {
    for (final b in await books.booksNeedingIndex()) {
      enqueue(b.id);
    }
  }

  Future<void> reindex(int bookId) async {
    await search.clearBook(bookId);
    await (db.delete(db.outlineEntries)..where((o) => o.bookId.equals(bookId))).go();
    await books.setIndexState(bookId, IndexStatus.pending, indexedPages: 0, textPages: 0);
    enqueue(bookId);
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty) {
        final id = _queue.removeFirst();
        await _indexBook(id);
      }
    } finally {
      _running = false;
      _idle.add(null);
    }
  }

  Future<void> _indexBook(int bookId) async {
    final book = await books.getBook(bookId);
    if (book == null) return;
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(book.filePath);
      final total = doc.pages.length;
      final start = await search.indexedPageCount(bookId);
      var textPages = book.textPages;
      await books.setIndexState(bookId, IndexStatus.indexing, indexedPages: start);

      if (start == 0) await _saveOutline(bookId, doc);

      final batch = <PageExcerpt>[];
      for (var i = start; i < total; i++) {
        final page = doc.pages[i];
        final text = await page.loadStructuredText();
        final content = text.fullText;
        if (content.replaceAll(RegExp(r'\s'), '').length >= _minTextChars) textPages++;
        batch.add(PageExcerpt(i + 1, content));
        if (batch.length >= _batchSize || i == total - 1) {
          // Stop quietly if the book was deleted mid-way.
          if (await books.getBook(bookId) == null) return;
          await search.savePageTexts(bookId, List.of(batch));
          batch.clear();
          await books.setIndexState(
            bookId,
            IndexStatus.indexing,
            indexedPages: i + 1,
            textPages: textPages,
          );
        }
      }
      await books.setIndexState(
        bookId,
        textPages == 0 ? IndexStatus.noText : IndexStatus.done,
        indexedPages: total,
        textPages: textPages,
      );
    } catch (_) {
      if (await books.getBook(bookId) != null) {
        await books.setIndexState(bookId, IndexStatus.failed);
      }
    } finally {
      await doc?.dispose();
    }
  }

  Future<void> _saveOutline(int bookId, PdfDocument doc) async {
    List<PdfOutlineNode> nodes;
    try {
      nodes = await doc.loadOutline();
    } catch (_) {
      return;
    }
    final rows = <OutlineEntriesCompanion>[];
    void walk(List<PdfOutlineNode> list, int level) {
      for (final n in list) {
        final page = n.dest?.pageNumber;
        final title = n.title.trim();
        if (page != null && page >= 1 && title.isNotEmpty) {
          rows.add(OutlineEntriesCompanion.insert(
            bookId: bookId,
            position: rows.length,
            title: title,
            page: page,
            level: level,
          ));
        }
        walk(n.children, level + 1);
      }
    }

    walk(nodes, 0);
    await (db.delete(db.outlineEntries)..where((o) => o.bookId.equals(bookId))).go();
    if (rows.isEmpty) return;
    await db.batch((b) => b.insertAll(db.outlineEntries, rows));
  }

  void dispose() => _idle.close();
}

/// Reads the saved outline.
extension OutlineQueries on AppDatabase {
  Future<List<OutlineEntry>> outlineFor(int bookId) => (select(outlineEntries)
        ..where((o) => o.bookId.equals(bookId))
        ..orderBy([(o) => OrderingTerm.asc(o.position)]))
      .get();
}
