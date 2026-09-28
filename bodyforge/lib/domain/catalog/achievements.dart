/// Achievement definitions (spec §20). Unlock logic lives in
/// `engine/achievement_evaluator.dart`; every criterion is a real action.
library;

enum MedalTier {
  /// Habit & consistency.
  lavender,

  /// Strength, PRs and skills.
  lime,

  /// Big milestones.
  ember;

  String get image => 'assets/images/badges/medal_$name.png';
}

class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.tier,
    required this.icon,
    this.target = 1,
  });

  final String id;
  final String title;
  final String description;
  final MedalTier tier;

  /// Semantic icon key mapped to an icon in the UI layer.
  final String icon;

  /// Target for progress display (e.g. 100 push-ups).
  final int target;
}

abstract final class AchievementIds {
  static const firstRep = 'first_rep';
  static const sevenDaysStrong = 'seven_days_strong';
  static const firstPr = 'first_pr';
  static const hundredPushUps = 'hundred_push_ups';
  static const thirtyWorkouts = 'thirty_workouts';
  static const coreBuilder = 'core_builder';
  static const bodyforge = 'bodyforge';
  static const skillUnlocked = 'skill_unlocked';
  static const pathMaster = 'path_master';
  static const tenPrs = 'ten_prs';
  static const thousandSquats = 'thousand_squats';
  static const plankTwoMinutes = 'plank_two_minutes';
  static const somethingBetter = 'something_better';
  static const recoveryRespected = 'recovery_respected';
  static const comeback = 'comeback';
  static const phaseOne = 'phase_one';
  static const halfwayForged = 'halfway_forged';
  static const phaseTwo = 'phase_two';
  static const measured = 'measured';
  static const consistentMonth = 'consistent_month';
  static const hydrated = 'hydrated';
  static const budgetProtein = 'budget_protein';
  static const hundredWorkouts = 'hundred_workouts';
}

const List<AchievementDef> kAchievements = [
  AchievementDef(id: AchievementIds.firstRep, title: 'FIRST REP', description: 'Completed your first workout.',
      tier: MedalTier.lavender, icon: 'bolt'),
  AchievementDef(id: AchievementIds.sevenDaysStrong, title: '7 DAYS STRONG',
      description: 'Completed every planned workout in a training week.', tier: MedalTier.lavender, icon: 'calendar'),
  AchievementDef(id: AchievementIds.firstPr, title: 'FIRST PR', description: 'Set your first personal record.',
      tier: MedalTier.lime, icon: 'trophy'),
  AchievementDef(id: AchievementIds.hundredPushUps, title: '100 PUSH-UPS',
      description: 'Completed 100 push-ups across your workouts.', tier: MedalTier.lime, icon: 'push', target: 100),
  AchievementDef(id: AchievementIds.thirtyWorkouts, title: '30 WORKOUTS', description: 'Completed 30 workouts.',
      tier: MedalTier.ember, icon: 'flame', target: 30),
  AchievementDef(id: AchievementIds.coreBuilder, title: 'CORE BUILDER', description: 'Completed 20 core sessions.',
      tier: MedalTier.lime, icon: 'core', target: 20),
  AchievementDef(id: AchievementIds.bodyforge, title: 'BODYFORGE', description: 'Completed the full 12-week journey.',
      tier: MedalTier.ember, icon: 'crown'),
  AchievementDef(id: AchievementIds.skillUnlocked, title: 'LEVEL UP',
      description: 'Unlocked a harder variation on a skill path.', tier: MedalTier.lime, icon: 'unlock'),
  AchievementDef(id: AchievementIds.pathMaster, title: 'PATH MASTER',
      description: 'Reached the final skill on any path.', tier: MedalTier.ember, icon: 'summit'),
  AchievementDef(id: AchievementIds.tenPrs, title: 'RECORD BREAKER', description: 'Set 10 personal records.',
      tier: MedalTier.lime, icon: 'trophy', target: 10),
  AchievementDef(id: AchievementIds.thousandSquats, title: '1,000 SQUATS',
      description: 'Completed 1,000 squat-family reps.', tier: MedalTier.lime, icon: 'legs', target: 1000),
  AchievementDef(id: AchievementIds.plankTwoMinutes, title: 'IRON CORE', description: 'Held a plank for 2 minutes.',
      tier: MedalTier.lime, icon: 'timer'),
  AchievementDef(id: AchievementIds.somethingBetter, title: 'SOMETHING > NOTHING',
      description: 'Completed a quick session on a low-motivation day.', tier: MedalTier.lavender, icon: 'spark'),
  AchievementDef(id: AchievementIds.recoveryRespected, title: 'RECOVERY RESPECTED',
      description: 'Completed 5 recovery sessions.', tier: MedalTier.lavender, icon: 'leaf', target: 5),
  AchievementDef(id: AchievementIds.comeback, title: 'THE COMEBACK',
      description: 'Came back and trained after 7+ days off.', tier: MedalTier.lavender, icon: 'return'),
  AchievementDef(id: AchievementIds.phaseOne, title: 'HABIT BUILT',
      description: 'Finished phase 1 of the journey: Build the Habit.', tier: MedalTier.lavender, icon: 'flag'),
  AchievementDef(id: AchievementIds.halfwayForged, title: 'HALFWAY FORGED',
      description: 'Completed 6 weeks of the journey.', tier: MedalTier.lavender, icon: 'half'),
  AchievementDef(id: AchievementIds.phaseTwo, title: 'BODY BUILT',
      description: 'Finished phase 2 of the journey: Build the Body.', tier: MedalTier.lime, icon: 'flag'),
  AchievementDef(id: AchievementIds.measured, title: 'MEASURED', description: 'Logged your first body measurement.',
      tier: MedalTier.lavender, icon: 'ruler'),
  AchievementDef(id: AchievementIds.consistentMonth, title: 'CONSISTENT MONTH',
      description: '80%+ consistency across 30 days with at least 8 workouts.', tier: MedalTier.ember,
      icon: 'calendar'),
  AchievementDef(id: AchievementIds.hydrated, title: 'HYDRATED', description: 'Completed the 7-Day Water Challenge.',
      tier: MedalTier.lavender, icon: 'drop'),
  AchievementDef(id: AchievementIds.budgetProtein, title: 'BUDGET PROTEIN',
      description: 'Completed the GH₵20 Protein Challenge.', tier: MedalTier.lime, icon: 'food'),
  AchievementDef(id: AchievementIds.hundredWorkouts, title: '100 WORKOUTS', description: 'Completed 100 workouts.',
      tier: MedalTier.ember, icon: 'flame', target: 100),
];

final Map<String, AchievementDef> kAchievementById = {for (final a in kAchievements) a.id: a};
