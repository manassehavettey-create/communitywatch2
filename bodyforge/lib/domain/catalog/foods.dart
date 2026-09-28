/// Built-in, offline food database focused on affordable, familiar foods in
/// Ghana / West Africa. Nutrition values are typical per-serving estimates.
/// Prices are rough GH₵ estimates the user can override on their phone.
library;

enum FoodCategory {
  protein('Protein'),
  carbs('Energy foods'),
  vegetables('Vegetables'),
  fruit('Fruit'),
  fats('Nuts & healthy fats'),
  meals('Local meals');

  const FoodCategory(this.label);
  final String label;
}

class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.serving,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.priceGhs,
    required this.tips,
    this.aka,
  });

  final String id;
  final String name;
  final String? aka;
  final FoodCategory category;
  final String serving;
  final int kcal;
  final double protein;
  final double carbs;
  final double fat;

  /// Approximate price for one serving in Ghana cedis.
  final double priceGhs;
  final List<String> tips;

  /// Protein per GH₵1 — "value for money" metric.
  double proteinPerCedi([double? price]) {
    final p = price ?? priceGhs;
    return p <= 0 ? 0 : protein / p;
  }

  bool get isProteinSource => protein >= 10;
  String get image => 'assets/images/foods/food_$id.png';
}

/// When the bundled prices were estimated. Shown next to every price.
const kPriceEstimateLabel = 'Estimated prices · Sep 2026';

