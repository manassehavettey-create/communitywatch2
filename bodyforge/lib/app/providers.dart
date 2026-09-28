import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
import '../data/repositories/data_context.dart';
import '../data/repositories/lifestyle_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/training_repository.dart';
import '../data/services/training_service.dart';
import '../domain/catalog/exercises.dart';
import '../domain/engine/calendar.dart';
import '../domain/engine/environment.dart';
import '../domain/engine/journey.dart';
import '../domain/engine/mission.dart';
import '../domain/engine/recovery.dart';
import '../domain/engine/reports.dart';
import '../domain/engine/session_builder.dart';
import '../domain/engine/training_params.dart';
import '../domain/engine/weakest_link.dart';
import '../domain/models/enums.dart';
import '../domain/models/exercise.dart' show Limitations;
import '../domain/models/local_date.dart';
import '../domain/models/profile.dart';
import '../domain/models/workout.dart';
import 'auth.dart';
import 'notifications.dart';

// ───────────────────────── infrastructure ─────────────────────────

final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('overridden in main'));
final notificationsProvider = Provider<NotificationService>((ref) => NotificationService());
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Today's local date. Refreshes at midnight and whenever the app resumes, so
/// time-zone and date changes (travel, manual clock changes) are picked up.
class TodayNotifier extends Notifier<LocalDate> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  LocalDate build() {
    final clock = ref.watch(clockProvider);
    _lifecycle?.dispose();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
    });
    _schedule(clock);
    return clock.today();
  }

  void _schedule(Clock clock) {
    _timer?.cancel();
    final now = clock.now();
    final midnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1, seconds: 2));
    _timer = Timer(midnight.difference(now), _refresh);
  }

  void _refresh() {
    final clock = ref.read(clockProvider);
    final t = clock.today();
    if (t != state) state = t;
    _schedule(clock);
  }
}

final todayProvider = NotifierProvider<TodayNotifier, LocalDate>(TodayNotifier.new);

// ───────────────────────── data context & repositories ─────────────────────────

final dataContextProvider = Provider<DataContext?>((ref) {
  final auth = ref.watch(authProvider);
  final id = auth.userId;
  if (id == null) return null;
  return DataContext(db: ref.watch(databaseProvider), userId: id, clock: ref.watch(clockProvider));
});

DataContext _ctx(Ref ref) {
  final c = ref.watch(dataContextProvider);
  if (c == null) throw StateError('Not signed in');
  return c;
}

final profileRepoProvider = Provider<ProfileRepository>((ref) => ProfileRepository(_ctx(ref)));
final trainingRepoProvider = Provider<TrainingRepository>((ref) => TrainingRepository(_ctx(ref)));
final lifestyleRepoProvider = Provider<LifestyleRepository>((ref) => LifestyleRepository(_ctx(ref)));
final trainingServiceProvider = Provider<TrainingService>((ref) => TrainingService(_ctx(ref)));

// ───────────────────────── live data ─────────────────────────

final profileProvider = StreamProvider<UserProfile?>((ref) {
  if (ref.watch(dataContextProvider) == null) return Stream.value(null);
  return ref.watch(profileRepoProvider).watchProfile();
});

final activeProgramProvider = StreamProvider<ActiveProgram?>((ref) {
  if (ref.watch(dataContextProvider) == null) return Stream.value(null);
  return ref.watch(profileRepoProvider).watchActiveProgram();
});

final progressProvider = StreamProvider<Map<String, TrackProgress>>(
    (ref) => ref.watch(trainingRepoProvider).watchProgress());

final workoutsProvider = StreamProvider<List<CompletedWorkout>>(
    (ref) => ref.watch(trainingRepoProvider).watchWorkouts());

final recordHistoryProvider = StreamProvider<List<RecordPoint>>(
    (ref) => ref.watch(trainingRepoProvider).watchRecordHistory());

final milestonesProvider = StreamProvider<List<Milestone>>((ref) => ref.watch(trainingRepoProvider).watchMilestones());

