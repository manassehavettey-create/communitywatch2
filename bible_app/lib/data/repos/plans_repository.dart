import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

import '../../domain/days.dart';
import '../../domain/plans.dart';
import '../db/database.dart';
import '../sync/sync_writer.dart';

/// A plan the user has started, with its computed state.
class UserPlan {
  const UserPlan(this.progressId, this.state);

  final String progressId;
  final PlanState state;

  PlanDefinition get plan => state.plan;
}

class PlansRepository {
  PlansRepository(this._w, {AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final SyncWriter _w;
  final AssetBundle _bundle;
  AppDatabase get _db => _w.db;

  List<PlanDefinition>? _catalog;

  Future<List<PlanDefinition>> catalog() async =>
      _catalog ??= PlanDefinition.parseAll(
        await _bundle.loadString('assets/plans/plans.json'),
      );

  /// Every started plan (active, paused and completed), newest first.
  Stream<List<UserPlan>> watchUserPlans() {
    final progress =
        (_db.select(_db.planProgress)
              ..where((p) => p.deletedAt.isNull())
              ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]))
            .watch();
    final days = (_db.select(
      _db.planDayCompletions,
    )..where((d) => d.deletedAt.isNull())).watch();
    return Rx.combineLatest2(progress, days, (ps, ds) => (ps, ds)).asyncMap((
      pair,
    ) async {
      final (ps, ds) = pair;
      final defs = {for (final d in await catalog()) d.id: d};
      final out = <UserPlan>[];
      for (final p in ps) {
        final def = defs[p.planId];
        if (def == null) continue;
        out.add(
          UserPlan(
            p.id,
            PlanState(
              plan: def,
              status: PlanStatus.fromName(p.status),
              startDate: p.startDate,
              pausedOn: p.pausedOn,
              pausedDays: p.pausedDays,
              completedDays: {
                for (final d in ds)
                  if (d.progressId == p.id) d.day,
              },
            ),
          ),
        );
      }
      return out;
    });
  }

  /// Starts [planId], or resumes it if it was already started.
  Future<String> start(String planId) async {
    // Normally one row per plan, but starting the same plan offline on two
    // devices syncs two; use the most recently updated.
    final existing =
        (await (_db.select(_db.planProgress)
                  ..where((p) => p.planId.equals(planId) & p.deletedAt.isNull())
                  ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]))
                .get())
            .firstOrNull;
    if (existing != null) {
      if (existing.status == PlanStatus.paused.name) await resume(existing.id);
      return existing.id;
    }
    final id = _w.newId();
    await _w.write(
      'plan_progress',
      id,
      (t) => _db
          .into(_db.planProgress)
          .insert(
            PlanProgressCompanion.insert(
              id: id,
              userId: Value(_w.userId),
              createdAt: t,
              updatedAt: t,
              planId: planId,
              status: PlanStatus.active.name,
              startDate: Days.today(),
            ),
          ),
    );
    return id;
  }

  Future<void> pause(String progressId) => _w.write(
    'plan_progress',
    progressId,
    (t) => (_db.update(_db.planProgress)..where((p) => p.id.equals(progressId)))
        .write(
          PlanProgressCompanion(
            status: Value(PlanStatus.paused.name),
            pausedOn: Value(Days.today()),
            updatedAt: Value(t),
          ),
        ),
  );

  Future<void> resume(String progressId) async {
    final row = await (_db.select(
      _db.planProgress,
    )..where((p) => p.id.equals(progressId))).getSingle();
    final extra = row.pausedOn == null
        ? row.pausedDays
        : PlanState.resumedPausedDays(
            pausedDays: row.pausedDays,
            pausedOn: row.pausedOn!,
            today: Days.today(),
          );
    await _w.write(
      'plan_progress',
      progressId,
      (t) =>
          (_db.update(
            _db.planProgress,
          )..where((p) => p.id.equals(progressId))).write(
            PlanProgressCompanion(
              status: Value(PlanStatus.active.name),
              pausedOn: const Value(null),
              pausedDays: Value(extra),
              updatedAt: Value(t),
            ),
          ),
    );
  }

  /// Clears progress and starts again from day 1 today.
  Future<void> restart(String progressId) async {
    final days =
        await (_db.select(_db.planDayCompletions)..where(
              (d) => d.progressId.equals(progressId) & d.deletedAt.isNull(),
            ))
            .get();
    for (final d in days) {
      await _w.softDelete('plan_day_completions', d.id);
    }
    await _w.write(
      'plan_progress',
      progressId,
      (t) =>
          (_db.update(
            _db.planProgress,
          )..where((p) => p.id.equals(progressId))).write(
            PlanProgressCompanion(
              status: Value(PlanStatus.active.name),
              startDate: Value(Days.today()),
              pausedOn: const Value(null),
              pausedDays: const Value(0),
              completedAt: const Value(null),
              updatedAt: Value(t),
            ),
          ),
    );
  }

  /// Stops tracking a plan entirely.
  Future<void> remove(String progressId) async {
    final days = await (_db.select(
      _db.planDayCompletions,
    )..where((d) => d.progressId.equals(progressId))).get();
    for (final d in days) {
      if (d.deletedAt == null) {
        await _w.softDelete('plan_day_completions', d.id);
      }
    }
    await _w.softDelete('plan_progress', progressId);
  }

  /// Marks a day done or not done. Returns true when this completed the
  /// whole plan.
  Future<bool> setDayComplete(
    String progressId,
    int day,
    bool complete, {
    required int totalDays,
  }) async {
    // Deterministic id: the same day completed on two devices is one row.
    final id = '$progressId:$day';
    await _w.write('plan_day_completions', id, (t) async {
      await _db
          .into(_db.planDayCompletions)
          .insertOnConflictUpdate(
            PlanDayCompletionsCompanion.insert(
              id: id,
              userId: Value(_w.userId),
              createdAt: t,
              updatedAt: t,
              progressId: progressId,
              day: day,
              completedAt: t,
              deletedAt: Value(complete ? null : t),
            ),
          );
    });
    final done =
        await (_db.select(_db.planDayCompletions)..where(
              (d) => d.progressId.equals(progressId) & d.deletedAt.isNull(),
            ))
            .get();
    final finished =
        done.map((d) => d.day).where((d) => d <= totalDays).toSet().length >=
        totalDays;
    final row = await (_db.select(
      _db.planProgress,
    )..where((p) => p.id.equals(progressId))).getSingle();
    final wasCompleted = row.status == PlanStatus.completed.name;
    if (finished != wasCompleted) {
      await _w.write(
        'plan_progress',
        progressId,
        (t) =>
            (_db.update(
              _db.planProgress,
            )..where((p) => p.id.equals(progressId))).write(
              PlanProgressCompanion(
                status: Value(
                  finished ? PlanStatus.completed.name : PlanStatus.active.name,
                ),
                completedAt: Value(finished ? t : null),
                updatedAt: Value(t),
              ),
            ),
      );
    }
    return finished && !wasCompleted;
  }
}