const List<FoodItem> kFoods = [
  // Protein
  FoodItem(id: 'eggs', name: 'Eggs', category: FoodCategory.protein, serving: '2 large eggs', kcal: 143,
      protein: 12.6, carbs: 0.7, fat: 9.5, priceGhs: 5,
      tips: ['One of the cheapest complete proteins you can buy.', 'Boil a batch for quick breakfasts and snacks.',
        'Eat the yolk — it carries half the protein and most of the vitamins.']),
  FoodItem(id: 'beans_red_red', name: 'Red-red', aka: 'Black-eyed bean stew', category: FoodCategory.protein,
      serving: '1 bowl (250 g)', kcal: 350, protein: 13, carbs: 40, fat: 15, priceGhs: 8,
      tips: ['Beans give protein and fibre that keep you full.', 'Go lighter on the palm oil when cutting body fat.',
        'Add an egg or sardines to push the protein past 20 g.']),
  FoodItem(id: 'sardines', name: 'Sardines', category: FoodCategory.protein, serving: '1 tin (≈ 90 g drained)',
      kcal: 190, protein: 21, carbs: 0, fat: 11, priceGhs: 15,
      tips: ['Protein plus omega-3 fats in one tin.', 'Eat the soft bones for extra calcium.',
        'Great with kenkey, bread or gari.']),
  FoodItem(id: 'tuna', name: 'Tuna', category: FoodCategory.protein, serving: '1 tin (≈ 110 g drained)', kcal: 150,
      protein: 27, carbs: 0, fat: 4, priceGhs: 22,
      tips: ['Choose tuna in water or brine for fewer calories.', 'Mix with tomato and onion for a quick salad.']),
  FoodItem(id: 'chicken', name: 'Chicken', category: FoodCategory.protein, serving: 'Thigh + drumstick (150 g)',
      kcal: 330, protein: 36, carbs: 0, fat: 20, priceGhs: 20,
      tips: ['Remove the skin to cut the fat by about a third.', 'Grill or boil instead of deep-frying.']),
  FoodItem(id: 'tilapia', name: 'Tilapia', category: FoodCategory.protein, serving: '1 medium fish (150 g edible)',
      kcal: 190, protein: 39, carbs: 0, fat: 4, priceGhs: 35,
      tips: ['Very lean, very high protein.', 'Grilled tilapia with banku is a strong post-workout meal.']),
  FoodItem(id: 'mackerel', name: 'Mackerel', aka: '"Salmon" / smoked fish', category: FoodCategory.protein,
      serving: '100 g', kcal: 250, protein: 22, carbs: 0, fat: 17, priceGhs: 15,
      tips: ['Rich in healthy fats.', 'Smoked fish adds protein to any stew for little money.']),
  FoodItem(id: 'milk', name: 'Milk', category: FoodCategory.protein, serving: '1 cup (250 ml)', kcal: 150,
      protein: 8, carbs: 12, fat: 8, priceGhs: 6,
      tips: ['Powdered milk is often the cheapest per gram of protein.', 'Add to oats or tea for easy protein.']),
  FoodItem(id: 'wagashi', name: 'Wagashi', aka: 'Wagashie cheese', category: FoodCategory.protein,
      serving: '100 g', kcal: 260, protein: 20, carbs: 3, fat: 18, priceGhs: 10,
      tips: ['A local cheese that is high in protein.', 'Grill or add to stew instead of deep-frying.']),
  FoodItem(id: 'soya_chunks', name: 'Soya chunks', category: FoodCategory.protein, serving: '50 g dry',
      kcal: 170, protein: 26, carbs: 16, fat: 0.5, priceGhs: 4,
      tips: ['One of the best protein-per-cedi foods.', 'Soak, squeeze and cook in stew like meat.']),

  // Energy foods
  FoodItem(id: 'rice', name: 'Rice', category: FoodCategory.carbs, serving: '1 cup cooked (160 g)', kcal: 205,
      protein: 4.3, carbs: 45, fat: 0.4, priceGhs: 4,
      tips: ['Match the portion to your activity — bigger on training days.', 'Pair with beans for more protein.']),
  FoodItem(id: 'oats', name: 'Oats', category: FoodCategory.carbs, serving: '40 g dry', kcal: 150, protein: 5,
      carbs: 27, fat: 2.5, priceGhs: 3,
      tips: ['Slow energy that keeps you full.', 'Cook with milk and top with groundnuts for a protein breakfast.']),
  FoodItem(id: 'plantain', name: 'Plantain', category: FoodCategory.carbs, serving: '1 medium, boiled (180 g)',
      kcal: 210, protein: 2, carbs: 55, fat: 0.3, priceGhs: 5,
      tips: ['Boiled or roasted plantain has far fewer calories than fried.', 'Unripe plantain keeps you fuller.']),
  FoodItem(id: 'kelewele', name: 'Kelewele', category: FoodCategory.carbs, serving: '1 small bowl (150 g)',
      kcal: 300, protein: 2, carbs: 45, fat: 13, priceGhs: 10,
      tips: ['Delicious, but fried — keep it as an occasional treat.', 'Eat with groundnuts for some protein.']),
  FoodItem(id: 'yam', name: 'Yam', category: FoodCategory.carbs, serving: '2 boiled slices (200 g)', kcal: 230,
      protein: 3, carbs: 55, fat: 0.3, priceGhs: 6,
      tips: ['Great fuel before training.', 'Pair with kontomire stew and egg for a complete meal.']),
  FoodItem(id: 'sweet_potato', name: 'Sweet potato', category: FoodCategory.carbs, serving: '200 g', kcal: 180,
      protein: 4, carbs: 41, fat: 0.3, priceGhs: 4,
      tips: ['Packed with vitamin A.', 'Boil or roast with the skin on for more fibre.']),
  FoodItem(id: 'gari', name: 'Gari', category: FoodCategory.carbs, serving: '50 g dry', kcal: 180, protein: 0.5,
      carbs: 43, fat: 0.3, priceGhs: 2,
      tips: ['Cheap energy but almost no protein.', 'Soak with milk and groundnuts to make it a better meal.']),
  FoodItem(id: 'kenkey', name: 'Kenkey', category: FoodCategory.carbs, serving: '1 ball (300 g)', kcal: 400,
      protein: 8, carbs: 85, fat: 3, priceGhs: 5,
      tips: ['Fermented corn is easy on the stomach for many people.', 'Classic with fish and pepper for protein.']),
  FoodItem(id: 'banku', name: 'Banku', category: FoodCategory.carbs, serving: '1 ball (300 g)', kcal: 350,
      protein: 7, carbs: 75, fat: 2, priceGhs: 5,
      tips: ['Pair with okro soup and fish or tilapia.', 'Half a ball is plenty on rest days.']),

  // Local meals
  FoodItem(id: 'waakye', name: 'Waakye', category: FoodCategory.meals, serving: '1 plate (300 g)', kcal: 450,
      protein: 14, carbs: 85, fat: 5, priceGhs: 12,
      tips: ['Rice and beans together make better protein.', 'Add egg or fish; go easy on spaghetti and gari.']),
  FoodItem(id: 'kontomire', name: 'Kontomire stew', aka: 'Cocoyam leaf stew with egg',
      category: FoodCategory.meals, serving: '1 bowl (250 g)', kcal: 220, protein: 10, carbs: 10, fat: 15,
      priceGhs: 10,
      tips: ['Iron-rich leafy greens.', 'Add more egg or wagashi for extra protein.']),

  // Vegetables
  FoodItem(id: 'garden_eggs', name: 'Garden eggs', category: FoodCategory.vegetables, serving: '100 g', kcal: 25,
      protein: 1, carbs: 6, fat: 0, priceGhs: 3,
      tips: ['Very low calorie, adds volume to stews.', 'Great for filling up while losing fat.']),
  FoodItem(id: 'okro', name: 'Okro', category: FoodCategory.vegetables, serving: '100 g', kcal: 33, protein: 2,
      carbs: 7, fat: 0.2, priceGhs: 3,
      tips: ['High in fibre.', 'Okro soup with fish is a light, high-protein dinner.']),
  FoodItem(id: 'tomato_onion', name: 'Tomatoes & onions', category: FoodCategory.vegetables, serving: '100 g',
      kcal: 25, protein: 1, carbs: 5, fat: 0, priceGhs: 5,
      tips: ['The base of most stews — use plenty.', 'Fresh pepper sauce adds flavour for almost no calories.']),
  FoodItem(id: 'cabbage_carrot', name: 'Cabbage & carrots', category: FoodCategory.vegetables, serving: '150 g',
      kcal: 45, protein: 1.5, carbs: 10, fat: 0.2, priceGhs: 4,
      tips: ['Cheap and crunchy — perfect for a quick salad.', 'Add to fried rice or stew to bulk up the meal.']),

  // Fruit
  FoodItem(id: 'banana', name: 'Banana', category: FoodCategory.fruit, serving: '1 medium', kcal: 105,
      protein: 1.3, carbs: 27, fat: 0.4, priceGhs: 1.5,
      tips: ['Quick energy before a workout.', 'Slice into oats for breakfast.']),
  FoodItem(id: 'orange', name: 'Orange', category: FoodCategory.fruit, serving: '1 medium', kcal: 60, protein: 1.2,
      carbs: 15, fat: 0.2, priceGhs: 1.5,
      tips: ['Vitamin C and water in one.', 'A far better choice than soft drinks.']),
  FoodItem(id: 'pawpaw', name: 'Pawpaw', category: FoodCategory.fruit, serving: '1 cup (150 g)', kcal: 60,
      protein: 0.7, carbs: 16, fat: 0.4, priceGhs: 3,
      tips: ['Good for digestion.', 'Low calorie and sweet.']),
  FoodItem(id: 'pineapple', name: 'Pineapple', category: FoodCategory.fruit, serving: '1 cup (165 g)', kcal: 82,
      protein: 0.9, carbs: 22, fat: 0.2, priceGhs: 4,
      tips: ['Sweet and hydrating.', 'Great after training.']),
  FoodItem(id: 'watermelon', name: 'Watermelon', category: FoodCategory.fruit, serving: '2 slices (300 g)',
      kcal: 90, protein: 1.8, carbs: 23, fat: 0.5, priceGhs: 4,
      tips: ['Over 90% water — great on hot days.', 'Low calorie for how much you get.']),
  FoodItem(id: 'avocado', name: 'Avocado', category: FoodCategory.fats, serving: 'Half (100 g)', kcal: 160,
      protein: 2, carbs: 9, fat: 15, priceGhs: 4,
      tips: ['Healthy fats that keep you full.', 'Mash on bread instead of margarine.']),

  // Nuts
  FoodItem(id: 'groundnuts', name: 'Groundnuts', category: FoodCategory.fats, serving: '1 handful (30 g)',
      kcal: 170, protein: 7.5, carbs: 5, fat: 14, priceGhs: 3,
      tips: ['Protein and healthy fats, but calorie-dense — measure a handful.',
        'Groundnut soup with fish or chicken is a great protein meal.']),
];

