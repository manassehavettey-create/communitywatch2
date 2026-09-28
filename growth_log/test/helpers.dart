import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:growth_log/core/db/database.dart';
import 'package:growth_log/core/utils/clock.dart';
import 'package:growth_log/features/log/data/entry_repository.dart';
import 'package:growth_log/features/skills/data/milestone_repository.dart';
import 'package:growth_log/features/skills/data/skill_repository.dart';
import 'package:growth_log/features/timer/data/timer_repository.dart';

AppDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

class TestEnv {
  TestEnv({DateTime? now})
    : db = memoryDb(),
      clock = FixedClock(now ?? DateTime(2026, 9, 28, 10));

  final AppDatabase db;
  final FixedClock clock;

  late final skills = SkillRepository(db, clock);
  late final entries = EntryRepository(db, clock);
  late final milestones = MilestoneRepository(db, clock);
  late final timer = TimerRepository(db, clock);

  Future<int> skill([String name = 'Guitar']) => skills.createSkill(
    SkillDraft(name: name, iconKey: 'guitar', colorValue: 0xFFC8EC64),
  );

  Future<void> dispose() => db.close();
}
