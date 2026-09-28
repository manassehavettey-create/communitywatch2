import 'package:drift/drift.dart';

/// Reading status of a book. Persisted by index — only append.
enum BookStatus { unread, reading, finished }

/// State of the per-book full-text index. Persisted by index — only append.
enum IndexStatus { pending, indexing, done, noText, failed }

/// Page theme / view mode enums live in the reader feature; the DB stores ints.

@DataClassName('Book')
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get originalFileName => text()();

  /// Absolute path of Folio's private copy of the PDF.
  TextColumn get filePath => text()();
  IntColumn get fileSize => integer()();

  /// SHA-256 of the file contents; used to detect duplicate imports.
  TextColumn get sha256 => text().unique()();
  IntColumn get pageCount => integer()();
  TextColumn get coverPath => text().nullable()();

  /// Aspect ratio (width / height) of the first page, for cover layout.
  RealColumn get coverAspect => real().withDefault(const Constant(0.7071))();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  /// Last time reading time was actually logged for this book.
  DateTimeColumn get lastReadAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  IntColumn get status => intEnum<BookStatus>().withDefault(const Constant(0))();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();

  /// Highest page the reader has reached (1-based); drives progress.
  IntColumn get furthestPage => integer().withDefault(const Constant(0))();
  IntColumn get indexStatus => intEnum<IndexStatus>().withDefault(const Constant(0))();
  IntColumn get indexedPages => integer().withDefault(const Constant(0))();

  /// Number of pages that contained any extractable text.
  IntColumn get textPages => integer().withDefault(const Constant(0))();
}

/// Exact last reading position per book.
@DataClassName('ReadingPosition')
class ReadingPositions extends Table {
  IntColumn get bookId => integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get page => integer()();

  /// Vertical position inside [page] of the viewport's top edge, 0..1.
  RealColumn get pageOffset => real().withDefault(const Constant(0))();

  /// Zoom factor relative to "fit" (1.0 = fit).
  RealColumn get zoom => real().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {bookId};
}

/// Extracted plain text per page. Backs the FTS5 index `page_fts`
/// (created in migration) and the reflowed Text view.
@DataClassName('PageText')
class PageTexts extends Table {
  IntColumn get bookId => integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get pageNumber => integer()();
  TextColumn get content => text()();

  @override
  Set<Column> get primaryKey => {bookId, pageNumber};
}

/// Table of contents entries from the PDF outline.
@DataClassName('OutlineEntry')
class OutlineEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get title => text()();
  IntColumn get page => integer()();
  IntColumn get level => integer()();
}

@DataClassName('Highlight')
class Highlights extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get page => integer()();
  TextColumn get content => text()();

  /// Index into ShelfColor.
  IntColumn get color => integer()();

  /// Character range in the page text: [startIndex, endIndex) .
  IntColumn get startIndex => integer()();
  IntColumn get endIndex => integer()();

  /// JSON list of [left, top, right, bottom] rects in PDF page points
  /// (origin bottom-left), used to paint the highlight without re-reading
  /// page text.
  TextColumn get rects => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('Note')
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get highlightId =>
      integer().nullable().references(Highlights, #id, onDelete: KeyAction.setNull)();
  IntColumn get page => integer()();
  TextColumn get passage => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('Bookmark')
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get page => integer()();
  TextColumn get title => text()();
  TextColumn get previewText => text()();

  /// True when created from a text selection (a passage bookmark).
  BoolColumn get isPassage => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('Collection')
class Collections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('CollectionBook')
class CollectionBooks extends Table {
  IntColumn get collectionId =>
      integer().references(Collections, #id, onDelete: KeyAction.cascade)();
  IntColumn get bookId => integer().references(Books, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {collectionId, bookId};
}

@DataClassName('ReadingSession')
class ReadingSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer().references(Books, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  IntColumn get startPage => integer()();
  IntColumn get endPage => integer()();
  IntColumn get pagesRead => integer()();
  IntColumn get seconds => integer()();

  /// Target length for a focus session, null for normal reading.
  IntColumn get targetMinutes => integer().nullable()();
}

/// Per-day reading totals (local calendar day, `yyyy-MM-dd`). Kept even when
/// a book is deleted so streaks and history survive.
@DataClassName('DailyActivity')
class DailyActivities extends Table {
  TextColumn get day => text()();
  IntColumn get pagesRead => integer().withDefault(const Constant(0))();
  IntColumn get seconds => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {day};
}

/// Locally cached AI answers so repeat questions don't hit the network.
@DataClassName('AiAnswer')
class AiAnswers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();
  TextColumn get scope => text()();
  TextColumn get question => text()();
  TextColumn get answer => text()();

  /// JSON list of cited page numbers.
  TextColumn get pages => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
}

/// Simple key/value settings.
@DataClassName('Setting')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
