import 'package:drift/drift.dart';

import '../../core/db/database.dart';
import '../logic/fts_query.dart';

/// Marks the start / end of a matched term inside a snippet.
const String kMatchStart = '\u0001';
const String kMatchEnd = '\u0002';

class SearchHit {
  const SearchHit({required this.bookId, required this.bookTitle, required this.page, required this.snippet});

  final int bookId;
  final String bookTitle;
  final int page;

  /// Context around the match; matched terms are wrapped in
  /// [kMatchStart] / [kMatchEnd].
  final String snippet;
}

class PageExcerpt {
  const PageExcerpt(this.page, this.text);
  final int page;
  final String text;
}

class SearchRepository {
  SearchRepository(this.db);
  final AppDatabase db;

  /// Stores extracted page text (and thereby indexes it). Replaces any
  /// previous text for the same pages.
  Future<void> savePageTexts(int bookId, List<PageExcerpt> pages) async {
    if (pages.isEmpty) return;
    await db.batch((b) {
      b.insertAll(db.pageTexts, [
        for (final p in pages) PageTextsCompanion.insert(bookId: bookId, pageNumber: p.page, content: p.text),
      ], mode: InsertMode.insertOrReplace);
    });
  }

  Future<void> clearBook(int bookId) => (db.delete(db.pageTexts)..where((t) => t.bookId.equals(bookId))).go();

  Future<String?> pageText(int bookId, int page) async {
    final row = await (db.select(
      db.pageTexts,
    )..where((t) => t.bookId.equals(bookId) & t.pageNumber.equals(page))).getSingleOrNull();
    return row?.content;
  }

  Future<List<PageExcerpt>> pageRange(int bookId, int from, int to) async {
    final rows =
        await (db.select(db.pageTexts)
              ..where((t) => t.bookId.equals(bookId) & t.pageNumber.isBetweenValues(from, to))
              ..orderBy([(t) => OrderingTerm.asc(t.pageNumber)]))
            .get();
    return [for (final r in rows) PageExcerpt(r.pageNumber, r.content)];
  }

  Future<int> indexedPageCount(int bookId) async {
    final c = db.pageTexts.pageNumber.count();
    final q = db.selectOnly(db.pageTexts)
      ..addColumns([c])
      ..where(db.pageTexts.bookId.equals(bookId));
    return (await q.getSingle()).read(c) ?? 0;
  }

  /// Full-text search inside one book, in page order.
  Future<List<SearchHit>> searchBook(int bookId, String input, {int limit = 200}) =>
      _search(input, bookId: bookId, limit: limit, orderByRank: false);

  /// Full-text search across the whole library, best matches first.
  Future<List<SearchHit>> searchLibrary(String input, {int limit = 80}) =>
      _search(input, limit: limit, orderByRank: true);

  /// Pages of [bookId] most relevant to [question] (BM25), used to ground
  /// "Ask This Book" answers without sending the whole book.
  Future<List<PageExcerpt>> relevantPages(int bookId, String question, {int limit = 5}) async {
    // OR the terms together so partially matching pages still rank.
    final terms = queryTerms(question).where((t) => t.length > 2).toSet().toList();
    if (terms.isEmpty) return const [];
    final match = terms.map((t) => '"$t"*').join(' OR ');
    final rows = await db
        .customSelect(
          'SELECT t.page_number AS page, t.content AS content '
          'FROM page_fts JOIN page_texts t ON t.rowid = page_fts.rowid '
          'WHERE page_fts MATCH ?1 AND t.book_id = ?2 '
          'ORDER BY bm25(page_fts) LIMIT ?3',
          variables: [Variable.withString(match), Variable.withInt(bookId), Variable.withInt(limit)],
          readsFrom: {db.pageTexts},
        )
        .get();
    return [for (final r in rows) PageExcerpt(r.read<int>('page'), r.read<String>('content'))];
  }

  Future<List<SearchHit>> _search(String input, {int? bookId, required int limit, required bool orderByRank}) async {
    final match = buildFtsQuery(input);
    if (match == null) return const [];
    final where = StringBuffer('page_fts MATCH ?1');
    final vars = <Variable>[Variable.withString(match)];
    if (bookId != null) {
      where.write(' AND t.book_id = ?2');
      vars.add(Variable.withInt(bookId));
    }
    vars.add(Variable.withInt(limit));
    final limitIdx = vars.length;
    final order = orderByRank ? 'bm25(page_fts)' : 't.page_number';
    final rows = await db
        .customSelect(
          "SELECT t.book_id AS book_id, t.page_number AS page, b.title AS title, "
          "snippet(page_fts, 0, '$kMatchStart', '$kMatchEnd', '…', 14) AS snip "
          'FROM page_fts '
          'JOIN page_texts t ON t.rowid = page_fts.rowid '
          'JOIN books b ON b.id = t.book_id '
          'WHERE $where ORDER BY $order LIMIT ?$limitIdx',
          variables: vars,
          readsFrom: {db.pageTexts, db.books},
        )
        .get();
    return [
      for (final r in rows)
        SearchHit(
          bookId: r.read<int>('book_id'),
          bookTitle: r.read<String>('title'),
          page: r.read<int>('page'),
          snippet: r.read<String>('snip').replaceAll(RegExp(r'\s+'), ' ').trim(),
        ),
    ];
  }
}
