import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/db/database.dart';
import 'package:folio/data/repositories/books_repository.dart';
import 'package:folio/data/repositories/position_repository.dart';

import 'test_helpers.dart';

void main() {
  late AppDatabase db;
  late PositionRepository positions;
  late BooksRepository books;

  setUp(() {
    db = newDb();
    positions = PositionRepository(db);
    books = BooksRepository(db);
  });
  tearDown(() => db.close());

  test('no position until one is saved', () async {
    final id = await seedBook(db);
    expect(await positions.get(id), isNull);
  });

  test('saves and restores the exact page, in-page offset and zoom', () async {
    final id = await seedBook(db);
    await positions.save(id, page: 42, pageOffset: 0.375, zoom: 1.8);
    final p = await positions.get(id);
    expect(p!.page, 42);
    expect(p.pageOffset, closeTo(0.375, 1e-9));
    expect(p.zoom, closeTo(1.8, 1e-9));
  });

  test('later saves overwrite earlier ones (one row per book)', () async {
    final id = await seedBook(db);
    await positions.save(id, page: 3);
    await positions.save(id, page: 9, pageOffset: 0.5);
    final rows = await db.select(db.readingPositions).get();
    expect(rows, hasLength(1));
    expect(rows.single.page, 9);
    expect(rows.single.pageOffset, 0.5);
  });

  test('offset is clamped into 0..1 and zoom must be positive', () async {
    final id = await seedBook(db);
    await positions.save(id, page: 1, pageOffset: 7, zoom: 0);
    final p = await positions.get(id);
    expect(p!.pageOffset, 1);
    expect(p.zoom, 1);
  });

  test('positions are per book and removed with the book', () async {
    final a = await seedBook(db, sha: 'a');
    final b = await seedBook(db, sha: 'b');
    await positions.save(a, page: 10);
    await positions.save(b, page: 20);
    expect((await positions.get(a))!.page, 10);
    expect((await positions.get(b))!.page, 20);
    await books.deleteBook(a);
    expect(await positions.get(a), isNull);
    expect((await positions.get(b))!.page, 20);
  });

  test('reaching pages updates progress and finishes the book on the last page', () async {
    final id = await seedBook(db, pages: 10);
    await books.recordPageReached(id, 4);
    var book = (await books.getBook(id))!;
    expect(book.status, BookStatus.reading);
    expect(book.progress, closeTo(0.4, 1e-9));
    await books.recordPageReached(id, 2); // going back keeps the furthest page
    expect((await books.getBook(id))!.furthestPage, 4);
    await books.recordPageReached(id, 10);
    book = (await books.getBook(id))!;
    expect(book.status, BookStatus.finished);
    expect(book.finishedAt, isNotNull);
    expect(book.progress, 1);
  });
}
