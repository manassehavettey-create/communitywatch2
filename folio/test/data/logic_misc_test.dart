import 'dart:ui';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/db/database.dart';
import 'package:folio/core/theme/reader_themes.dart';
import 'package:folio/data/repositories/books_repository.dart';
import 'package:folio/data/repositories/settings_repository.dart';
import 'package:folio/features/reader/reader_selection.dart';
import 'package:folio/features/reader/text_reader_view.dart';

Book _book(int id, String title, {String? author, BookStatus status = BookStatus.unread, int furthest = 0,
    bool fav = false, DateTime? opened, DateTime? added}) {
  return Book(
    id: id,
    title: title,
    author: author,
    originalFileName: '$title.pdf',
    filePath: '/x/$id.pdf',
    fileSize: 1,
    sha256: 'sha$id',
    pageCount: 100,
    coverAspect: 0.7,
    addedAt: added ?? DateTime(2026, 1, id),
    lastOpenedAt: opened,
    status: status,
    favorite: fav,
    furthestPage: furthest,
    indexStatus: IndexStatus.done,
    indexedPages: 100,
    textPages: 100,
  );
}

void main() {
  group('Text view reflow', () {
    test('keeps the exact length so offsets map onto PDF text', () {
      const raw = 'The quick brown fox\njumps over the lazy\ndog.\n\nA new paragraph starts here\nand continues.';
      final out = reflowPreservingIndices(raw);
      expect(out.length, raw.length);
      for (var i = 0; i < raw.length; i++) {
        if (raw[i] != '\n') expect(out[i], raw[i], reason: 'char $i changed');
      }
    });

    test('joins wrapped lines and keeps paragraph breaks', () {
      const raw = 'The quick brown fox\njumps over the lazy\ndog.\n\nNext paragraph.';
      final out = reflowPreservingIndices(raw);
      expect(out, startsWith('The quick brown fox jumps over the lazy dog.\n'));
      expect(out, contains('\n\nNext paragraph.'));
    });

    test('keeps list items on their own lines', () {
      const raw = 'Ingredients:\n• flour\n• water';
      expect(reflowPreservingIndices(raw), 'Ingredients:\n• flour\n• water');
    });
  });

  group('highlight geometry', () {
    test('word boxes on one line merge into a single bar', () {
      final merged = mergeLineRects(const [
        Rect.fromLTRB(10, 700, 40, 688),
        Rect.fromLTRB(44, 700, 90, 688),
        Rect.fromLTRB(94, 701, 130, 689),
        Rect.fromLTRB(10, 684, 60, 672), // next line
      ]);
      expect(merged, hasLength(2));
      expect(merged.first.left, 10);
      expect(merged.first.right, 130);
    });

    test('empty rects are dropped', () {
      expect(mergeLineRects(const [Rect.fromLTRB(5, 5, 5, 1)]), isEmpty);
    });
  });

  group('library sort & filter', () {
    final books = [
      _book(1, 'Walden', author: 'Thoreau', status: BookStatus.reading, furthest: 50, opened: DateTime(2026, 3, 1)),
      _book(2, 'Anna Karenina', author: 'Tolstoy', status: BookStatus.finished, fav: true),
      _book(3, 'Middlemarch', author: 'Eliot', opened: DateTime(2026, 3, 5)),
      _book(4, 'Notes', status: BookStatus.reading, furthest: 10),
    ];

    List<int> ids(List<Book> l) => l.map((b) => b.id).toList();

    test('filters', () {
      expect(ids(BooksRepository.sortAndFilter(books, sort: LibrarySort.title, filter: LibraryFilter.reading)), [4, 1]);
      expect(ids(BooksRepository.sortAndFilter(books, sort: LibrarySort.title, filter: LibraryFilter.finished)), [2]);
      expect(ids(BooksRepository.sortAndFilter(books, sort: LibrarySort.title, filter: LibraryFilter.unread)), [3]);
      expect(ids(BooksRepository.sortAndFilter(books, sort: LibrarySort.title, filter: LibraryFilter.favorites)), [2]);
    });

    test('sorts', () {
      expect(ids(BooksRepository.sortAndFilter(books, sort: LibrarySort.title, filter: LibraryFilter.all)), [2, 3, 4, 1]);
      expect(ids(BooksRepository.sortAndFilter(books, sort: LibrarySort.author, filter: LibraryFilter.all)), [3, 1, 2, 4]);
      expect(ids(BooksRepository.sortAndFilter(books, sort: LibrarySort.progress, filter: LibraryFilter.all)).first, 2);
      expect(ids(BooksRepository.sortAndFilter(books, sort: LibrarySort.recentlyOpened, filter: LibraryFilter.all)).take(2),
          [3, 1]);
      expect(ids(BooksRepository.sortAndFilter(books, sort: LibrarySort.recentlyAdded, filter: LibraryFilter.all)).first, 4);
    });

    test('search matches title, author and file name, case-insensitively', () {
      expect(ids(BooksRepository.sortAndFilter(books, sort: LibrarySort.title, filter: LibraryFilter.all, query: 'TOLST')),
          [2]);
      expect(ids(BooksRepository.sortAndFilter(books, sort: LibrarySort.title, filter: LibraryFilter.all, query: 'walden')),
          [1]);
    });
  });

  test('settings survive a JSON round trip and bad values fall back', () {
    const s = AppSettings(
      themeMode: ThemeMode.dark,
      readerTheme: ReaderTheme.sepia,
      viewMode: ReaderViewMode.text,
      fitMode: FitMode.page,
      textScale: 22,
      lineHeight: 1.8,
      dailyGoalMinutes: 45,
      reminderEnabled: true,
      reminderMinutes: 21 * 60,
      onboardingDone: true,
      name: 'Ama',
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());

    final bad = AppSettings.fromJson({'themeMode': 99, 'textScale': 400, 'name': 3});
    expect(bad.themeMode, ThemeMode.system);
    expect(bad.textScale, 28);
    expect(bad.name, '');
  });

  test('night page filter dims white pages and keeps hue (not a plain inversion)', () {
    final m = ReaderTheme.nightMatrix();
    List<int> apply(int r, int g, int b) => [
          for (var row = 0; row < 3; row++)
            (m[row * 5] * r + m[row * 5 + 1] * g + m[row * 5 + 2] * b + m[row * 5 + 4]).round().clamp(0, 255),
        ];
    expect(apply(255, 255, 255), [30, 28, 25]); // white page -> warm dark
    expect(apply(0, 0, 0), [217, 208, 191]); // black text -> warm light
    final red = apply(220, 40, 40);
    expect(red[0], greaterThan(red[1] + 40)); // red stays red, unlike a negative (cyan)
    expect(ReaderTheme.paper.pageFilter, isNull);
  });
}
