import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/assets.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../domain/catalog/challenges.dart';
import '../../domain/catalog/foods.dart';
import 'nutrition_widgets.dart';

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});
  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  int _tab = 0;
  String _q = '';
  FoodCategory? _cat;
  bool _valueSort = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final weight = ref.watch(profileProvider).value?.weightKg ?? 70;
    final protein = proteinTargetGrams(weight);
    final water = waterTargetMl(weight);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 120),
          children: [
            Text('Nutrition', style: t.displaySmall).enter(context),
            const SizedBox(height: 4),
            Text('Build a better body with food you can actually afford and find.', style: t.bodyMedium?.copyWith(color: c.textMuted))
                .enter(context, index: 1),
            const SizedBox(height: Space.lg),
            Row(children: [
              Expanded(
                child: BfCard(
                  color: c.primary,
                  rings: true,
                  onTap: () => context.push('/meals'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Overline('Daily protein', color: BfPalette.ink.withValues(alpha: 0.6)),
                    CountUp(value: protein.target.toDouble(), suffix: ' g', style: BfType.number(32, color: BfPalette.ink)),
                    Text('${protein.low}–${protein.high} g range', style: t.bodySmall?.copyWith(color: BfPalette.ink.withValues(alpha: 0.7))),
                  ]),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: BfCard(
                  color: BfPalette.sky,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Overline('Water', color: BfPalette.ink.withValues(alpha: 0.6)),
                    CountUp(value: water / 1000, decimals: 1, suffix: ' L', style: BfType.number(32, color: BfPalette.ink)),
                    Text('≈ ${(water / 250).round()} glasses', style: t.bodySmall?.copyWith(color: BfPalette.ink.withValues(alpha: 0.7))),
                  ]),
                ),
              ),
            ]).enter(context, index: 2),
            const SizedBox(height: Space.lg),
            Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
              for (final (i, l) in ['Foods', 'Meal guidance', 'Challenges'].indexed)
                PillChip(label: l, selected: _tab == i, onTap: () => i == 1 ? context.push('/meals') : setState(() => _tab = i)),
            ]),
            const SizedBox(height: Space.md),
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.medium),
              child: KeyedSubtree(key: ValueKey(_tab), child: _tab == 2 ? const _Challenges() : _foods(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _foods(BuildContext context) {
    final overrides = ref.watch(priceOverridesProvider).value ?? const {};
    final t = Theme.of(context).textTheme;
    var foods = kFoods.where((f) {
      if (_cat != null && f.category != _cat) return false;
      final q = _q.toLowerCase();
      return q.isEmpty || f.name.toLowerCase().contains(q) || (f.aka?.toLowerCase().contains(q) ?? false);
    }).toList();
    if (_valueSort) {
      foods.sort((a, b) => b.proteinPerCedi(overrides[b.id]).compareTo(a.proteinPerCedi(overrides[a.id])));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        decoration: const InputDecoration(hintText: 'Search foods (e.g. sardines, gari)', prefixIcon: Icon(BfIcons.search)),
        onChanged: (v) => setState(() => _q = v),
      ),
      const SizedBox(height: Space.sm),
      Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
        PillChip(label: 'All', dense: true, selected: _cat == null, onTap: () => setState(() => _cat = null)),
        for (final cat in FoodCategory.values)
          PillChip(label: cat.label, dense: true, selected: _cat == cat, onTap: () => setState(() => _cat = cat)),
        PillChip(
            label: 'Best protein per cedi',
            icon: BfIcons.up,
            dense: true,
            selected: _valueSort,
            onTap: () => setState(() => _valueSort = !_valueSort)),
      ]),
      const SizedBox(height: Space.md),
      if (foods.isEmpty) const EmptyState(image: Img.emptySearch, title: 'No foods found', message: 'Try a different name.'),
      for (var i = 0; i < foods.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.xs),
          child: BfCard(
            padding: const EdgeInsets.all(Space.sm),
            onTap: () => context.push('/food/${foods[i].id}'),
            child: Row(children: [
              FoodImage(food: foods[i], size: 64),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(foods[i].name, style: t.titleSmall),
                  Text(foods[i].serving, style: t.bodySmall),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${foods[i].protein.toStringAsFixed(0)} g', style: BfType.number(18, color: context.bf.accentText)),
                Text('${ghs(overrides[foods[i].id] ?? foods[i].priceGhs)} · ${foods[i].kcal} kcal', style: t.labelSmall),
              ]),
            ]),
          ),
        ).enter(context, index: i),
      const SizedBox(height: Space.sm),
      Text('$kPriceEstimateLabel — tap a food to set your local price.', textAlign: TextAlign.center, style: t.bodySmall),
    ]);
  }
}

class _Challenges extends ConsumerWidget {
  const _Challenges();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollments = ref.watch(challengesProvider).value ?? const [];
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final colors = [c.primary, BfPalette.sky, BfPalette.butter, c.secondary];
    return Column(children: [
      for (var i = 0; i < kChallenges.length; i++)
        () {
          final def = kChallenges[i];
          final e = enrollments.where((x) => x.def.id == def.id && !x.abandoned).firstOrNull;
          return Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: BfCard(
              color: colors[i],
              padding: EdgeInsets.zero,
              onTap: () => context.push('/challenge/${def.id}'),
              child: SizedBox(
                height: 132,
                child: Row(children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Overline(def.tagline, color: BfPalette.ink.withValues(alpha: 0.6)),
                        const SizedBox(height: 2),
                        Text(def.title, maxLines: 2, style: t.titleMedium?.copyWith(color: BfPalette.ink)),
                        const Spacer(),
                        if (e == null)
                          Text('Start challenge →', style: t.labelMedium?.copyWith(color: BfPalette.ink))
                        else if (e.isComplete)
                          Text('Completed ✓', style: t.labelMedium?.copyWith(color: BfPalette.ink))
                        else ...[
                          ClipRRect(
                            borderRadius: Radii.pillAll,
                            child: LinearProgressIndicator(
                              value: e.progress,
                              minHeight: 8,
                              color: BfPalette.ink,
                              backgroundColor: BfPalette.ink.withValues(alpha: 0.12),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${e.successDays} / ${def.daysRequired} days', style: t.labelSmall?.copyWith(color: BfPalette.ink)),
                        ],
                      ]),
                    ),
                  ),
                  SizedBox(width: 120, child: AppImage(Img.challenge(def.id), alignment: Alignment.center)),
                ]),
              ),
            ),
          ).enter(context, index: i);
        }(),
    ]);
  }
}
