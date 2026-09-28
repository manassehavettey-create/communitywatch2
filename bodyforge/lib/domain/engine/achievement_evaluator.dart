import '../catalog/achievements.dart';
import '../models/enums.dart';
import '../models/local_date.dart';
import '../models/workout.dart';

/// Aggregated facts about the user's real actions.
class AchievementStats {
  const AchievementStats({
    this.totalWorkouts = 0,
    this.pushUpReps = 0,
    this.squatReps = 0,
    this.prCount = 0,
    this.coreSessions = 0,
    this.maxPlankSec = 0,
    this.lowMotivationSessions = 0,
    this.recoverySessions = 0,
    this.comeback = false,
    this.fullWeek = false,
    this.journeyCountedWeeks = 0,
    this.journeyComplete = false,
    this.measurementCount = 0,
    this.consistency30 = 0,
    this.workouts30 = 0,
    this.completedChallenges = const {},
    this.unlockCount = 0,
    this.pathMastered = false,
  });

  final int totalWorkouts;
  final int pushUpReps;
  final int squatReps;
  final int prCount;
  final int coreSessions;
  final int maxPlankSec;
  final int lowMotivationSessions;
  final int recoverySessions;
  final bool comeback;
  final bool fullWeek;
  final int journeyCountedWeeks;
  final bool journeyComplete;
  final int measurementCount;
  final double consistency30;
  final int workouts30;
  final Set<String> completedChallenges;
  final int unlockCount;
  final bool pathMastered;
}

/// Current value toward an achievement (for progress bars).
int achievementProgress(String id, AchievementStats s) => switch (id) {
      AchievementIds.firstRep => s.totalWorkouts.clamp(0, 1),
      AchievementIds.sevenDaysStrong => s.fullWeek ? 1 : 0,
      AchievementIds.firstPr => s.prCount.clamp(0, 1),
      AchievementIds.hundredPushUps => s.pushUpReps,
      AchievementIds.thirtyWorkouts => s.totalWorkouts,
      AchievementIds.coreBuilder => s.coreSessions,
      AchievementIds.bodyforge => s.journeyComplete ? 1 : 0,
      AchievementIds.skillUnlocked => s.unlockCount.clamp(0, 1),
      AchievementIds.pathMaster => s.pathMastered ? 1 : 0,
      AchievementIds.tenPrs => s.prCount,
      AchievementIds.thousandSquats => s.squatReps,
      AchievementIds.plankTwoMinutes => s.maxPlankSec >= 120 ? 1 : 0,
      AchievementIds.somethingBetter => s.lowMotivationSessions.clamp(0, 1),
      AchievementIds.recoveryRespected => s.recoverySessions,
      AchievementIds.comeback => s.comeback ? 1 : 0,
      AchievementIds.phaseOne => s.journeyCountedWeeks >= 4 ? 1 : 0,
      AchievementIds.halfwayForged => s.journeyCountedWeeks >= 6 ? 1 : 0,
      AchievementIds.phaseTwo => s.journeyCountedWeeks >= 8 ? 1 : 0,
      AchievementIds.measured => s.measurementCount.clamp(0, 1),
      AchievementIds.consistentMonth => (s.consistency30 >= 0.8 && s.workouts30 >= 8) ? 1 : 0,
      AchievementIds.hydrated => s.completedChallenges.contains('water_7') ? 1 : 0,
      AchievementIds.budgetProtein => s.completedChallenges.contains('protein_20') ? 1 : 0,
      AchievementIds.hundredWorkouts => s.totalWorkouts,
      _ => 0,
    };

bool isAchieved(AchievementDef def, AchievementStats s) => achievementProgress(def.id, s) >= def.target;

/// Achievements newly earned given [alreadyUnlocked] (spec §20).
List<AchievementDef> evaluateAchievements(AchievementStats stats, Set<String> alreadyUnlocked) => [
      for (final a in kAchievements)
        if (!alreadyUnlocked.contains(a.id) && isAchieved(a, stats)) a
    ];

/// Workout-derived stats. [sessionsPerWeek] is the plan's weekly count.
({
  int total,
  int pushUps,
  int squats,
  int coreSessions,
  int maxPlank,
  int lowMotivation,
  int recovery,
  bool comeback,
  bool fullWeek,
}) workoutStats(List<CompletedWorkout> workouts, int sessionsPerWeek) {
  var push = 0, squat = 0, core = 0, maxPlank = 0, low = 0, rec = 0;
  for (final w in workouts) {
    push += w.repsForFamily('push_up');
    squat += w.repsForFamily('squat');
    if (w.dayType == DayType.core || w.dayType == DayType.upperCore || w.setsInArea(Area.core) >= 3) core++;
    if (w.kind == SessionKind.lowMotivation) low++;
    if (w.isRecovery) rec++;
    for (final s in w.sets) {
      if (s.skipped) continue;
      if (s.exerciseId == 'plank' || s.exerciseId == 'long_lever_plank') {
        if (s.achieved > maxPlank) maxPlank = s.achieved;
      }
    }
  }

  final dates = [for (final w in workouts) w.date]..sort();
  var comeback = false;
  for (var i = 1; i < dates.length; i++) {
    if (dates[i].daysSince(dates[i - 1]) >= 7) {
      comeback = true;
      break;
    }
  }

  final perWeek = <LocalDate, Set<LocalDate>>{};
  for (final d in dates) {
    perWeek.putIfAbsent(d.startOfWeek, () => {}).add(d);
  }
  final need = sessionsPerWeek < 1 ? 1 : sessionsPerWeek;
  final fullWeek = perWeek.values.any((days) => days.length >= need);

  return (
    total: workouts.length,
    pushUps: push,
    squats: squat,
    coreSessions: core,
    maxPlank: maxPlank,
    lowMotivation: low,
    recovery: rec,
    comeback: comeback,
    fullWeek: fullWeek,
  );
}
