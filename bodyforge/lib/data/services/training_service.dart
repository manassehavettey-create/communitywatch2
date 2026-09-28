import '../../domain/catalog/achievements.dart';
import '../../domain/catalog/exercises.dart';
import '../../domain/catalog/skill_paths.dart';
import '../../domain/engine/achievement_evaluator.dart';
import '../../domain/engine/adaptive_engine.dart';
import '../../domain/engine/baseline.dart';
import '../../domain/engine/calendar.dart';
import '../../domain/engine/journey.dart';
import '../../domain/engine/player.dart';
import '../../domain/engine/program_generator.dart';
import '../../domain/engine/records.dart';
import '../../domain/engine/reports.dart';
import '../../domain/engine/training_params.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/local_date.dart';
import '../../domain/models/profile.dart';
import '../repositories/data_context.dart';
import '../repositories/lifestyle_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/training_repository.dart';

class CompletionOutcome {
  const CompletionOutcome({
    required this.workoutId,
    required this.prs,
    required this.baselines,
    required this.progression,
    required this.achievements,
    required this.journeyBefore,
    required this.journeyAfter,
    required this.durationSec,
    required this.totalReps,
    required this.setsDone,
  });

  final String workoutId;

  /// Real PRs (beat a previous record) — celebrated.
  final List<PrEvent> prs;

  /// First-time results — recorded quietly.
  final List<PrEvent> baselines;
  final List<ProgressionEvent> progression;
  final List<AchievementDef> achievements;
  final JourneyState journeyBefore;
  final JourneyState journeyAfter;
  final int durationSec;
  final int totalReps;
  final int setsDone;

  Iterable<ProgressionEvent> get unlocks => progression.where((e) => e.isUnlock);
}

/// Orchestrates multi-repository flows: onboarding, finishing a workout and
/// re-evaluating achievements. Everything runs locally; sync happens after.
class TrainingService {
  TrainingService(this.ctx)
      : profiles = ProfileRepository(ctx),
        training = TrainingRepository(ctx),
        lifestyle = LifestyleRepository(ctx);

  final DataContext ctx;
  final ProfileRepository profiles;
  final TrainingRepository training;
  final LifestyleRepository lifestyle;

  // ───────────────────────── onboarding ─────────────────────────

  /// Save the profile and create the starting program, skill placement,
  /// journey and first weight entry (spec §3 → "creates the starting program").
  Future<ProgramSpec> completeOnboarding(UserProfile profile) async {
    final today = ctx.today;
    final p = profile.copyWith(id: ctx.userId, journeyStart: today);
    await profiles.saveProfile(p);
    final spec = generateProgram(
      goals: p.goals,
      daysPerWeek: p.daysPerWeek,
      minutes: p.sessionMinutes,
      preferredDays: p.preferredDays,
    );
    await profiles.activateProgram(spec, startedOn: today);
    final params = TrainingParams.from(goals: p.goals, level: p.level, phase: JourneyPhase.habit, daysPerWeek: p.daysPerWeek);
    final start = initialProgress(p, params, now: ctx.nowUtc);
    await training.saveProgress(start.values);
    await training.saveJourney(JourneyRecord(
      startDate: today,
      currentWeek: 1,
      countedWeeks: 0,
      startNodes: {for (final e in start.entries) e.key: e.value.nodeIndex},
    ));
    await lifestyle.addMeasurement(MeasurementType.weight, p.weightKg, date: today);
    return spec;
  }

  /// Regenerate the plan after the user edits goals / days / duration.
  Future<void> regenerateProgram(UserProfile p) async {
    final spec = generateProgram(
        goals: p.goals, daysPerWeek: p.daysPerWeek, minutes: p.sessionMinutes, preferredDays: p.preferredDays);
    await profiles.activateProgram(spec);
  }

  // ───────────────────────── journey ─────────────────────────

  Future<JourneyState> journeyState() async {
    final record = await training.getJourney();
    final program = await profiles.getActiveProgram();
    final workouts = await training.getWorkouts();
    final start = record?.startDate ?? ctx.today;
    return computeJourney(
      start: start,
      today: ctx.today,
      workoutDates: [for (final w in workouts) w.date],
      plannedPerWeek: program?.spec.sessionsPerWeek ?? 3,
    );
  }

  Future<JourneyPhase> currentPhase() async => (await journeyState()).phase;

  Future<TrainingParams> paramsFor(UserProfile p) async => TrainingParams.from(
        goals: p.goals,
        level: p.level,
        phase: await currentPhase(),
        daysPerWeek: p.daysPerWeek,
      );

  // ───────────────────────── completing a workout ─────────────────────────