final recoveryChecksProvider = StreamProvider<List<StoredRecoveryCheck>>(
    (ref) => ref.watch(trainingRepoProvider).watchRecoveryChecks());

final journeyRecordProvider = StreamProvider<JourneyRecord?>((ref) => ref.watch(trainingRepoProvider).watchJourney());

final measurementsProvider = StreamProvider<List<StoredMeasurement>>(
    (ref) => ref.watch(lifestyleRepoProvider).watchMeasurements());

final unlockedAchievementsProvider = StreamProvider<Map<String, DateTime>>(
    (ref) => ref.watch(lifestyleRepoProvider).watchUnlocked());

final challengesProvider = StreamProvider<List<ChallengeEnrollment>>(
    (ref) => ref.watch(lifestyleRepoProvider).watchChallenges());

final priceOverridesProvider = StreamProvider<Map<String, double>>(
    (ref) => ref.watch(lifestyleRepoProvider).watchPriceOverrides());

final hasActiveSessionProvider = StreamProvider<bool>(
    (ref) => ref.watch(trainingRepoProvider).watchHasActiveSession());

// ───────────────────────── derived state ─────────────────────────

final journeyProvider = Provider<JourneyState?>((ref) {
  final record = ref.watch(journeyRecordProvider).value;
  final workouts = ref.watch(workoutsProvider).value;
  final program = ref.watch(activeProgramProvider).value;
  if (record == null || workouts == null) return null;
  return computeJourney(
    start: record.startDate,
    today: ref.watch(todayProvider),
    workoutDates: [for (final w in workouts) w.date],
    plannedPerWeek: program?.spec.sessionsPerWeek ?? 3,
  );
});

final paramsProvider = Provider<TrainingParams?>((ref) {
  final p = ref.watch(profileProvider).value;
  if (p == null) return null;
  final phase = ref.watch(journeyProvider)?.phase ?? JourneyPhase.habit;
  final program = ref.watch(activeProgramProvider).value?.spec;
  // A custom (build-your-own) program's goal and frequency take precedence.
  final goals = program != null && program.custom ? program.goals : p.goals;
  final days = program?.sessionsPerWeek ?? p.daysPerWeek;
  return TrainingParams.from(goals: goals, level: p.level, phase: phase, daysPerWeek: days);
});

/// The environment for today's session (profile default, switchable).
final filterProvider = Provider<ExerciseFilter>((ref) {
  final p = ref.watch(profileProvider).value;
  return ExerciseFilter(p?.environment ?? TrainingEnvironment.livingRoom, p?.limitations ?? const Limitations());
});

/// Completion rate per area over the last 14 days (feeds the weakest link).
final recentCompletionProvider = Provider<Map<Area, double>>((ref) {
  final workouts = ref.watch(workoutsProvider).value ?? const [];
  final from = ref.watch(todayProvider).addDays(-14);
  final target = <Area, int>{}, done = <Area, int>{};
  for (final w in workouts.where((w) => !w.date.isBefore(from))) {
    for (final s in w.sets) {
      if (s.blockKind == BlockKind.warmup || s.blockKind == BlockKind.cooldown) continue;
      final area = exerciseArea(s.exerciseId);
      target[area] = (target[area] ?? 0) + s.target;
      done[area] = (done[area] ?? 0) + (s.skipped ? 0 : s.achieved.clamp(0, s.target));
    }
  }
  return {for (final a in target.keys) if (target[a]! > 0) a: done[a]! / target[a]!};
});

final weakestLinkProvider = Provider<WeakestLinkReport?>((ref) {
  final progress = ref.watch(progressProvider).value;
  final params = ref.watch(paramsProvider);
  if (progress == null || params == null) return null;
  return assessWeakestLink(progress, params, recentCompletion: ref.watch(recentCompletionProvider));
});

final bestsProvider = Provider<Map<String, int>>((ref) {
  final history = ref.watch(recordHistoryProvider).value ?? const [];
  return TrainingRepository.bestsFrom(history);
});