final Map<String, FoodItem> kFoodById = {for (final f in kFoods) f.id: f};

/// A suggested meal built from database foods.
class MealIdea {
  const MealIdea({required this.id, required this.name, required this.slot, required this.items, this.note});
  final String id;
  final String name;
  final String slot; // Breakfast / Lunch / Dinner / Snack
  /// foodId -> servings
  final Map<String, double> items;
  final String? note;
}

const List<MealIdea> kMealIdeas = [
  MealIdea(id: 'm_oats_power', name: 'Power oats', slot: 'Breakfast',
      items: {'oats': 1, 'milk': 1, 'groundnuts': 0.5, 'banana': 1}, note: 'Cook oats in milk, top with groundnuts and banana.'),
  MealIdea(id: 'm_egg_yam', name: 'Boiled yam & eggs', slot: 'Breakfast', items: {'yam': 1, 'eggs': 1, 'tomato_onion': 1},
      note: 'Add fresh pepper sauce for flavour.'),
  MealIdea(id: 'm_redred_egg', name: 'Red-red with egg & plantain', slot: 'Lunch',
      items: {'beans_red_red': 1, 'eggs': 0.5, 'plantain': 1}),
  MealIdea(id: 'm_waakye_fish', name: 'Waakye with egg & fish', slot: 'Lunch',
      items: {'waakye': 1, 'eggs': 0.5, 'mackerel': 0.5}, note: 'Skip the spaghetti and extra gari when cutting.'),
  MealIdea(id: 'm_kenkey_sardine', name: 'Kenkey & sardines', slot: 'Dinner',
      items: {'kenkey': 1, 'sardines': 1, 'tomato_onion': 1}),
  MealIdea(id: 'm_banku_tilapia', name: 'Banku & tilapia', slot: 'Dinner', items: {'banku': 1, 'tilapia': 1, 'okro': 1}),
  MealIdea(id: 'm_soya_rice', name: 'Soya stew & rice', slot: 'Dinner',
      items: {'rice': 1, 'soya_chunks': 1, 'tomato_onion': 1, 'cabbage_carrot': 1}, note: 'Top protein per cedi.'),
  MealIdea(id: 'm_gari_milk', name: 'Gari soakings upgrade', slot: 'Snack',
      items: {'gari': 1, 'milk': 1, 'groundnuts': 1}, note: 'Milk and groundnuts turn gari into a real snack.'),
];

