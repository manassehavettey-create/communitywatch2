import 'package:drift/drift.dart';

/// Columns every synced, user-owned table has. SQL names are snake_case and
/// match the Supabase migrations exactly, so rows map 1:1 during sync.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ProfileRow')
class Profiles extends Table with SyncColumns {
  TextColumn get name => text()();
  IntColumn get age => integer()();
  TextColumn get sex => text()();
  RealColumn get heightCm => real()();
  RealColumn get weightKg => real()();
  TextColumn get fitnessLevel => text()();
  TextColumn get experience => text()();
  IntColumn get daysPerWeek => integer()();
  IntColumn get sessionMinutes => integer()();
  TextColumn get environment => text()();
  TextColumn get limitations => text().withDefault(const Constant('{}'))();
  TextColumn get preferredDays => text().withDefault(const Constant('[]'))();
  TextColumn get workoutStyle => text()();
  TextColumn get pushAbility => text()();
  TextColumn get squatAbility => text()();
  TextColumn get plankAbility => text()();
  TextColumn get journeyStart => text()();
}

@DataClassName('GoalRow')
class Goals extends Table with SyncColumns {
  TextColumn get goal => text()();
}

@DataClassName('ProgramRow')
class Programs extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get source => text()(); // generated | custom
  TextColumn get goals => text()(); // json list
  IntColumn get daysPerWeek => integer()();
  IntColumn get minutes => integer()();
  TextColumn get focus => text().withDefault(const Constant('[]'))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get startedOn => text()();
}

@DataClassName('ProgramDayRow')
class ProgramDays extends Table with SyncColumns {
  TextColumn get programId => text()();
  IntColumn get weekday => integer()();
  TextColumn get dayType => text()();
}

@DataClassName('WorkoutRow')
class Workouts extends Table with SyncColumns {
  TextColumn get programId => text().nullable()();
  TextColumn get date => text()(); // local yyyy-MM-dd
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  TextColumn get dayType => text()();
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get plan => text()(); // json
  TextColumn get rating => text().nullable()();
  IntColumn get durationSec => integer()();
  IntColumn get totalReps => integer().withDefault(const Constant(0))();
  IntColumn get journeyWeek => integer().nullable()();
  TextColumn get recoveryCheckId => text().nullable()();
}

@DataClassName('WorkoutSetRow')
class WorkoutSets extends Table with SyncColumns {
  TextColumn get workoutId => text()();
  TextColumn get exerciseId => text()();
  TextColumn get trackKey => text().nullable()();
  TextColumn get block => text()();
  IntColumn get setIndex => integer()();
  IntColumn get target => integer()();
  IntColumn get achieved => integer()();
  BoolColumn get skipped => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

@DataClassName('PersonalRecordRow')
class PersonalRecords extends Table with SyncColumns {
  TextColumn get exerciseId => text()();
  TextColumn get metric => text()();
  IntColumn get value => integer()();
  IntColumn get previousValue => integer().nullable()();
  TextColumn get workoutId => text().nullable()();
  TextColumn get achievedOn => text()();
}

@DataClassName('MeasurementRow')
class Measurements extends Table with SyncColumns {
  TextColumn get type => text()();
  TextColumn get label => text().nullable()();
  RealColumn get value => real()(); // metric: kg / cm
  TextColumn get measuredOn => text()();
}

@DataClassName('SkillProgressRow')
class SkillProgress extends Table with SyncColumns {
  TextColumn get trackKey => text()();
  IntColumn get nodeIndex => integer()();
  IntColumn get sets => integer()();
  IntColumn get amount => integer()();
  IntColumn get easyStreak => integer().withDefault(const Constant(0))();
  IntColumn get hardStreak => integer().withDefault(const Constant(0))();
  IntColumn get bestNode => integer().nullable()();
}

@DataClassName('RecoveryCheckRow')
class RecoveryChecks extends Table with SyncColumns {
  TextColumn get date => text()();
  TextColumn get sleep => text()();
  TextColumn get soreness => text()();
  TextColumn get energy => text()();
  IntColumn get score => integer()();
  TextColumn get mode => text()();
}

@DataClassName('ChallengeProgressRow')
class ChallengeProgress extends Table with SyncColumns {
  TextColumn get challengeId => text()();
  TextColumn get startedOn => text()();
  TextColumn get completedOn => text().nullable()();
  BoolColumn get abandoned => boolean().withDefault(const Constant(false))();
}

@DataClassName('ChallengeCheckinRow')
class ChallengeCheckins extends Table with SyncColumns {
  TextColumn get progressId => text()();
  TextColumn get date => text()();
  RealColumn get value => real()();
  TextColumn get detail => text().nullable()(); // json (e.g. the GH₵20 meal)
}

@DataClassName('UserAchievementRow')
class UserAchievements extends Table with SyncColumns {
  TextColumn get achievementId => text()();
  DateTimeColumn get unlockedAt => dateTime()();
}

@DataClassName('JourneyProgressRow')
class JourneyProgress extends Table with SyncColumns {
  TextColumn get startDate => text()();
  IntColumn get currentWeek => integer()();
  IntColumn get countedWeeks => integer()();
  TextColumn get completedOn => text().nullable()();
  TextColumn get startNodes => text().withDefault(const Constant('{}'))(); // json
}

@DataClassName('MilestoneRow')
class Milestones extends Table with SyncColumns {
  TextColumn get date => text()();
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get trackKey => text().nullable()();
  TextColumn get exerciseId => text().nullable()();
}

@DataClassName('FoodPriceRow')
class FoodPrices extends Table with SyncColumns {
  TextColumn get foodId => text()();
  RealColumn get price => real()();
}

// ───────────────────────── local-only tables ─────────────────────────

/// Pending changes to push. One entry per (table, row): later writes to the
/// same row replace the entry, so days offline push only the final state.
@DataClassName('OutboxRow')
class SyncOutbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get tableName_ => text().named('table_name')();
  TextColumn get rowId => text()();
  DateTimeColumn get queuedAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {tableName_, rowId}
      ];
}

/// Pull cursors (server `synced_at`) per table.
@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  TextColumn get tableName_ => text().named('table_name')();
  DateTimeColumn get lastPulledAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {tableName_};
}

/// The running workout (player snapshot JSON) so it survives the app being killed.
@DataClassName('ActiveSessionRow')
class ActiveSessions extends Table {
  TextColumn get userId => text()();
  TextColumn get snapshot => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId};
}
