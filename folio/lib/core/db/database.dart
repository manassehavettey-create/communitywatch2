import 'package:drift/drift.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Books,
    ReadingPositions,
    PageTexts,
    OutlineEntries,
    Highlights,
    Notes,
    Bookmarks,
    Collections,
    CollectionBooks,
    ReadingSessions,
    DailyActivities,
    AiAnswers,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createSearchIndex();
      await customStatement('CREATE INDEX IF NOT EXISTS idx_highlights_book_page ON highlights(book_id, page)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_notes_book ON notes(book_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_bookmarks_book ON bookmarks(book_id, page)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_sessions_book ON reading_sessions(book_id)');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// External-content FTS5 index over `page_texts`, kept in sync by triggers.
  /// Built once per book at import; searches never touch the PDF.
  Future<void> _createSearchIndex() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS page_fts USING fts5(
        content,
        content='page_texts',
        content_rowid='rowid',
        tokenize='unicode61 remove_diacritics 2'
      )''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS page_texts_ai AFTER INSERT ON page_texts BEGIN
        INSERT INTO page_fts(rowid, content) VALUES (new.rowid, new.content);
      END''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS page_texts_ad AFTER DELETE ON page_texts BEGIN
        INSERT INTO page_fts(page_fts, rowid, content) VALUES ('delete', old.rowid, old.content);
      END''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS page_texts_au AFTER UPDATE ON page_texts BEGIN
        INSERT INTO page_fts(page_fts, rowid, content) VALUES ('delete', old.rowid, old.content);
        INSERT INTO page_fts(rowid, content) VALUES (new.rowid, new.content);
      END''');
  }
}
