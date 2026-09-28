import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class FoodDetailScreen extends ConsumerWidget {
  const FoodDetailScreen({super.key, required this.foodId});
  final String foodId;

  Future<void> _editPrice(BuildContext context, WidgetRef ref, FoodItem f, double current) async {
    final ctl = TextEditingController(text: current.toStringAsFixed(current == current.roundToDouble() ? 0 : 2));
    final result = await showBfSheet<String>(context, builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Your local price', style: t.headlineMedium),
          const SizedBox(height: 4),
          Text('For one serving: ${f.serving}', style: t.bodyMedium?.copyWith(color: ctx.bf.textMuted)),
          const SizedBox(height: Space.lg),
          TextField(
            controller: ctl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: BfType.number(30, color: ctx.bf.text),
            decoration: const InputDecoration(prefixText: 'GH₵ '),
          ),
          const SizedBox(height: Space.lg),
          BfButton(label: 'Save price', onPressed: () => Navigator.pop(ctx, ctl.text)),
          const SizedBox(height: Space.xs),
          BfButton(label: 'Use estimate (${ghs(f.priceGhs)})', kind: BfButtonKind.ghost, onPressed: () => Navigator.pop(ctx, 'reset')),
        ]),
      );
    });
    if (result == null) return;
    if (result == 'reset') {
      await ref.read(lifestyleRepoProvider).setPrice(f.id, null);
      return;
    }
    final v = double.tryParse(result.replaceAll(',', '.'));
    if (v == null || v < 0 || v > 10000) {
      if (context.mounted) toast(context, 'Enter a valid price');
      return;
    }
    await ref.read(lifestyleRepoProvider).setPrice(f.id, v);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = kFoodById[foodId];
    if (f == null) return const BfPage(title: 'Food', children: [Text('Not found')]);
    final overrides = ref.watch(priceOverridesProvider).value ?? const {};
    final price = overrides[f.id] ?? f.priceGhs;
    final custom = overrides.containsKey(f.id);
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final maxMacro = [f.protein, f.carbs, f.fat, 30.0].reduce((a, b) => a > b ? a : b);
    return BfPage(
      title: f.name,
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(color: categoryColor(f.category), borderRadius: Radii.cardLarge),
          child: Stack(children: [
            const Positioned.fill(child: ConcentricRings(color: Color(0x14000000))),
            Center(child: FoodImage(food: f, size: 190)),
          ]),
        ),
        const SizedBox(height: Space.md),
        Text(f.name, style: t.headlineLarge).enter(context),
        if (f.aka != null) Text(f.aka!, style: t.bodyMedium?.copyWith(color: c.textMuted)),
        Text('${f.category.label} · ${f.serving}', style: t.bodySmall),
        const SizedBox(height: Space.lg),
        Row(children: [
          Expanded(child: StatTile(label: 'Protein', color: c.primary, value: CountUp(value: f.protein, decimals: 1, suffix: ' g'))),
          const SizedBox(width: Space.sm),
          Expanded(child: StatTile(label: 'Calories', value: CountUp(value: f.kcal.toDouble(), suffix: ''))),
        ]).enter(context, index: 1),
        const SizedBox(height: Space.md),
        BfCard(
          child: Column(children: [
            MacroBar(label: 'Protein', grams: f.protein, max: maxMacro, color: c.primary),
            MacroBar(label: 'Carbs', grams: f.carbs, max: maxMacro, color: BfPalette.butter),
            MacroBar(label: 'Fat', grams: f.fat, max: maxMacro, color: BfPalette.peach),
          ]),
        ).enter(context, index: 2),
        const SizedBox(height: Space.md),
        BfCard(
          color: c.surfaceRaised,
          onTap: () => _editPrice(context, ref, f, price),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Overline(custom ? 'Your price' : kPriceEstimateLabel),
                Text(ghs(price), style: BfType.number(28, color: c.text)),
                Text('${f.proteinPerCedi(price).toStringAsFixed(1)} g protein per GH₵1', style: t.bodySmall),
              ]),
            ),
            const Icon(BfIcons.edit),
          ]),
        ).enter(context, index: 3),
        const SizedBox(height: Space.lg),
        Text('Tips', style: t.headlineSmall),
        const SizedBox(height: Space.sm),
        for (final tip in f.tips)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(BfIcons.tip, size: 18, color: c.primary),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(tip, style: t.bodyMedium)),
            ]),
          ),
      ],
    );
  }
}
