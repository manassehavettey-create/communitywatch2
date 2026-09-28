import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/assets.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/page.dart';
import '../../domain/catalog/exercises.dart';
import '../../domain/engine/records.dart';
import '../../domain/engine/reports.dart';

/// Personal records (spec §12): previous vs current for every exercise.
class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recordHistoryProvider).value;
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    if (history == null) return const BfPage(title: 'Personal records', children: [Shimmer()]);
    final byEx = <String, List<RecordPoint>>{};
    for (final r in history) {
      byEx.putIfAbsent(r.exerciseId, () => []).add(r);
    }
    final entries = byEx.entries.toList()
      ..sort((a, b) => b.value.last.date.compareTo(a.value.last.date));
    final fmt = DateFormat('d MMM');
    return BfPage(
      title: 'Personal records',
      children: [
        if (entries.isEmpty)
          const EmptyState(image: Img.emptyRecords, title: 'No records yet', message: 'Complete a workout — your first results become your baselines, and every improvement after is a PR.'),
        for (var i = 0; i < entries.length; i++)
          () {
            final list = entries[i].value..sort((a, b) => a.date.compareTo(b.date));
            final ex = exerciseById(entries[i].key);
            final latest = list.last;
            final best = list.map((e) => e.value).reduce((a, b) => a > b ? a : b);
            final prev = latest.previous;
            final prCount = list.where((e) => e.previous != null).length;
            return Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: BfCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(ex.name, style: t.titleMedium)),
                    if (prCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: c.ember.withValues(alpha: 0.18), borderRadius: Radii.pillAll),
                        child: Text('$prCount PR${prCount == 1 ? '' : 's'}', style: t.labelSmall?.copyWith(color: c.ember)),
                      ),
                  ]),
                  const SizedBox(height: Space.sm),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Previous record', style: t.labelSmall),
                      Text(prev == null ? '—' : formatRecord(prev, latest.metric), style: BfType.number(22, color: c.textMuted)),
                    ]),
                    const SizedBox(width: Space.xl),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Current record', style: t.labelSmall),
                      Text(formatRecord(best, latest.metric), style: BfType.number(30, color: c.accentText)),
                    ]),
                    const Spacer(),
                    Text(fmt.format(latest.date.toLocalDateTime()), style: t.bodySmall),
                  ]),
                ]),
              ),
            ).enter(context, index: i);
          }(),
        if (entries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.md),
            child: Row(children: [
              Icon(BfIcons.info, size: 16, color: c.textMuted),
              const SizedBox(width: 6),
              Expanded(child: Text('Best single set. Timed holds show your longest hold.', style: t.bodySmall)),
            ]),
          ),
      ],
    );
  }
}
