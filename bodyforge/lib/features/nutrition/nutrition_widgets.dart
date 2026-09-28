import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/components.dart';
import '../../domain/catalog/foods.dart';

Color categoryColor(FoodCategory c) => switch (c) {
      FoodCategory.protein => BfPalette.peach,
      FoodCategory.carbs => BfPalette.butter,
      FoodCategory.vegetables => BfPalette.mint,
      FoodCategory.fruit => BfPalette.coral,
      FoodCategory.fats => BfPalette.sky,
      FoodCategory.meals => BfPalette.lilac,
    };

/// Food photo, or the typographic tile for foods without one.
class FoodImage extends StatelessWidget {
  const FoodImage({super.key, required this.food, this.size = 84, this.hero = true});
  final FoodItem food;
  final double size;

  /// Only one widget per screen may carry a food's Hero tag.
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final path = Img.food(food.id);
    final tile = MonogramTile(text: food.name, color: categoryColor(food.category), size: size);
    return SizedBox.square(
      dimension: size,
      child: () {
        final img = path == null ? tile : AppImage(path, alignment: Alignment.center, fallback: tile);
        return hero ? Hero(tag: 'food-${food.id}', child: img) : img;
      }(),
    );
  }
}

String ghs(double v) => 'GH₵${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}';

class MacroBar extends StatelessWidget {
  const MacroBar({super.key, required this.label, required this.grams, required this.max, required this.color});
  final String label;
  final double grams;
  final double max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: 72, child: Text(label, style: t.labelMedium)),
        Expanded(
          child: ClipRRect(
            borderRadius: Radii.pillAll,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (grams / max).clamp(0, 1)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 10, color: color, backgroundColor: context.bf.surfaceRaised),
            ),
          ),
        ),
        SizedBox(width: 56, child: Text('${grams.toStringAsFixed(grams < 10 ? 1 : 0)} g', textAlign: TextAlign.right, style: t.labelMedium)),
      ]),
    );
  }
}