/// Best single-set value per exercise id (for benchmark targets).
final bestByExerciseProvider = Provider<Map<String, int>>((ref) {
  final out = <String, int>{};
  ref.watch(bestsProvider).forEach((k, v) => out[k.split('|').first] = v);
  return out;
});

final todaysRecoveryProvider = Provider<StoredRecoveryCheck?>((ref) {
  final today = ref.watch(todayProvider);
  final list = ref.watch(recoveryChecksProvider).value ?? const [];
  for (final c in list.reversed) {
    if (c.date == today) return c;
  }
  return null;
});

final missionDayProvider = Provider<MissionDay?>((ref) {
  final program = ref.watch(activeProgramProvider).value;
  final workouts = ref.watch(workoutsProvider).value;
  if (program == null || workouts == null) return null;
  return planToday(
    today: ref.watch(todayProvider),
    program: program.spec,
    programStart: program.startedOn,
    sessionDates: {for (final w in workouts) w.date},
  );
});

/// Inputs to build any session right now (null until data has loaded).
final sessionInputsProvider = Provider.family<SessionInputs?, DayType>((ref, day) {
  final p = ref.watch(profileProvider).value;
  final params = ref.watch(paramsProvider);
  final progress = ref.watch(progressProvider).value;
  final program = ref.watch(activeProgramProvider).value;
  if (p == null || params == null || progress == null) return null;
  final check = ref.watch(todaysRecoveryProvider);
  final today = ref.watch(todayProvider);
  return SessionInputs(
    dayType: day,
    params: params,
    progress: progress,
    filter: ref.watch(filterProvider),
    minutes: program?.spec.minutes ?? p.sessionMinutes,
    weakest: ref.watch(weakestLinkProvider)?.weakest,
    style: p.style,
    focus: program?.spec.focus ?? const {},
    seed: today.daysSince(const LocalDate(2024, 1, 1)),
    recovery: check == null ? RecoveryAdjustment.none : adjustForRecovery(check.check),
    bestRecords: ref.watch(bestByExerciseProvider),
  );
});

/// Today's mission plan (null on a rest day without a catch-up).
final missionPlanProvider = Provider<WorkoutPlan?>((ref) {
  final day = ref.watch(missionDayProvider);
  final type = day?.missionType;
  if (type == null) return null;
  final inputs = ref.watch(sessionInputsProvider(type));
  if (inputs == null) return null;
  return SessionBuilder(inputs).build();
});

final calendarProvider = Provider<List<CalendarDay>>((ref) {
  final program = ref.watch(activeProgramProvider).value;
  final workouts = ref.watch(workoutsProvider).value ?? const [];
  final map = <LocalDate, List<CalendarEntry>>{};
  for (final w in workouts) {
    map.putIfAbsent(w.date, () => []).add(CalendarEntry(kind: w.kind, dayType: w.dayType));
  }
  return buildCalendar(
    today: ref.watch(todayProvider),
    sessions: map,
    program: program?.spec,
    programStart: program?.startedOn ?? ref.watch(todayProvider),
  );
});

final weeklyReportProvider = Provider.family<WeeklyReport?, LocalDate>((ref, weekStart) {
  final workouts = ref.watch(workoutsProvider).value;
  final records = ref.watch(recordHistoryProvider).value;
  final measurements = ref.watch(measurementsProvider).value;
  final checks = ref.watch(recoveryChecksProvider).value;
  final program = ref.watch(activeProgramProvider).value;
  if (workouts == null || records == null || measurements == null || checks == null) return null;
  return buildWeeklyReport(
    weekStart: weekStart,
    workouts: workouts,
    records: records,
    measurements: [for (final m in measurements) m.point],
    recoveryScores: [for (final c in checks) (c.date, c.check.score)],
    program: program?.spec,
    programStart: program?.startedOn ?? weekStart,
  );
});

Area exerciseArea(String id) => exerciseById(id).area;
