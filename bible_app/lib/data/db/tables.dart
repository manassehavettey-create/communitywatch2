import 'package:drift/drift.dart';

/// Columns every synced row has. Times are UTC milliseconds.
///
/// Rows are never hard-deleted while signed in: [deletedAt] is a tombstone
/// that syncs, so a delete on one device reaches the others.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  IntColumn get createdAt => integer()();

  /// Set by the device that made the change; drives last-write-wins.
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Columns for anything anchored to Scripture. Refs are translation
/// independent ("JHN.3.16"); keys are sortable integers for range queries.
mixin RangeColumns on Table {
  TextColumn get startRef => text()();
  TextColumn get endRef => text()();
  IntColumn get startKey => integer()();
  IntColumn get endKey => integer()();
}

/// Synced reading preferences. One row, id [Preferences.rowId].
class Preferences extends Table with SyncColumns {
  static const rowId = 'preferences';

  TextColumn get translationId => text().nullable()();
  TextColumn get scriptureFont =>
      text().withDefault(const Constant('literata'))();
  RealColumn get fontSize => real().withDefault(const Constant(19))();
  RealColumn get lineHeight => real().withDefault(const Constant(1.65))();
  TextColumn get readerTheme => text().withDefault(const Constant('auto'))();
  TextColumn get appTheme => text().withDefault(const Constant('system'))();
  BoolColumn get showVerseNumbers =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get paragraphMode => boolean().withDefault(const Constant(true))();
  BoolColumn get suppliedItalics =>
      boolean().withDefault(const Constant(true))();

  /// Last reading position, for Continue Reading on every device.
  TextColumn get lastChapter => text().nullable()();
  IntColumn get lastVerse => integer().nullable()();
  IntColumn get lastReadAt => integer().nullable()();
}

class Bookmarks extends Table with SyncColumns, RangeColumns {
  TextColumn get translationId => text().nullable()();
}

class Highlights extends Table with SyncColumns, RangeColumns {
  TextColumn get color => text()();
}

class Notes extends Table with SyncColumns, RangeColumns {
  TextColumn get body => text()();
}

class SavedVerses extends Table with SyncColumns, RangeColumns {
  TextColumn get translationId => text()();

  /// Text as saved, so the Saved list renders without loading a Bible.
  TextColumn get snapshot => text()();
}

class PlanProgress extends Table with SyncColumns {
  TextColumn get planId => text()();

  /// active | paused | completed
  TextColumn get status => text()();

  /// Local calendar date the plan (re)started, yyyy-mm-dd.
  TextColumn get startDate => text()();
  TextColumn get pausedOn => text().nullable()();

  /// Days spent paused; the schedule shifts by this much.
  IntColumn get pausedDays => integer().withDefault(const Constant(0))();
  IntColumn get completedAt => integer().nullable()();
}

class PlanDayCompletions extends Table with SyncColumns {
  TextColumn get progressId => text()();
  IntColumn get day => integer()();
  IntColumn get completedAt => integer()();
}

/// One row per local calendar day with reading. id is the date (yyyy-mm-dd).
class ReadingActivity extends Table with SyncColumns {
  IntColumn get chapters => integer().withDefault(const Constant(0))();
  IntColumn get seconds => integer().withDefault(const Constant(0))();
}

/// One row per chapter ever read. id is the chapter code ("JHN.3").
class ChapterReads extends Table with SyncColumns {
  IntColumn get firstReadAt => integer()();
  IntColumn get lastReadAt => integer()();
  IntColumn get timesRead => integer().withDefault(const Constant(1))();
}

class Prayers extends Table with SyncColumns {
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get category => text()();

  /// Optional Scripture range code ("PHP.4.6-PHP.4.7").
  TextColumn get scriptureRef => text().nullable()();

  /// active | answered
  TextColumn get status => text().withDefault(const Constant('active'))();
  IntColumn get answeredAt => integer().nullable()();
  TextColumn get answerNote => text().nullable()();

  /// none | once | daily
  TextColumn get reminderKind => text().withDefault(const Constant('none'))();

  /// For "once": UTC ms. For "daily": minutes after local midnight.
  IntColumn get reminderValue => integer().nullable()();
}

class JournalEntries extends Table with SyncColumns {
  TextColumn get title => text()();
  TextColumn get body => text()();

  /// The day the entry is about (UTC ms of local midnight).
  IntColumn get entryDate => integer()();
  TextColumn get scriptureRef => text().nullable()();
}

class Tags extends Table with SyncColumns {
  TextColumn get name => text()();
}

class JournalEntryTags extends Table with SyncColumns {
  TextColumn get entryId => text()();
  TextColumn get tagId => text()();
}

/// Pending local changes to push. One row per changed entity.
class Outbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get entityTable => text()();
  TextColumn get entityId => text()();
  IntColumn get enqueuedAt => integer()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {entityTable, entityId},
  ];
}

/// Device-local settings and sync cursors (never synced).
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
