import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/engine/program_generator.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/local_date.dart';
import '../../domain/models/profile.dart';
import '../local/database.dart';
import 'data_context.dart';

class ActiveProgram {
  const ActiveProgram({required this.id, required this.spec, required this.startedOn});
  final String id;
  final ProgramSpec spec;
  final LocalDate startedOn;
}

class ProfileRepository {
  ProfileRepository(this.ctx);
  final DataContext ctx;
  AppDatabase get db => ctx.db;

  // ───────────────────────── profile ─────────────────────────

  UserProfile _toProfile(ProfileRow r, List<GoalRow> goals) => UserProfile(
        id: r.id,
        name: r.name,
        age: r.age,
        sex: enumByName(Sex.values, r.sex, Sex.other),
        heightCm: r.heightCm,
        weightKg: r.weightKg,
        level: enumByName(FitnessLevel.values, r.fitnessLevel, FitnessLevel.beginner),
        experience: enumByName(TrainingExperience.values, r.experience, TrainingExperience.none),
        goals: {for (final g in goals) enumByName(Goal.values, g.goal, Goal.fullTransformation)},
        daysPerWeek: r.daysPerWeek,
        sessionMinutes: r.sessionMinutes,
        environment: enumByName(TrainingEnvironment.values, r.environment, TrainingEnvironment.livingRoom),
        limitations: Limitations.fromJson((jsonDecode(r.limitations) as Map).cast<String, Object?>()),
        preferredDays: [for (final d in jsonDecode(r.preferredDays) as List) (d as num).toInt()],
        style: enumByName(WorkoutStyle.values, r.workoutStyle, WorkoutStyle.mixed),
        pushAbility: enumByName(PushAbility.values, r.pushAbility, PushAbility.knee),
        squatAbility: enumByName(SquatAbility.values, r.squatAbility, SquatAbility.underTen),
        plankAbility: enumByName(PlankAbility.values, r.plankAbility, PlankAbility.twentyTo45),
        journeyStart: LocalDate.parse(r.journeyStart),
        updatedAt: r.updatedAt,
      );

  Stream<UserProfile?> watchProfile() => watchTables(db, {db.profiles, db.goals}, getProfile);

  Future<UserProfile?> getProfile() async {
    final row = await (db.select(db.profiles)..where((t) => t.id.equals(ctx.userId) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) return null;
    final goals = await (db.select(db.goals)..where((t) => t.userId.equals(ctx.userId) & t.deletedAt.isNull())).get();
    return _toProfile(row, goals);
  }

  Future<void> saveProfile(UserProfile p) async {
    final now = ctx.nowUtc;
    await db.transaction(() async {
      await db.write(
        db.profiles,
        ProfilesCompanion.insert(
          id: ctx.userId,
          userId: ctx.userId,
          name: p.name.trim(),
          age: p.age,
          sex: p.sex.name,
          heightCm: p.heightCm,
          weightKg: p.weightKg,
          fitnessLevel: p.level.name,
          experience: p.experience.name,
          daysPerWeek: p.daysPerWeek,
          sessionMinutes: p.sessionMinutes,
          environment: p.environment.name,
          limitations: Value(jsonEncode(p.limitations.toJson())),
          preferredDays: Value(jsonEncode(p.preferredDays)),
          workoutStyle: p.style.name,
          pushAbility: p.pushAbility.name,
          squatAbility: p.squatAbility.name,
          plankAbility: p.plankAbility.name,
          journeyStart: p.journeyStart.toString(),
          updatedAt: now,
        ),
        ctx.userId,
      );
      // Goals: one row per goal, deterministic ids; removed goals are tombstoned.
      final existing = await (db.select(db.goals)..where((t) => t.userId.equals(ctx.userId))).get();
      for (final g in Goal.values) {
        final id = ctx.keyed('goal:${g.name}');
        final had = existing.where((e) => e.id == id).firstOrNull;
        final want = p.goals.contains(g);
        if (want && (had == null || had.deletedAt != null)) {
          await db.write(db.goals,
              GoalsCompanion.insert(id: id, userId: ctx.userId, goal: g.name, updatedAt: now), id);
        } else if (!want && had != null && had.deletedAt == null) {
          await db.write(
              db.goals,
              GoalsCompanion.insert(
                  id: id, userId: ctx.userId, goal: g.name, updatedAt: now, deletedAt: Value(now)),
              id);
        }
      }
    });
  }

  /// Environment mode switch from Home/Workout — also persisted to profile.
  Future<void> setEnvironment(TrainingEnvironment env) async {
    final p = await getProfile();
    if (p == null) return;
    await saveProfile(p.copyWith(environment: env));
  }

  // ───────────────────────── program ─────────────────────────

  Stream<ActiveProgram?> watchActiveProgram() => watchTables(db, {db.programs, db.programDays}, getActiveProgram);

  Future<ActiveProgram?> getActiveProgram() async {
    final row = await (db.select(db.programs)
          ..where((t) => t.userId.equals(ctx.userId) & t.active.equals(true) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toActive(row);
  }

  Future<ActiveProgram> _toActive(ProgramRow row) async {
    final days = await (db.select(db.programDays)
          ..where((t) => t.programId.equals(row.id) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.weekday)]))
        .get();
    return ActiveProgram(
      id: row.id,
      startedOn: LocalDate.parse(row.startedOn),
      spec: ProgramSpec(
        name: row.name,
        goals: {for (final g in jsonDecode(row.goals) as List) enumByName(Goal.values, g as String, Goal.fullTransformation)},
        daysPerWeek: row.daysPerWeek,
        minutes: row.minutes,
        custom: row.source == 'custom',
        focus: {for (final f in jsonDecode(row.focus) as List) enumByName(MuscleFocus.values, f as String, MuscleFocus.fullBody)},
        days: [for (final d in days) ProgramDay(d.weekday, enumByName(DayType.values, d.dayType, DayType.fullBody))],
      ),
    );
  }

  /// Make [spec] the active program from today; the previous one is archived.
  Future<String> activateProgram(ProgramSpec spec, {LocalDate? startedOn}) async {
    final now = ctx.nowUtc;
    final id = ctx.newId();
    await db.transaction(() async {
      final current = await (db.select(db.programs)
            ..where((t) => t.userId.equals(ctx.userId) & t.active.equals(true)))
          .get();
      for (final c in current) {
        await db.write(db.programs, c.toCompanion(false).copyWith(active: const Value(false), updatedAt: Value(now)), c.id);
      }
      await db.write(
        db.programs,
        ProgramsCompanion.insert(
          id: id,
          userId: ctx.userId,
          name: spec.name,
          source: spec.custom ? 'custom' : 'generated',
          goals: jsonEncode([for (final g in spec.goals) g.name]),
          daysPerWeek: spec.daysPerWeek,
          minutes: spec.minutes,
          focus: Value(jsonEncode([for (final f in spec.focus) f.name])),
          startedOn: (startedOn ?? ctx.today).toString(),
          updatedAt: now,
        ),
        id,
      );
      for (final d in spec.days) {
        final dayId = ctx.newId();
        await db.write(
          db.programDays,
          ProgramDaysCompanion.insert(
              id: dayId, userId: ctx.userId, programId: id, weekday: d.weekday, dayType: d.dayType.name, updatedAt: now),
          dayId,
        );
      }
    });
    return id;
  }
}
