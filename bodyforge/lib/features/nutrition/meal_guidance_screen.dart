import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/page.dart';
import '../../domain/catalog/foods.dart';
import 'nutrition_widgets.dart';

/// Meal guidance: simple plate rules and affordable local meal ideas — no
/// complicated bodybuilding diets.
class MealGuidanceScreen extends ConsumerWidget {
  const MealGuidanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final weight = ref.watch(profileProvider).value?.weightKg ?? 70;
    final overrides = ref.watch(priceOverridesProvider).value ?? const {};
    final protein = proteinTargetGrams(weight);
    var i = 0;
    return BfPage(
      title: 'Meal guidance',
      children: [
        Text('Keep it simple.', style: t.headlineLarge).enter(context, index: i++),
        const SizedBox(height: 4),
        Text('No complicated diets. Build every plate the same way, with food you can find.',
                style: t.bodyMedium?.copyWith(color: c.textMuted))
            .enter(context, index: i++),
        const SizedBox(height: Space.lg),
        BfCard(
          color: c.primary,
          rings: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Overline('Build your plate', color: BfPalette.ink.withValues(alpha: 0.6)),
            const SizedBox(height: Space.sm),
            for (final (icon, title, body) in [
              (BfIcons.food, 'A palm of protein', 'Eggs, beans, sardines, fish, chicken, soya or wagashi — at every meal.'),
              (BfIcons.leaf, 'Half the plate vegetables', 'Garden eggs, okro, kontomire, cabbage, tomato — fill up for little.'),
              (BfIcons.bolt, 'A fist of energy food', 'Rice, yam, plantain, kenkey, banku. Bigger on training days.'),
              (BfIcons.drop, 'Water first', 'Swap soft drinks for water. Add lime if you like.'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, color: BfPalette.ink, size: 20),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: t.titleSmall?.copyWith(color: BfPalette.ink)),
                      Text(body, style: t.bodySmall?.copyWith(color: BfPalette.ink.withValues(alpha: 0.75))),
                    ]),
                  ),
                ]),
              ),
          ]),
        ).enter(context, index: i++),
        const SizedBox(height: Space.md),
        BfCard(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Overline('Your protein target'),
                Text('${protein.target} g / day', style: BfType.number(26, color: c.text)),
                Text('About ${(protein.target / 4).round()} g at each of 4 meals/snacks. Range ${protein.low}–${protein.high} g.', style: t.bodySmall),
              ]),
            ),
          ]),
        ).enter(context, index: i++),
        const SizedBox(height: Space.lg),
        Text('Affordable meal ideas', style: t.headlineSmall),
        const SizedBox(height: Space.sm),
        for (final m in kMealIdeas)
          () {
            final totals = mealTotals(m.items, priceOverrides: overrides);
            return Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: BfCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Overline(m.slot),
                        Text(m.name, style: t.titleMedium),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${totals.protein.round()} g', style: BfType.number(20, color: c.accentText)),
                      Text('${ghs(totals.priceGhs)} · ${totals.kcal.round()} kcal', style: t.labelSmall),
                    ]),
                  ]),
                  const SizedBox(height: Space.sm),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final e in m.items.entries)
                      if (kFoodById[e.key] != null)
                        Pressable(
                          onTap: () => context.push('/food/${e.key}'),
                          borderRadius: Radii.pillAll,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
                            decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: Radii.pillAll),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              FoodImage(food: kFoodById[e.key]!, size: 26, hero: false),
                              const SizedBox(width: 4),
                              Text('${e.value == 1 ? '' : '${e.value}× '}${kFoodById[e.key]!.name}', style: t.labelSmall?.copyWith(color: c.text)),
                            ]),
                          ),
                        ),
                  ]),
                  if (m.note != null) ...[const SizedBox(height: Space.sm), Text(m.note!, style: t.bodySmall)],
                ]),
              ),
            ).enter(context, index: i++);
          }(),
        const SizedBox(height: Space.md),
        BfCard(
          color: c.surfaceRaised,
          child: Text(
            'Fat loss comes from eating a little less energy than you use over time — not from any single food, and '
            'not from ab exercises alone. Keep protein high, fill up on vegetables, and let consistency do the work.',
            style: t.bodySmall?.copyWith(color: c.text),
          ),
        ),
      ],
    );
  }
}
