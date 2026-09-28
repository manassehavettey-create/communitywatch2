import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/db/database.dart';
import 'package:folio/core/pdf/library_storage.dart';
import 'package:folio/core/pdf/pdf_metadata.dart';
import 'package:folio/data/repositories/books_repository.dart';
import 'package:folio/data/repositories/search_repository.dart';
import 'package:folio/data/services/import_service.dart';
import 'package:folio/data/services/indexing_service.dart';
import 'package:pdfrx/pdfrx.dart';

import 'test_helpers.dart';

/// Exercises the real PDFium pipeline against generated fixtures.
/// Set FOLIO_LARGE_PDF=/path/to/large_book.pdf to also run the large-file test.
void main() {
  late AppDatabase db;
  late Directory tmp;
  late ImportService importer;
  late IndexingService indexer;
  late BooksRepository books;
  late SearchRepository search;

  setUpAll(() async {
    Pdfrx.pdfiumModulePath = findPdfiumForTests();
    Pdfrx.cacheDirectoryPath = (await Directory.systemTemp.createTemp('pdfrx')).path;
    await PdfrxEntryFunctions.instance.init();
  });

  setUp(() async {
    db = newDb();
    tmp = await Directory.systemTemp.createTemp('folio_lib');
    final storage = LibraryStorage(tmp);
    await storage.booksDir.create(recursive: true);
    await storage.coversDir.create(recursive: true);
    books = BooksRepository(db);
    search = SearchRepository(db);
    indexer = IndexingService(db: db, books: books, search: search);
    importer = ImportService(books: books, storage: storage, indexer: indexer);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> idle() async {
    while (indexer.isBusy) {
      await indexer.onIdle.first;
    }
  }

  testWidgets('imports a PDF: metadata, cover, page count, outline and search index',
      (tester) async {
    await tester.runAsync(() async {
      final r = await importer.importFile('test/fixtures/sample_book.pdf', 'sample_book.pdf');
      expect(r.outcome, ImportOutcome.added, reason: r.message);
      final book = (await books.getBook(r.bookId!))!;
      expect(book.title, 'The Quiet Garden');
      expect(book.author, 'Ada Winters');
      expect(book.pageCount, 12);
      expect(book.coverPath, isNotNull);
      expect(File(book.coverPath!).lengthSync(), greaterThan(1000));
      expect(File(book.filePath).existsSync(), isTrue);

      await idle();
      final indexed = (await books.getBook(book.id))!;
      expect(indexed.indexStatus, IndexStatus.done);
      expect(indexed.indexedPages, 12);
      expect(indexed.textPages, 12);

      final hits = await search.searchBook(book.id, 'thylakoid');
      expect(hits.single.page, 6);
      final outline = await db.outlineFor(book.id);
      expect(outline.map((o) => (o.title, o.page)).toList(), [
        ('Chapter 1 · Seeds', 1),
        ('Chapter 2 · Light', 5),
        ('Chapter 3 · Harvest', 9),
      ]);
    });
  });

  testWidgets('duplicate imports are detected by content', (tester) async {
    await tester.runAsync(() async {
      final a = await importer.importFile('test/fixtures/sample_book.pdf', 'a.pdf');
      final copy = File('${tmp.path}/renamed copy.pdf');
      await File('test/fixtures/sample_book.pdf').copy(copy.path);
      final b = await importer.importFile(copy.path, 'renamed copy.pdf');
      expect(b.outcome, ImportOutcome.duplicate);
      expect(b.bookId, a.bookId);
      expect(await db.select(db.books).get(), hasLength(1));
      await idle();
    });
  });

  testWidgets('image-only PDFs import but are marked as having no text', (tester) async {
    await tester.runAsync(() async {
      final r = await importer.importFile('test/fixtures/scanned.pdf', 'Scan 2024-03.pdf');
      expect(r.outcome, ImportOutcome.added);
      await idle();
      final book = (await books.getBook(r.bookId!))!;
      expect(book.indexStatus, IndexStatus.noText);
      expect(book.isScanned, isTrue);
      expect(book.title, 'Scan 2024-03');
    });
  });

  testWidgets('PDFs without metadata fall back to the file name', (tester) async {
    await tester.runAsync(() async {
      final r = await importer.importFile('test/fixtures/untitled.pdf', 'deep_work_notes.pdf');
      final book = (await books.getBook(r.bookId!))!;
      expect(book.title, 'Deep work notes');
      expect(book.author, isNull);
      await idle();
    });
  });

  testWidgets('non-PDF files are rejected without copying anything', (tester) async {
    await tester.runAsync(() async {
      final f = File('${tmp.path}/notes.txt')..writeAsStringSync('hello');
      final r = await importer.importFile(f.path, 'notes.txt');
      expect(r.outcome, ImportOutcome.failed);
      expect(r.message, contains("isn't a PDF"));
      expect(await db.select(db.books).get(), isEmpty);
    });
  });

  test('title heuristics', () {
    expect(chooseTitle('Microsoft Word - draft.docx', 'Essay.pdf'), 'Essay');
    expect(chooseTitle('Untitled', 'my_notes.pdf'), 'My notes');
    expect(chooseTitle('Walden', 'x.pdf'), 'Walden');
    expect(chooseTitle(null, 'report-2024.PDF'), 'Report-2024');
  });

  final largePath = Platform.environment['FOLIO_LARGE_PDF'];
  testWidgets('large PDF (1,200 pages, ~25 MB) imports and indexes', (tester) async {
    await tester.runAsync(() async {
      final sw = Stopwatch()..start();
      final r = await importer.importFile(largePath!, 'large_book.pdf');
      final importMs = sw.elapsedMilliseconds;
      expect(r.outcome, ImportOutcome.added, reason: r.message);
      await idle();
      final indexMs = sw.elapsedMilliseconds - importMs;
      final book = (await books.getBook(r.bookId!))!;
      expect(book.pageCount, 1200);
      expect(book.indexStatus, IndexStatus.done);
      final hits = await search.searchBook(book.id, '"seven hundred seventy seven"');
      expect(hits.single.page, 777);
      expect((await db.outlineFor(book.id)), hasLength(40));
      final searchSw = Stopwatch()..start();
      await search.searchBook(book.id, 'lantern');
      // ignore: avoid_print
      print('large PDF: import ${importMs}ms, index ${indexMs}ms, '
          'search ${searchSw.elapsedMilliseconds}ms');
    });
  }, skip: largePath == null, timeout: const Timeout(Duration(minutes: 5)));
}
