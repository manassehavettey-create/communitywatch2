import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/assets.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/page.dart';
import '../../data/repositories/lifestyle_repository.dart';
import '../../domain/catalog/challenges.dart';
import '../../domain/catalog/foods.dart';
import '../achievements/celebrations.dart';
import 'nutrition_widgets.dart';

/// Nutrition challenge (spec §16) with daily check-ins.
class ChallengeScreen extends ConsumerWidget {
  const ChallengeScreen({super.key, required this.challengeId});
  final String challengeId;

  Future<void> _checkIn(BuildContext context, WidgetRef ref, ChallengeEnrollment e, double value, {Map<String, Object?>? detail}) async {
    final completed = await ref.read(lifestyleRepoProvider).checkIn(e, value, detail: detail);
    Haptics.medium();
    if (!context.mounted) return;
    if (completed) {
      final fresh = await ref.read(trainingServiceProvider).checkAchievements();
      if (!context.mounted) return;
      toast(context, '${e.def.title} complete!');
      for (final a in fresh) {
        await showAchievementCelebration(context, a);
        if (!context.mounted) return;
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = kChallengeById[challengeId];
    if (def == null) return const BfPage(title: 'Challenge', children: [Text('Not found')]);
    final enrollment = (ref.watch(challengesProvider).value ?? const [])
        .where((x) => x.def.id == challengeId && !x.abandoned)
        .firstOrNull;
    final today = ref.watch(todayProvider);
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final todayValue = enrollment?.checkins[today] ?? 0;

    return BfPage(
      title: def.title,
      bottom: enrollment == null
          ? BfButton(label: 'Start challenge', onPressed: () => ref.read(lifestyleRepoProvider).startChallenge(def.id))
          : null,
      actions: [
        if (enrollment != null && !enrollment.isComplete)
          CircleIconButton(
            icon: BfIcons.close,
            tooltip: 'Leave challenge',
            background: c.surfaceRaised,
            foreground: c.text,
            onTap: () async {
              if (await confirm(context, title: 'Leave this challenge?', message: 'Your check-ins stay in your history.', confirmLabel: 'Leave')) {
                await ref.read(lifestyleRepoProvider).abandonChallenge(enrollment.id);
              }
            },
          ),
      ],
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: Radii.cardLarge),
          child: Stack(children: [
            const Positioned.fill(child: ConcentricRings()),
            Center(child: SizedBox(height: 180, child: AppImage(Img.challenge(def.id), alignment: Alignment.center))),
          ]),
        ),
        const SizedBox(height: Space.md),
        Overline(def.tagline),
        Text(def.title, style: t.headlineMedium),
        const SizedBox(height: Space.xs),
        Text(def.description, style: t.bodyMedium?.copyWith(color: c.textMuted)),
        const SizedBox(height: Space.lg),
        if (enrollment != null) ...[
          _DayTrack(enrollment: enrollment),
          const SizedBox(height: Space.lg),
          if (enrollment.isComplete)
            BfCard(
              color: c.primary,
              child: Row(children: [
                const Icon(BfIcons.trophy, color: BfPalette.ink),
                const SizedBox(width: Space.sm),
                Expanded(child: Text('Challenge complete. That\'s a habit now.', style: t.titleSmall?.copyWith(color: BfPalette.ink))),
              ]),
            ).pop(context)
          else ...[
            Text(def.dailyPrompt, style: t.headlineSmall),
            const SizedBox(height: Space.sm),
            switch (def.checkType) {
              ChallengeCheckType.yesNo => Row(children: [
                  Expanded(
                    child: BfButton(
                      label: todayValue >= 1 ? 'Done today ✓' : 'Yes, done',
                      onPressed: () => _checkIn(context, ref, enrollment, 1),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: BfButton(
                      label: 'Not today',
                      kind: BfButtonKind.ghost,
                      onPressed: () => _checkIn(context, ref, enrollment, 0),
                    ),
                  ),
                ]),
              ChallengeCheckType.counter => _GlassCounter(
                  value: todayValue.round(),
                  target: def.dailyTarget,
                  onChanged: (v) => _checkIn(context, ref, enrollment, v.toDouble()),
                ),
              ChallengeCheckType.mealBuilder => _MealBuilder(
                  def: def,
                  done: todayValue >= 1,
                  onSubmit: (items, totals) => _checkIn(context, ref, enrollment, 1, detail: {
                    'items': items,
                    'protein': totals.protein,
                    'price': totals.priceGhs,
                  }),
                ),
            },
          ],
        ],
        const SizedBox(height: Space.lg),
        Text('Tips', style: t.headlineSmall),
        const SizedBox(height: Space.sm),
        for (final tip in def.tips)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(BfIcons.tip, size: 18, color: c.primary),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(tip, style: t.bodyMedium)),
            ]),
          ),
        Text('Missed a day? It doesn\'t reset — just check in again tomorrow.', style: t.bodySmall),
      ],
    );
  }
}

class _DayTrack extends StatelessWidget {
  const _DayTrack({required this.enrollment});
  final ChallengeEnrollment enrollment;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final t = Theme.of(context).textTheme;
    final successes = enrollment.successDays;
    final req = enrollment.def.daysRequired;
    return BfCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$successes', style: BfType.number(36, color: c.accentText)),
          Text(' / $req days', style: t.titleMedium?.copyWith(color: c.textMuted)),
        ]),
        const SizedBox(height: Space.sm),
        Row(children: [
          for (var i = 0; i < req; i++)
            Expanded(
              child: Container(
                height: 36,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  color: i < successes ? c.primary : c.surfaceRaised,
                  borderRadius: Radii.small,
                ),
                child: i < successes ? const Icon(BfIcons.check, size: 18, color: BfPalette.ink) : null,
              ).animate(delay: Motion.stagger(i)).fadeIn(duration: Motion.of(context, Motion.medium)).scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1)),
            ),
        ]),
      ]),
    );
  }
}

