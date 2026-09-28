import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/engine/player.dart';
import '../../domain/engine/records.dart';
import '../../domain/engine/recovery.dart';
import '../../domain/engine/reports.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/local_date.dart';
import '../../domain/models/profile.dart';
import '../../domain/models/workout.dart';
import '../local/database.dart';
import 'data_context.dart';

class StoredRecoveryCheck {
  const StoredRecoveryCheck(this.id, this.date, this.check, this.mode);
  final String id;
  final LocalDate date;
  final RecoveryCheck check;
  final RecoveryMode mode;
}

class JourneyRecord {
  const JourneyRecord({
    required this.startDate,
    required this.currentWeek,
    required this.countedWeeks,
    required this.startNodes,
    this.completedOn,
  });
  final LocalDate startDate;
  final int currentWeek;
  final int countedWeeks;
  final Map<String, int> startNodes;
  final LocalDate? completedOn;
}

/// Workouts, sets, skill progress, records, milestones, recovery checks,
/// the journey row and the running session.
class TrainingRepository {
  TrainingRepository(this.ctx);
  final DataContext ctx;
  AppDatabase get db => ctx.db;
  String get uid => ctx.userId;

  // ───────────────────────── skill progress ─────────────────────────

  Future<Map<String, TrackProgress>> getProgress() async {
    final rows =
        await (db.select(db.skillProgress)..where((t) => t.userId.equals(uid) & t.deletedAt.isNull())).get();
    return {
      for (final r in rows)
        r.trackKey: TrackProgress(
          key: r.trackKey,
          nodeIndex: r.nodeIndex,
          sets: r.sets,
          amount: r.amount,
          easyStreak: r.easyStreak,
          hardStreak: r.hardStreak,
          bestNodeIndex: r.bestNode,
          updatedAt: r.updatedAt,
        )
    };
  }

  Stream<Map<String, TrackProgress>> watchProgress() => watchTables(db, {db.skillProgress}, getProgress);

  Future<void> saveProgress(Iterable<TrackProgress> tracks) async {
    final now = ctx.nowUtc;
    await db.transaction(() async {
      for (final t in tracks) {
        final id = ctx.keyed(t.key);
        await db.write(
          db.skillProgress,
          SkillProgressCompanion.insert(
            id: id,
            userId: uid,
            trackKey: t.key,
            nodeIndex: t.nodeIndex,
            sets: t.sets,
            amount: t.amount,
            easyStreak: Value(t.easyStreak),
            hardStreak: Value(t.hardStreak),
            bestNode: Value(t.highestNode),
            updatedAt: now,
          ),
          id,
        );
      }
    });
  }

  // ───────────────────────── workouts ─────────────────────────

