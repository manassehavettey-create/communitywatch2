import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Skills,
    PracticeSessions,
    ActiveTimers,
    Entries,
    Tags,
    EntryTags,
    Milestones,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The on-device database file.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'growth_log'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX idx_sessions_skill_day ON practice_sessions (skill_id, day_key)',
      );
      await customStatement(
        'CREATE INDEX idx_sessions_day ON practice_sessions (day_key)',
      );
      await customStatement(
        'CREATE INDEX idx_entries_day ON entries (day_key)',
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Deletes every row in every table (used by "Reset data" and import).
  Future<void> wipe() => transaction(() async {
    for (final table in allTables.toList().reversed) {
      await delete(table).go();
    }
  });
}
