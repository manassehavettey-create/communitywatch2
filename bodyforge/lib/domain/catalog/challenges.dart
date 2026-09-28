/// Nutrition challenges (spec §16). Each one needs [daysRequired] successful
/// check-ins. Missing a day never fails a challenge — you just keep going.
library;

enum ChallengeCheckType {
  /// Simple yes/no for the day.
  yesNo,

  /// A counter with a daily target (e.g. glasses of water).
  counter,

  /// A meal built in the meal builder that must meet protein/price targets.
  mealBuilder,
}

class ChallengeDef {
  const ChallengeDef({
    required this.id,
    required this.title,
    required this.tagline,
    required this.description,
    required this.dailyPrompt,
    required this.checkType,
    required this.tips,
    this.daysRequired = 7,
    this.dailyTarget = 1,
    this.proteinTarget = 0,
    this.priceLimitGhs = 0,
    this.achievementId,
  });

  final String id;
  final String title;
  final String tagline;
  final String description;
  final String dailyPrompt;
  final ChallengeCheckType checkType;
  final List<String> tips;
  final int daysRequired;

  /// For counters (e.g. 8 glasses).
  final int dailyTarget;

  /// For meal builder challenges.
  final double proteinTarget;
  final double priceLimitGhs;
  final String? achievementId;

  String get image => 'assets/images/challenges/challenge_${switch (id) {
        'protein_20' => 'protein_20',
        'water_7' => 'water_7',
        'breakfast_7' => 'breakfast_7',
        _ => 'no_soda_7',
      }}.png';

  /// Whether a day's value counts as a success.
  bool isSuccess(double value) => switch (checkType) {
        ChallengeCheckType.yesNo => value >= 1,
        ChallengeCheckType.counter => value >= dailyTarget,
        ChallengeCheckType.mealBuilder => value >= 1,
      };
}

const List<ChallengeDef> kChallenges = [
  ChallengeDef(
    id: 'protein_20',
    title: 'GH₵20 Protein Challenge',
    tagline: 'Big protein, small budget',
    description: 'Build a protein-focused meal with at least 25 g of protein for GH₵20 or less, using everyday foods. '
        'Do it on 7 different days.',
    dailyPrompt: 'Build today\'s GH₵20 meal',
    checkType: ChallengeCheckType.mealBuilder,
    proteinTarget: 25,
    priceLimitGhs: 20,
    achievementId: 'budget_protein',
    tips: ['Eggs, sardines, beans, soya chunks and groundnuts give the most protein per cedi.',
      'Combine a cheap carb (gari, kenkey, rice) with one strong protein.',
      'Set your local prices in the food database so the totals match your market.'],
  ),
  ChallengeDef(
    id: 'water_7',
    title: '7-Day Water Challenge',
    tagline: 'Build a hydration habit',
    description: 'Drink your daily water target on 7 days. Tap a glass each time you finish one.',
    dailyPrompt: 'Glasses of water today',
    checkType: ChallengeCheckType.counter,
    dailyTarget: 8,
    achievementId: 'hydrated',
    tips: ['Keep a filled bottle where you can see it.', 'Drink a glass as soon as you wake up.',
      'Drink more on hot days and training days.'],
  ),
  ChallengeDef(
    id: 'breakfast_7',
    title: '7-Day Breakfast Challenge',
    tagline: 'Start the day strong',
    description: 'Eat a breakfast with a protein source (eggs, milk, groundnuts, beans…) on 7 days.',
    dailyPrompt: 'Did you eat a protein breakfast today?',
    checkType: ChallengeCheckType.yesNo,
    tips: ['Boil eggs the night before.', 'Oats with milk and groundnuts takes 5 minutes.',
      'Koko with groundnuts and an egg beats koko alone.'],
  ),
  ChallengeDef(
    id: 'no_soda_7',
    title: 'No Soft Drink Challenge',
    tagline: 'Cut the sugar',
    description: 'Go 7 days without sugary soft drinks or sweetened juice.',
    dailyPrompt: 'Soft-drink free today?',
    checkType: ChallengeCheckType.yesNo,
    tips: ['A single 500 ml soft drink can hold more than 10 teaspoons of sugar.',
      'Swap for water with lime, or sobolo without added sugar.', 'Check the label on "juice" drinks too.'],
  ),
];

final Map<String, ChallengeDef> kChallengeById = {for (final c in kChallenges) c.id: c};
