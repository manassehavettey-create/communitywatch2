import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/page.dart';
import '../../domain/catalog/exercises.dart';
import '../../domain/catalog/skill_paths.dart';
import '../../domain/engine/records.dart';
import 'exercise_figure.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});
  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ex = kExerciseById[exerciseId];
    if (ex == null) return const BfPage(title: 'Exercise', children: [Text('Exercise not found.')]);
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final reason = ref.watch(filterProvider).reason(ex);
    final best = ref.watch(bestsProvider)[recordKey(ex.id, metricFor(ex.id))];
    final paths = [for (final p in kSkillPaths) if (p.indexOf(ex.id) >= 0) p];
    var i = 0;
    return BfPage(
      title: ex.name,
      children: [
        Hero(
          tag: 'ex-${ex.id}',
          child: Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(color: c.primary, borderRadius: Radii.cardLarge),
            child: ExerciseFigure(demo: ex.demo, color: BfPalette.ink),
          ),
        ),
        const SizedBox(height: Space.md),
        Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
          PillChip(label: ex.area.label, selected: true, dense: true),
          PillChip(label: 'Level ${ex.difficulty}/10', selected: false, dense: true),
          PillChip(label: ex.isTimed ? 'Timed hold' : 'Reps', selected: false, dense: true),
          if (ex.perSide) const PillChip(label: 'Each side', selected: false, dense: true),
          if (ex.impact) const PillChip(label: 'Jumping', selected: false, dense: true, icon: BfIcons.bolt),
          for (final p in ex.props) PillChip(label: p.label, selected: false, dense: true),
          PillChip(label: '${ex.space.name[0].toUpperCase()}${ex.space.name.substring(1)} space', selected: false, dense: true),
        ]).enter(context, index: i++),
        if (reason != null) ...[
          const SizedBox(height: Space.sm),
          BfCard(
            color: c.warning.withValues(alpha: 0.18),
            padding: const EdgeInsets.all(Space.md),
            child: Row(children: [
              Icon(BfIcons.warning, color: c.warning),
              const SizedBox(width: Space.sm),
              Expanded(child: Text('Not in your plan right now: $reason.', style: t.bodyMedium)),
            ]),
          ),
        ],
        const SizedBox(height: Space.lg),
        Text(ex.summary, style: t.bodyLarge).enter(context, index: i++),
        if (best != null) ...[
          const SizedBox(height: Space.md),
          StatTile(label: 'Your best', color: c.ember, value: Text(formatRecord(best, metricFor(ex.id)))),
        ],
        const SizedBox(height: Space.lg),
        Text('How to do it', style: t.headlineSmall).enter(context, index: i++),
        const SizedBox(height: Space.sm),
        for (var n = 0; n < ex.cues.length; n++)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                child: Text('${n + 1}', style: t.labelMedium?.copyWith(color: BfPalette.ink)),
              ),
              const SizedBox(width: Space.sm),
              Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: Text(ex.cues[n], style: t.bodyMedium))),
            ]),
          ).enter(context, index: i++),
        if (ex.mistakes.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Text('Avoid', style: t.headlineSmall),
          const SizedBox(height: Space.sm),
          for (final m in ex.mistakes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(BfIcons.close, size: 18, color: c.danger),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(m, style: t.bodyMedium)),
              ]),
            ),
        ],
        for (final p in paths) ...[
          const SizedBox(height: Space.lg),
          BfCard(
            color: c.secondary,
            onTap: () => context.push('/skills/${p.id}'),
            child: Row(children: [
              const Icon(BfIcons.tree, color: BfPalette.ink),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text('${p.name}: level ${p.indexOf(ex.id) + 1} of ${p.length}',
                    style: t.titleSmall?.copyWith(color: BfPalette.ink)),
              ),
              const Icon(BfIcons.chevronRight, color: BfPalette.ink),
            ]),
          ),
        ],
      ],
    );
  }
}

