import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/catalog/challenges.dart';
import '../../domain/engine/reports.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/local_date.dart';
import '../local/database.dart';
import 'data_context.dart';

class StoredMeasurement {
  const StoredMeasurement(this.id, this.point);
  final String id;
  final MeasurementPoint point;
}

class ChallengeEnrollment {
  const ChallengeEnrollment({
    required this.id,
    required this.def,
    required this.startedOn,
    required this.checkins,
    this.completedOn,
    this.abandoned = false,
  });

  final String id;
  final ChallengeDef def;
  final LocalDate startedOn;

  /// date → value (glasses, 1 for yes, 1 for a qualifying meal).
  final Map<LocalDate, double> checkins;
  final LocalDate? completedOn;
  final bool abandoned;

  int get successDays => checkins.entries.where((e) => def.isSuccess(e.value)).length;
  bool get isComplete => completedOn != null || successDays >= def.daysRequired;
  bool get isActive => !abandoned && !isComplete;
  double get progress => (successDays / def.daysRequired).clamp(0.0, 1.0);
}

/// Measurements, nutrition challenges, achievements and food prices.
class LifestyleRepository {
  LifestyleRepository(this.ctx);
  final DataContext ctx;
  AppDatabase get db => ctx.db;
  String get uid => ctx.userId;

  // ───────────────────────── measurements ─────────────────────────

  Future<List<StoredMeasurement>> getMeasurements() async {
    final rows = await (db.select(db.measurements)
          ..where((t) => t.userId.equals(uid) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.measuredOn), (t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return [
      for (final r in rows)
        StoredMeasurement(
          r.id,
          MeasurementPoint(enumByName(MeasurementType.values, r.type, MeasurementType.custom), r.value,
              LocalDate.parse(r.measuredOn),
              label: r.label),
        )
    ];
  }

  Stream<List<StoredMeasurement>> watchMeasurements() => watchTables(db, {db.measurements}, getMeasurements);

  /// [value] must be metric (kg / cm).
  Future<void> addMeasurement(MeasurementType type, double value, {LocalDate? date, String? label}) async {
    final id = ctx.newId();
    await db.write(
      db.measurements,
      MeasurementsCompanion.insert(
        id: id,
        userId: uid,
        type: type.name,
        label: Value(type == MeasurementType.custom ? label?.trim() : null),
        value: value,
        measuredOn: (date ?? ctx.today).toString(),
        updatedAt: ctx.nowUtc,
      ),
      id,
    );
  }

  Future<void> deleteMeasurement(String id) async {
    final row = await (db.select(db.measurements)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    final now = ctx.nowUtc;
    await db.write(db.measurements, row.toCompanion(false).copyWith(deletedAt: Value(now), updatedAt: Value(now)), id);
  }

  // ───────────────────────── challenges ─────────────────────────

  Future<List<ChallengeEnrollment>> getChallenges() async {
    final rows = await (db.select(db.challengeProgress)
          ..where((t) => t.userId.equals(uid) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startedOn)]))
        .get();
    if (rows.isEmpty) return const [];
    final checks = await (db.select(db.challengeCheckins)
          ..where((t) => t.progressId.isIn(rows.map((r) => r.id).toList()) & t.deletedAt.isNull()))
        .get();
    final out = <ChallengeEnrollment>[];
    for (final r in rows) {
      final def = kChallengeById[r.challengeId];
      if (def == null) continue;
      out.add(ChallengeEnrollment(
        id: r.id,
        def: def,
        startedOn: LocalDate.parse(r.startedOn),
        completedOn: LocalDate.tryParse(r.completedOn),
        abandoned: r.abandoned,
        checkins: {for (final c in checks.where((c) => c.progressId == r.id)) LocalDate.parse(c.date): c.value},
      ));
    }
    return out;
  }

  Stream<List<ChallengeEnrollment>> watchChallenges() =>
      watchTables(db, {db.challengeProgress, db.challengeCheckins}, getChallenges);

  Future<String> startChallenge(String challengeId) async {
    final existing = (await getChallenges()).where((c) => c.def.id == challengeId && c.isActive);
    if (existing.isNotEmpty) return existing.first.id;
    final id = ctx.newId();
    await db.write(
      db.challengeProgress,
      ChallengeProgressCompanion.insert(
          id: id, userId: uid, challengeId: challengeId, startedOn: ctx.today.toString(), updatedAt: ctx.nowUtc),
      id,
    );
    return id;
  }

  /// Record today's value (idempotent per day). Returns true if this check-in
  /// completed the challenge.
  Future<bool> checkIn(ChallengeEnrollment e, double value, {Map<String, Object?>? detail, LocalDate? date}) async {
    final day = date ?? ctx.today;
    final id = '${e.id}:$day';
    final now = ctx.nowUtc;
    await db.write(
      db.challengeCheckins,
      ChallengeCheckinsCompanion.insert(
        id: id,
        userId: uid,
        progressId: e.id,
        date: day.toString(),
        value: value,
        detail: Value(detail == null ? null : jsonEncode(detail)),
        updatedAt: now,
      ),
      id,
    );
    final after = {...e.checkins, day: value};
    final successes = after.values.where(e.def.isSuccess).length;
    if (e.completedOn == null && successes >= e.def.daysRequired) {
      final row = await (db.select(db.challengeProgress)..where((t) => t.id.equals(e.id))).getSingle();
      await db.write(db.challengeProgress,
          row.toCompanion(false).copyWith(completedOn: Value(day.toString()), updatedAt: Value(now)), e.id);
      return true;
    }
    return false;
  }

  Future<void> abandonChallenge(String id) async {
    final row = await (db.select(db.challengeProgress)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await db.write(db.challengeProgress,
        row.toCompanion(false).copyWith(abandoned: const Value(true), updatedAt: Value(ctx.nowUtc)), id);
  }

  // ───────────────────────── achievements ─────────────────────────

  Future<Map<String, DateTime>> getUnlocked() async {
    final rows =
        await (db.select(db.userAchievements)..where((t) => t.userId.equals(uid) & t.deletedAt.isNull())).get();
    return {for (final r in rows) r.achievementId: r.unlockedAt};
  }

  Stream<Map<String, DateTime>> watchUnlocked() => watchTables(db, {db.userAchievements}, getUnlocked);

  Future<void> unlock(Iterable<String> achievementIds) async {
    final now = ctx.nowUtc;
    await db.transaction(() async {
      for (final a in achievementIds) {
        final id = ctx.keyed(a);
        await db.into(db.userAchievements).insert(
              UserAchievementsCompanion.insert(id: id, userId: uid, achievementId: a, unlockedAt: now, updatedAt: now),
              mode: InsertMode.insertOrIgnore,
            );
        await db.enqueue('user_achievements', id);
      }
    });
  }

  // ───────────────────────── food prices ─────────────────────────

  Future<Map<String, double>> getPriceOverrides() async {
    final rows = await (db.select(db.foodPrices)..where((t) => t.userId.equals(uid) & t.deletedAt.isNull())).get();
    return {for (final r in rows) r.foodId: r.price};
  }

  Stream<Map<String, double>> watchPriceOverrides() => watchTables(db, {db.foodPrices}, getPriceOverrides);

  Future<void> setPrice(String foodId, double? price) async {
    final id = ctx.keyed(foodId);
    final now = ctx.nowUtc;
    await db.write(
      db.foodPrices,
      FoodPricesCompanion.insert(
        id: id,
        userId: uid,
        foodId: foodId,
        price: price ?? 0,
        updatedAt: now,
        deletedAt: Value(price == null ? now : null),
      ),
      id,
    );
  }
}
