import 'package:drift/drift.dart';

@DataClassName('SkillRow')
class Skills extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get description => text().nullable()();
  TextColumn get iconKey => text()();
  IntColumn get colorValue => integer()();
  RealColumn get targetHours => real().withDefault(const Constant(10000))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Minutes after local midnight.
  IntColumn get reminderMinutes =>
      integer().withDefault(const Constant(19 * 60))();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('SessionRow')
class PracticeSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get skillId =>
      integer().references(Skills, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime()();

  /// Local calendar day the session belongs to (see `Days`).
  IntColumn get dayKey => integer()();
  IntColumn get durationSec => integer()();
  TextColumn get note => text().nullable()();

  /// 'manual' or 'timer'.
  TextColumn get source => text().withDefault(const Constant('manual'))();
  DateTimeColumn get createdAt => dateTime()();
}

/// At most one row (id = 1). Persisting the start instant is what lets the
/// timer survive the app being backgrounded, killed or the phone rebooting.
@DataClassName('ActiveTimerRow')
class ActiveTimers extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get skillId =>
      integer().references(Skills, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('EntryRow')
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 'gratitude' or 'win'.
  TextColumn get type => text()();
  TextColumn get body => text()();
  TextColumn get mood => text().nullable()();
  IntColumn get skillId => integer()
      .nullable()
      .references(Skills, #id, onDelete: KeyAction.setNull)();
  IntColumn get dayKey => integer()();
  DateTimeColumn get createdAt => dateTime()();

  /// True for wins generated automatically from milestones.
  BoolColumn get isAuto => boolean().withDefault(const Constant(false))();

  /// For auto wins: `skillId:hours`, used to avoid duplicates and to
  /// remove the win if the milestone is un-reached (sessions deleted).
  TextColumn get milestoneRef => text().nullable()();
}

@DataClassName('TagRow')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

@DataClassName('EntryTagRow')
class EntryTags extends Table {
  IntColumn get entryId =>
      integer().references(Entries, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {entryId, tagId};
}

@DataClassName('MilestoneRow')
class Milestones extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get skillId =>
      integer().references(Skills, #id, onDelete: KeyAction.cascade)();
  IntColumn get hours => integer()();
  DateTimeColumn get achievedAt => dateTime()();
  IntColumn get dayKey => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {skillId, hours},
      ];
}

@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