class _GlassCounter extends StatelessWidget {
  const _GlassCounter({required this.value, required this.target, required this.onChanged});
  final int value;
  final int target;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    return BfCard(
      child: Column(children: [
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          for (var i = 0; i < target; i++)
            Pressable(
              onTap: () => onChanged(i + 1 == value ? i : i + 1),
              borderRadius: Radii.small,
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.medium),
                width: 44,
                height: 56,
                decoration: BoxDecoration(
                  color: i < value ? BfPalette.sky : c.surfaceRaised,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12), top: Radius.circular(4)),
                ),
                child: Icon(BfIcons.drop, color: i < value ? BfPalette.ink : c.textFaint),
              ),
            ),
        ]),
        const SizedBox(height: Space.md),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircleIconButton(icon: BfIcons.remove, background: c.surfaceRaised, foreground: c.text, onTap: value > 0 ? () => onChanged(value - 1) : null),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Text('$value / $target', style: BfType.number(28, color: c.text)),
          ),
          CircleIconButton(icon: BfIcons.add, onTap: () => onChanged(value + 1)),
        ]),
      ]),
    );
  }
}

/// Build today's GH₵20 meal from the food database; totals update live.
class _MealBuilder extends ConsumerStatefulWidget {
  const _MealBuilder({required this.def, required this.done, required this.onSubmit});
  final ChallengeDef def;
  final bool done;
  final void Function(Map<String, double> items, MealTotals totals) onSubmit;

  @override
  ConsumerState<_MealBuilder> createState() => _MealBuilderState();
}

class _MealBuilderState extends ConsumerState<_MealBuilder> {
  final Map<String, double> _items = {};

  @override
  Widget build(BuildContext context) {
    final overrides = ref.watch(priceOverridesProvider).value ?? const {};
    final totals = mealTotals(_items, priceOverrides: overrides);
    final okProtein = totals.protein >= widget.def.proteinTarget;
    final okPrice = totals.priceGhs <= widget.def.priceLimitGhs && totals.priceGhs > 0;
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final sorted = [...kFoods]..sort((a, b) => b.proteinPerCedi(overrides[b.id]).compareTo(a.proteinPerCedi(overrides[a.id])));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.done)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: Text('Today\'s meal is logged ✓ — build another to replace it.', style: t.bodySmall?.copyWith(color: c.accentText)),
        ),
      BfCard(
        color: okProtein && okPrice ? c.primary : c.surface,
        child: Row(children: [
          Expanded(
            child: _Gauge(
              label: 'Protein',
              value: '${totals.protein.round()} g',
              goal: '≥ ${widget.def.proteinTarget.round()} g',
              ok: okProtein,
              dark: okProtein && okPrice,
            ),
          ),
          Expanded(
            child: _Gauge(
              label: 'Cost',
              value: ghs(totals.priceGhs),
              goal: '≤ ${ghs(widget.def.priceLimitGhs)}',
              ok: okPrice,
              dark: okProtein && okPrice,
            ),
          ),
          Expanded(
            child: _Gauge(label: 'Energy', value: '${totals.kcal.round()}', goal: 'kcal', ok: true, dark: okProtein && okPrice),
          ),
        ]),
      ),
      const SizedBox(height: Space.sm),
      for (final f in sorted)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            FoodImage(food: f, size: 40, hero: false),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f.name, style: t.titleSmall),
                Text('${f.protein.round()} g · ${ghs(overrides[f.id] ?? f.priceGhs)} · ${f.serving}', style: t.labelSmall),
              ]),
            ),
            if ((_items[f.id] ?? 0) > 0) ...[
              CircleIconButton(
                icon: BfIcons.remove,
                size: 34,
                background: c.surfaceRaised,
                foreground: c.text,
                onTap: () => setState(() {
                  final v = (_items[f.id] ?? 0) - 0.5;
                  if (v <= 0) {
                    _items.remove(f.id);
                  } else {
                    _items[f.id] = v;
                  }
                }),
              ),
              SizedBox(width: 36, child: Text('${_items[f.id]}', textAlign: TextAlign.center, style: BfType.number(14, color: c.text))),
            ],
            CircleIconButton(icon: BfIcons.add, size: 34, onTap: () => setState(() => _items[f.id] = (_items[f.id] ?? 0) + 0.5)),
          ]),
        ),
      const SizedBox(height: Space.md),
      BfButton(
        label: okProtein && okPrice ? 'Log this meal' : 'Reach ${widget.def.proteinTarget.round()} g for ≤ ${ghs(widget.def.priceLimitGhs)}',
        onPressed: okProtein && okPrice ? () => widget.onSubmit({..._items}, totals) : null,
      ),
    ]);
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.label, required this.value, required this.goal, required this.ok, required this.dark});
  final String label;
  final String value;
  final String goal;
  final bool ok;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final fg = dark ? BfPalette.ink : c.text;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: BfType.overline(fg.withValues(alpha: 0.6))),
      Text(value, style: BfType.number(20, color: ok ? fg : c.warning)),
      Text(goal, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.6))),
    ]);
  }
}
