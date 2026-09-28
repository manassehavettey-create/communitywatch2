import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// Tables that sync to Supabase, in push order (parents before children).
/// Local and remote table names are identical.
const syncedTables = <String>[
  'preferences',
  'bookmarks',
  'highlights',
  'notes',
  'saved_verses',
  'plan_progress',
  'plan_day_completions',
  'reading_activity',
  'chapter_reads',
  'prayers',
  'journal_entries',
  'tags',
  'journal_entry_tags',
];

@DriftDatabase(
  tables: [
    Preferences,
    Bookmarks,
    Highlights,
    Notes,
    SavedVerses,
    PlanProgress,
    PlanDayCompletions,
    ReadingActivity,
    ChapterReads,
    Prayers,
    JournalEntries,
    Tags,
    JournalEntryTags,
    Outbox,
    KeyValues,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the on-device database (SQLite on mobile, OPFS/IndexedDB on web).
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'bible_app',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      for (final sql in _indexes) {
        await customStatement(sql);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static const _indexes = [
    'CREATE INDEX idx_highlights_range ON highlights (start_key, end_key)',
    'CREATE INDEX idx_notes_range ON notes (start_key, end_key)',
    'CREATE INDEX idx_bookmarks_range ON bookmarks (start_key, end_key)',
    'CREATE INDEX idx_saved_range ON saved_verses (start_key, end_key)',
    'CREATE INDEX idx_plan_days ON plan_day_completions (progress_id, day)',
    'CREATE INDEX idx_journal_date ON journal_entries (entry_date)',
    'CREATE INDEX idx_entry_tags ON journal_entry_tags (entry_id, tag_id)',
  ];

  /// Looks up a synced table by its SQL name.
  TableInfo<Table, dynamic> syncTable(String name) {
    for (final t in allTables) {
      if (t.actualTableName == name) return t;
    }
    throw ArgumentError.value(name, 'name', 'Unknown table');
  }

  // --- Device-local key/value settings -----------------------------------

  Future<String?> getValue(String key) async {
    final row = await (select(
      keyValues,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchValue(String key) => (select(
    keyValues,
  )..where((t) => t.key.equals(key))).watchSingleOrNull().map((r) => r?.value);

  Future<void> setValue(String key, String? value) async {
    if (value == null) {
      await (delete(keyValues)..where((t) => t.key.equals(key))).go();
    } else {
      await into(keyValues)
          .insertOnConflictUpdate(KeyValue(key: key, value: value));
    }
  }
}
