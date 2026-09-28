import '../domain/catalog/achievements.dart';
import '../domain/models/enums.dart';

/// Every image the app uses. Where a generated image wasn't available, a
/// deliberate on-brand alternative is mapped here instead (see DESIGN.md).
abstract final class Img {
  static const _i = 'assets/images';

  static const logoMark = '$_i/brand/logo_mark.webp';
  static const ama = '$_i/cast/ama_reference.webp';

  // Athletes by workout type.
  static const typeUpper = '$_i/workouts/type_upper.webp';
  static const typeLower = '$_i/workouts/type_lower.webp';
  static const typeCore = '$_i/workouts/type_core.webp';
  static const typeBack = '$_i/workouts/type_back.webp';
  static const typeFull = '$_i/workouts/type_full.webp';
  static const typeConditioning = '$_i/workouts/type_conditioning.webp';
  static const typeRecovery = '$_i/workouts/type_recovery.webp';

  // Onboarding. Welcome uses Kofi's push-up (same pose family as the brief).
  static const onboardingWelcome = typeUpper;
  static const onboardingGoals = '$_i/onboarding/onboarding_goals.webp';
  static const onboardingPlan = '$_i/onboarding/onboarding_plan.webp';

  // Journey phases (athlete alternatives for the phase artwork).
  static const phaseHabit = typeLower;
  static const phaseBody = typeFull;
  static const phaseForge = typeCore;

  // Empty states. "No achievements" uses a locked lavender medallion.
  static const emptyWorkouts = '$_i/empty/empty_workouts.webp';
  static const emptyMeasurements = '$_i/empty/empty_measurements.webp';
  static const emptyRecords = '$_i/empty/empty_records.webp';
  static const emptySearch = '$_i/empty/empty_search.webp';
  static const emptyAchievements = '$_i/badges/medal_lavender.webp';

  static String medal(MedalTier t) => '$_i/badges/medal_${t.name}.webp';

  static String environment(TrainingEnvironment e) => '$_i/environments/env_${switch (e) {
        TrainingEnvironment.bedroom => 'bedroom',
        TrainingEnvironment.livingRoom => 'living_room',
        TrainingEnvironment.smallSpace => 'small_space',
        TrainingEnvironment.largeSpace => 'large_space',
        TrainingEnvironment.outside => 'outside',
        TrainingEnvironment.hotelRoom => 'hotel_room',
      }}.webp';

  static String challenge(String id) => '$_i/challenges/challenge_$id.webp';

  static String forDay(DayType d) => switch (d) {
        DayType.upper => typeUpper,
        DayType.lower => typeLower,
        DayType.core => typeCore,
        DayType.upperCore => typeUpper,
        DayType.fullBody => typeFull,
        DayType.conditioning => typeConditioning,
        DayType.recovery || DayType.rest => typeRecovery,
        DayType.benchmark => typeCore,
      };

  static String forArea(Area a) => switch (a) {
        Area.upper => typeUpper,
        Area.legs => typeLower,
        Area.core => typeCore,
        Area.conditioning => typeConditioning,
      };

  static String forPath(String pathId) => switch (pathId) {
        'push' => typeUpper,
        'legs' => typeLower,
        'core' => typeCore,
        'back' => typeBack,
        'hips' => typeRecovery,
        _ => typeConditioning,
      };

  /// Food photos that exist. Banana shares the plantain photo (it shows
  /// bananas). Foods not listed get a typographic tile drawn in code.
  static const _foods = {
    'avocado', 'banku', 'beans_red_red', 'cabbage_carrot', 'chicken', 'eggs', 'garden_eggs', 'gari', 'kelewele',
    'kenkey', 'kontomire', 'oats', 'okro', 'plantain', 'rice', 'sardines', 'soya_chunks', 'sweet_potato', 'tilapia',
    'tomato_onion', 'tuna', 'waakye', 'watermelon', 'yam',
  };

  static String? food(String id) {
    if (id == 'banana') return '$_i/foods/food_plantain.webp';
    return _foods.contains(id) ? '$_i/foods/food_$id.webp' : null;
  }
}