class MealTotals {
  const MealTotals(this.kcal, this.protein, this.carbs, this.fat, this.priceGhs);
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double priceGhs;
}

/// Sums a food→servings map. [priceOverrides] replaces bundled prices.
MealTotals mealTotals(Map<String, double> items, {Map<String, double> priceOverrides = const {}}) {
  double kcal = 0, p = 0, c = 0, f = 0, price = 0;
  items.forEach((id, servings) {
    final food = kFoodById[id];
    if (food == null) return;
    kcal += food.kcal * servings;
    p += food.protein * servings;
    c += food.carbs * servings;
    f += food.fat * servings;
    price += (priceOverrides[id] ?? food.priceGhs) * servings;
  });
  return MealTotals(kcal, p, c, f, price);
}

/// Daily protein guidance in grams (1.6 g/kg is the evidence-based sweet spot
/// for muscle gain; range shown 1.2–2.0 g/kg).
({int low, int target, int high}) proteinTargetGrams(double weightKg) => (
      low: (weightKg * 1.2).round(),
      target: (weightKg * 1.6).round(),
      high: (weightKg * 2.0).round(),
    );

/// Daily water guidance in millilitres (~35 ml/kg).
int waterTargetMl(double weightKg) => ((weightKg * 35) / 250).round() * 250;