  Future<List<CompletedWorkout>> getWorkouts({LocalDate? from, LocalDate? to}) async {
    final q = db.select(db.workouts)..where((t) => t.userId.equals(uid) & t.deletedAt.isNull());
    if (from != null) q.where((t) => t.date.isBiggerOrEqualValue(from.toString()));
    if (to != null) q.where((t) => t.date.isSmallerOrEqualValue(to.toString()));
    q.orderBy([(t) => OrderingTerm.asc(t.startedAt)]);
    final rows = await q.get();
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r.id).toList();
    final sets = await (db.select(db.workoutSets)
          ..where((s) => s.workoutId.isIn(ids) & s.deletedAt.isNull())
          ..orderBy([(s) => OrderingTerm.asc(s.completedAt)]))
        .get();
    final byWorkout = <String, List<SetResult>>{};
    for (final s in sets) {
      byWorkout.putIfAbsent(s.workoutId, () => []).add(SetResult(
            exerciseId: s.exerciseId,
            trackKey: s.trackKey,
            setIndex: s.setIndex,
            target: s.target,
            achieved: s.achieved,
            skipped: s.skipped,
            blockKind: enumByName(BlockKind.values, s.block, BlockKind.main),
            completedAt: s.completedAt,
          ));
    }
    return [
      for (final r in rows)
        CompletedWorkout(
          id: r.id,
          date: LocalDate.parse(r.date),
          dayType: enumByName(DayType.values, r.dayType, DayType.fullBody),
          kind: enumByName(SessionKind.values, r.kind, SessionKind.planned),
          sets: byWorkout[r.id] ?? const [],
          durationSec: r.durationSec,
          rating: r.rating == null ? null : enumByName(Rating.values, r.rating, Rating.good),
          startedAt: r.startedAt,
        )
    ];
  }

  Stream<List<CompletedWorkout>> watchWorkouts() => watchTables(db, {db.workouts, db.workoutSets}, getWorkouts);

  Future<WorkoutRow?> getWorkoutRow(String id) =>
      (db.select(db.workouts)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Persist a finished session (workout + every set) in one transaction.
  Future<void> saveWorkout({
    required PlayerSnapshot snapshot,
    required Rating? rating,
    required LocalDate date,
    required DateTime endedAt,
    String? programId,
    int? journeyWeek,
    String? recoveryCheckId,
  }) async {
    final now = ctx.nowUtc;
    final plan = snapshot.plan;
    final duration = snapshot.elapsed(endedAt).inSeconds;
    await db.transaction(() async {
      await db.write(
        db.workouts,
        WorkoutsCompanion.insert(
          id: snapshot.workoutId,
          userId: uid,
          programId: Value(programId),
          date: date.toString(),
          startedAt: snapshot.startedAt.toUtc(),
          endedAt: endedAt.toUtc(),
          dayType: plan.dayType.name,
          kind: plan.kind.name,
          title: plan.title,
          plan: jsonEncode(plan.toJson()),
          rating: Value(rating?.name),
          durationSec: duration,
          totalReps: Value(snapshot.totalReps),
          journeyWeek: Value(journeyWeek),
          recoveryCheckId: Value(recoveryCheckId),
          updatedAt: now,
        ),
        snapshot.workoutId,
      );
      for (var i = 0; i < snapshot.results.length; i++) {
        final r = snapshot.results[i];
        final id = '${snapshot.workoutId}:$i';
        await db.write(
          db.workoutSets,
          WorkoutSetsCompanion.insert(
            id: id,
            userId: uid,
            workoutId: snapshot.workoutId,
            exerciseId: r.exerciseId,
            trackKey: Value(r.trackKey),
            block: r.blockKind.name,
            setIndex: r.setIndex,
            target: r.target,
            achieved: r.achieved,
            skipped: Value(r.skipped),
            completedAt: Value(r.completedAt),
            updatedAt: now,
          ),
          id,
        );
      }
    });
  }

  /// Soft-delete a workout (tombstone syncs to other devices).
  Future<void> deleteWorkout(String id) async {
    final row = await getWorkoutRow(id);
    if (row == null) return;
    final now = ctx.nowUtc;
    await db.transaction(() async {
      await db.write(db.workouts, row.toCompanion(false).copyWith(deletedAt: Value(now), updatedAt: Value(now)), id);
      final sets = await (db.select(db.workoutSets)..where((s) => s.workoutId.equals(id))).get();
      for (final s in sets) {
        await db.write(
            db.workoutSets, s.toCompanion(false).copyWith(deletedAt: Value(now), updatedAt: Value(now)), s.id);
      }
    });
  }

  // ───────────────────────── records ─────────────────────────

  Future<List<RecordPoint>> getRecordHistory() async {
    final rows = await (db.select(db.personalRecords)
          ..where((t) => t.userId.equals(uid) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.achievedOn), (t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return [
      for (final r in rows)
        RecordPoint(
          exerciseId: r.exerciseId,
          metric: enumByName(RecordMetric.values, r.metric, RecordMetric.maxReps),
          previous: r.previousValue,
          value: r.value,
          date: LocalDate.parse(r.achievedOn),
        )
    ];
  }

  Stream<List<RecordPoint>> watchRecordHistory() => watchTables(db, {db.personalRecords}, getRecordHistory);

  /// Best value per record key (`exercise|metric`).
  static Map<String, int> bestsFrom(List<RecordPoint> history) {
    final out = <String, int>{};
    for (final r in history) {
      final k = recordKey(r.exerciseId, r.metric);
      if ((out[k] ?? -1) < r.value) out[k] = r.value;
    }
    return out;
  }

  Future<void> saveRecords(List<PrEvent> events, {required String workoutId, required LocalDate date}) async {
    if (events.isEmpty) return;
    final now = ctx.nowUtc;
    await db.transaction(() async {
      for (final e in events) {
        final id = ctx.newId();
        await db.write(
          db.personalRecords,
          PersonalRecordsCompanion.insert(
            id: id,
            userId: uid,
            exerciseId: e.exerciseId,
            metric: e.metric.name,
            value: e.current,
            previousValue: Value(e.previous),
            workoutId: Value(workoutId),
            achievedOn: date.toString(),
            updatedAt: now,
          ),
          id,
        );
      }
    });
  }

  // ───────────────────────── milestones ─────────────────────────

  Future<List<Milestone>> getMilestones() async {
    final rows = await (db.select(db.milestones)
          ..where((t) => t.userId.equals(uid) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
    return [
      for (final r in rows)
        Milestone(
            date: LocalDate.parse(r.date), type: r.type, title: r.title, trackKey: r.trackKey, exerciseId: r.exerciseId)
    ];
  }

  Stream<List<Milestone>> watchMilestones() => watchTables(db, {db.milestones}, getMilestones);

  Future<void> addMilestone(Milestone m) async {
    final id = ctx.newId();
    await db.write(
      db.milestones,
      MilestonesCompanion.insert(
        id: id,
        userId: uid,
        date: m.date.toString(),
        type: m.type,
        title: m.title,
        trackKey: Value(m.trackKey),
        exerciseId: Value(m.exerciseId),
        updatedAt: ctx.nowUtc,
      ),
      id,
    );
  }

  // ───────────────────────── recovery checks ─────────────────────────

  Future<List<StoredRecoveryCheck>> getRecoveryChecks() async {
    final rows = await (db.select(db.recoveryChecks)
          ..where((t) => t.userId.equals(uid) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.date), (t) => OrderingTerm.asc(t.updatedAt)]))
        .get();
    return [
      for (final r in rows)
        StoredRecoveryCheck(
          r.id,
          LocalDate.parse(r.date),
          RecoveryCheck(
            sleep: enumByName(SleepQuality.values, r.sleep, SleepQuality.okay),
            soreness: enumByName(Soreness.values, r.soreness, Soreness.little),
            energy: enumByName(Energy.values, r.energy, Energy.normal),
          ),
          enumByName(RecoveryMode.values, r.mode, RecoveryMode.full),
        )
    ];
  }

  Stream<List<StoredRecoveryCheck>> watchRecoveryChecks() => watchTables(db, {db.recoveryChecks}, getRecoveryChecks);

  /// One check per day: saving again today replaces today's answer.
  Future<String> saveRecoveryCheck(RecoveryCheck c, RecoveryMode mode) async {
    final id = ctx.keyed('recovery:${ctx.today}');
    await db.write(
      db.recoveryChecks,
      RecoveryChecksCompanion.insert(
        id: id,
        userId: uid,
        date: ctx.today.toString(),
        sleep: c.sleep.name,
        soreness: c.soreness.name,
        energy: c.energy.name,
        score: c.score,
        mode: mode.name,
        updatedAt: ctx.nowUtc,
      ),
      id,
    );
    return id;
  }

  // ───────────────────────── journey ─────────────────────────

  Future<JourneyRecord?> getJourney() async {
    final r = await (db.select(db.journeyProgress)..where((t) => t.id.equals(uid))).getSingleOrNull();
    if (r == null) return null;
    return JourneyRecord(
      startDate: LocalDate.parse(r.startDate),
      currentWeek: r.currentWeek,
      countedWeeks: r.countedWeeks,
      completedOn: LocalDate.tryParse(r.completedOn),
      startNodes: {
        for (final e in (jsonDecode(r.startNodes) as Map).entries) e.key as String: (e.value as num).toInt()
      },
    );
  }

  Stream<JourneyRecord?> watchJourney() => watchTables(db, {db.journeyProgress}, getJourney);

  Future<void> saveJourney(JourneyRecord j) async {
    await db.write(
      db.journeyProgress,
      JourneyProgressCompanion.insert(
        id: uid,
        userId: uid,
        startDate: j.startDate.toString(),
        currentWeek: j.currentWeek,
        countedWeeks: j.countedWeeks,
        completedOn: Value(j.completedOn?.toString()),
        startNodes: Value(jsonEncode(j.startNodes)),
        updatedAt: ctx.nowUtc,
      ),
      uid,
    );
  }

  // ───────────────────────── running session ─────────────────────────

  Future<PlayerSnapshot?> getActiveSession() async {
    final r = await (db.select(db.activeSessions)..where((t) => t.userId.equals(uid))).getSingleOrNull();
    if (r == null) return null;
    try {
      return PlayerSnapshot.fromJson((jsonDecode(r.snapshot) as Map).cast<String, Object?>());
    } on Object {
      // A corrupt snapshot must never brick the app.
      await clearActiveSession();
      return null;
    }
  }

  Stream<bool> watchHasActiveSession() => (db.select(db.activeSessions)..where((t) => t.userId.equals(uid)))
      .watchSingleOrNull()
      .map((r) => r != null);

  Future<void> saveActiveSession(PlayerSnapshot s) => db.into(db.activeSessions).insertOnConflictUpdate(
        ActiveSessionsCompanion.insert(userId: uid, snapshot: jsonEncode(s.toJson()), updatedAt: ctx.nowUtc),
      );

  Future<void> clearActiveSession() => (db.delete(db.activeSessions)..where((t) => t.userId.equals(uid))).go();
}