  Future<CompletionOutcome> completeWorkout(PlayerSnapshot snapshot, Rating rating, {String? recoveryCheckId}) async {
    final now = ctx.clock.now();
    final date = LocalDate.fromDateTime(snapshot.startedAt.toLocal());
    final profile = await profiles.getProfile();
    if (profile == null) throw StateError('No profile');
    final program = await profiles.getActiveProgram();
    final journeyBefore = await journeyState();
    final params = TrainingParams.from(
        goals: profile.goals, level: profile.level, phase: journeyBefore.phase, daysPerWeek: profile.daysPerWeek);

    // 1. Records.
    final history = await training.getRecordHistory();
    final events = detectRecords(TrainingRepository.bestsFrom(history), snapshot.results);
    await training.saveRecords(events, workoutId: snapshot.workoutId, date: date);

    // 2. Adaptive progression (not for recovery flows or benchmark tests).
    var progression = <ProgressionEvent>[];
    final plan = snapshot.plan;
    if (plan.kind != SessionKind.recovery && plan.kind != SessionKind.benchmark && plan.dayType != DayType.recovery) {
      final before = await training.getProgress();
      final result = applySession(
        current: before,
        results: snapshot.results,
        rating: rating,
        params: params,
        wasReduced: plan.kind == SessionKind.recoveryReduced,
        now: ctx.nowUtc,
      );
      progression = result.events;
      final changed = [for (final e in result.events) if (e.type != ProgressionType.skipped) result.progress[e.trackKey]!];
      await training.saveProgress(changed);
      for (final u in result.unlocks) {
        final path = kPathById[u.trackKey];
        final ex = exerciseById(u.toExerciseId);
        await training.addMilestone(Milestone(
          date: date,
          type: path != null && u.after.nodeIndex == path.length - 1 ? 'path_top' : 'unlock',
          title: 'Unlocked ${ex.name}',
          trackKey: u.trackKey,
          exerciseId: ex.id,
        ));
      }
    }

    // 3. The workout itself.
    await training.saveWorkout(
      snapshot: snapshot,
      rating: rating,
      date: date,
      endedAt: now,
      programId: program?.id,
      journeyWeek: journeyBefore.currentWeek,
      recoveryCheckId: recoveryCheckId,
    );
    await training.clearActiveSession();

    // 4. Journey.
    final journeyAfter = await refreshJourney(before: journeyBefore);

    // 5. Achievements.
    final unlocked = await checkAchievements();

    return CompletionOutcome(
      workoutId: snapshot.workoutId,
      prs: [for (final e in events) if (e.isPr) e],
      baselines: [for (final e in events) if (e.isBaseline) e],
      progression: progression,
      achievements: unlocked,
      journeyBefore: journeyBefore,
      journeyAfter: journeyAfter,
      durationSec: snapshot.elapsed(now).inSeconds,
      totalReps: snapshot.totalReps,
      setsDone: snapshot.results.where((r) => !r.skipped).length,
    );
  }

  /// Recompute the journey, persist it and add phase milestones.
  Future<JourneyState> refreshJourney({JourneyState? before}) async {
    final b = before ?? await journeyState();
    final after = await journeyState();
    final record = await training.getJourney();
    if (record != null &&
        (record.countedWeeks != after.countedWeeks ||
            record.currentWeek != after.currentWeek ||
            (after.complete && record.completedOn == null))) {
      await training.saveJourney(JourneyRecord(
        startDate: record.startDate,
        currentWeek: after.currentWeek,
        countedWeeks: after.countedWeeks,
        startNodes: record.startNodes,
        completedOn: after.completedOn ?? record.completedOn,
      ));
    }
    for (final (weeks, title) in [(4, 'Phase 1 complete: Build the Habit'), (8, 'Phase 2 complete: Build the Body'), (12, '12-week BODYFORGE journey complete')]) {
      if (b.countedWeeks < weeks && after.countedWeeks >= weeks) {
        await training.addMilestone(Milestone(date: ctx.today, type: 'phase', title: title));
      }
    }
    return after;
  }

  // ───────────────────────── achievements ─────────────────────────

  Future<AchievementStats> achievementStats() async {
    final workouts = await training.getWorkouts();
    final program = await profiles.getActiveProgram();
    final history = await training.getRecordHistory();
    final measurements = await lifestyle.getMeasurements();
    final challenges = await lifestyle.getChallenges();
    final milestones = await training.getMilestones();
    final progress = await training.getProgress();
    final journey = await journeyState();
    final ws = workoutStats(workouts, program?.spec.sessionsPerWeek ?? 3);

    final today = ctx.today;
    final from = today.addDays(-29);
    final recent = [for (final w in workouts) if (!w.date.isBefore(from)) w.date];
    final c30 = consistency(
      from: from,
      to: today,
      sessionDates: recent,
      program: program?.spec,
      programStart: program?.startedOn ?? today,
    );

    return AchievementStats(
      totalWorkouts: ws.total,
      pushUpReps: ws.pushUps,
      squatReps: ws.squats,
      prCount: history.where((r) => r.previous != null).length,
      coreSessions: ws.coreSessions,
      maxPlankSec: ws.maxPlank,
      lowMotivationSessions: ws.lowMotivation,
      recoverySessions: ws.recovery,
      comeback: ws.comeback,
      fullWeek: ws.fullWeek,
      journeyCountedWeeks: journey.countedWeeks,
      journeyComplete: journey.complete,
      measurementCount: measurements.length,
      consistency30: c30,
      workouts30: recent.length,
      completedChallenges: {for (final c in challenges) if (c.isComplete) c.def.id},
      unlockCount: milestones.where((m) => m.type == 'unlock' || m.type == 'path_top').length,
      pathMastered: PathIds.all.any((id) {
        final p = progress[id];
        return p != null && p.nodeIndex >= pathById(id).length - 1;
      }),
    );
  }

  /// Unlock anything newly earned; returns the new achievements.
  Future<List<AchievementDef>> checkAchievements() async {
    final stats = await achievementStats();
    final already = (await lifestyle.getUnlocked()).keys.toSet();
    final fresh = evaluateAchievements(stats, already);
    if (fresh.isNotEmpty) await lifestyle.unlock(fresh.map((a) => a.id));
    return fresh;
  }
}
