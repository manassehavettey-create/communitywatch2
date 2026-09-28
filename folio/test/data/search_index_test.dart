import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/db/database.dart';
import 'package:folio/data/logic/fts_query.dart';
import 'package:folio/data/repositories/books_repository.dart';
import 'package:folio/data/repositories/search_repository.dart';

import 'test_helpers.dart';

void main() {
  group('buildFtsQuery', () {
    test('words become required prefix terms', () {
      expect(buildFtsQuery('photo synth'), '"photo"* "synth"*');
    });
    test('quoted phrases stay phrases', () {
      expect(buildFtsQuery('"light reaction" leaf'), '"light reaction" "leaf"*');
    });
    test('FTS syntax in user input is neutralised', () {
      expect(buildFtsQuery('NEAR( a* OR "b'), '"near"* "a"* "or"* "b"*');
      expect(buildFtsQuery('  ***  '), isNull);
    });
    test('accented and non-latin text is kept', () {
      expect(buildFtsQuery('Café 東京'), '"café"* "東京"*');
    });
  });

  group('search repository', () {
    late AppDatabase db;
    late SearchRepository search;
    late int bookA;
    late int bookB;

    setUp(() async {
      db = newDb();
      search = SearchRepository(db);
      bookA = await seedBook(db, title: 'Plant Biology', sha: 'a');
      bookB = await seedBook(db, title: 'Physics', sha: 'b');
      await search.savePageTexts(bookA, const [
        PageExcerpt(1, 'Introduction to plants and their cells.'),
        PageExcerpt(2, 'Photosynthesis converts light energy into chemical energy.'),
        PageExcerpt(3, 'The light reaction happens in the thylakoid membrane.'),
      ]);
      await search.savePageTexts(bookB, const [
        PageExcerpt(1, 'Light behaves as both a particle and a wave.'),
      ]);
    });
    tearDown(() => db.close());

    test('finds words inside one book with page numbers, in page order', () async {
      final hits = await search.searchBook(bookA, 'light');
      expect(hits.map((h) => h.page), [2, 3]);
      expect(hits.every((h) => h.bookId == bookA), isTrue);
    });

    test('snippet marks the matched term', () async {
      final hits = await search.searchBook(bookA, 'thylakoid');
      expect(hits.single.snippet, contains('${kMatchStart}thylakoid$kMatchEnd'));
    });

    test('prefix matching and diacritics-insensitive matching', () async {
      expect((await search.searchBook(bookA, 'photo')).single.page, 2);
      await search.savePageTexts(bookA, const [PageExcerpt(4, 'Le café est prêt.')]);
      expect((await search.searchBook(bookA, 'cafe')).single.page, 4);
    });

    test('phrase search requires the words together', () async {
      expect((await search.searchBook(bookA, '"light reaction"')).single.page, 3);
      expect(await search.searchBook(bookA, '"energy light"'), isEmpty);
    });

    test('library search spans books', () async {
      final hits = await search.searchLibrary('light');
      expect(hits.map((h) => h.bookId).toSet(), {bookA, bookB});
      expect(hits.firstWhere((h) => h.bookId == bookB).bookTitle, 'Physics');
    });

    test('re-indexing a page replaces its old text', () async {
      await search.savePageTexts(bookA, const [PageExcerpt(2, 'Replaced text about roots.')]);
      expect(await search.searchBook(bookA, 'photosynthesis'), isEmpty);
      expect((await search.searchBook(bookA, 'roots')).single.page, 2);
      expect(await search.indexedPageCount(bookA), 3);
    });

    test('deleting a book removes it from the index', () async {
      await BooksRepository(db).deleteBook(bookA);
      expect(await search.searchLibrary('light'), hasLength(1));
      final rows = await db.customSelect('SELECT count(*) AS c FROM page_fts').getSingle();
      expect(rows.read<int>('c'), 1);
    });

    test('relevant pages rank by term overlap for grounding answers', () async {
      final pages = await search.relevantPages(bookA, 'Where does the light reaction happen?');
      expect(pages.first.page, 3);
    });

    test('page text is retrievable for Text view and ranges', () async {
      expect(await search.pageText(bookA, 2), startsWith('Photosynthesis'));
      final r = await search.pageRange(bookA, 2, 3);
      expect(r.map((e) => e.page), [2, 3]);
    });
  });
}
