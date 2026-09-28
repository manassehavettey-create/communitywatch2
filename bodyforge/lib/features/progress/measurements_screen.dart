import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/assets.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/page.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/local_date.dart';

/// Body measurements (spec §13). No photos — just numbers that move.
class MeasurementsScreen extends ConsumerStatefulWidget {
  const MeasurementsScreen({super.key});
  @override
  ConsumerState<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends ConsumerState<MeasurementsScreen> {
  MeasurementType _type = MeasurementType.weight;
  String? _customLabel;

  Future<void> _add() async {
    final units = ref.read(settingsProvider).units;
    final value = TextEditingController();
    final label = TextEditingController(text: _customLabel ?? '');
    var date = ref.read(todayProvider);
    final saved = await showBfSheet<bool>(context, builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      return StatefulBuilder(builder: (ctx, setSheet) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Log ${_type.label.toLowerCase()}', style: t.headlineMedium),
            const SizedBox(height: Space.lg),
            if (_type == MeasurementType.custom) ...[
              TextField(controller: label, decoration: const InputDecoration(labelText: 'What are you measuring? (e.g. calf)')),
              const SizedBox(height: Space.md),
            ],
            TextField(
              controller: value,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              style: BfType.number(32, color: ctx.bf.text),
              decoration: InputDecoration(suffixText: Units.unitFor(_type, units), hintText: '0.0'),
            ),
            const SizedBox(height: Space.md),
            BfCard(
              color: ctx.bf.surfaceRaised,
              padding: const EdgeInsets.all(Space.md),
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: date.toLocalDateTime(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setSheet(() => date = LocalDate.fromDateTime(picked));
              },
              child: Row(children: [
                const Icon(BfIcons.calendar, size: 18),
                const SizedBox(width: Space.sm),
                Text(DateFormat('EEEE d MMMM').format(date.toLocalDateTime()), style: t.bodyMedium),
              ]),
            ),
            const SizedBox(height: Space.lg),
            BfButton(label: 'Save', onPressed: () => Navigator.pop(ctx, true)),
          ]),
        );
      });
    });
    if (saved != true) return;
    final v = double.tryParse(value.text.replaceAll(',', '.'));
    if (v == null || v <= 0 || v > 1000) {
      if (mounted) toast(context, 'Enter a valid number');
      return;
    }
    if (_type == MeasurementType.custom && label.text.trim().isEmpty) {
      if (mounted) toast(context, 'Give your custom measurement a name');
      return;
    }
    await ref.read(lifestyleRepoProvider).addMeasurement(_type, Units.fromDisplay(_type, v, units), date: date, label: label.text);
    if (_type == MeasurementType.custom) _customLabel = label.text.trim();
    final fresh = await ref.read(trainingServiceProvider).checkAchievements();
    if (mounted && fresh.isNotEmpty) toast(context, 'Achievement unlocked: ${fresh.first.title}');
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(measurementsProvider).value ?? const [];
    final units = ref.watch(settingsProvider).units;
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final customLabels = {for (final m in all) if (m.point.type == MeasurementType.custom && m.point.label != null) m.point.label!};
    final list = all
        .where((m) => m.point.type == _type && (_type != MeasurementType.custom || _customLabel == null || m.point.label == _customLabel))
        .toList();
    final fmt = DateFormat('d MMM yyyy');
    return BfPage(
      title: 'Measurements',
      actions: [CircleIconButton(icon: BfIcons.add, onTap: _add, tooltip: 'Add')],
      children: [
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final type in MeasurementType.values)
              Padding(
                padding: const EdgeInsets.only(right: Space.xs),
                child: PillChip(label: type.label, selected: _type == type, onTap: () => setState(() => _type = type)),
              ),
          ]),
        ),
        if (_type == MeasurementType.custom && customLabels.isNotEmpty) ...[
          const SizedBox(height: Space.xs),
          Wrap(spacing: Space.xs, children: [
            for (final l in customLabels) PillChip(label: l, dense: true, selected: _customLabel == l, onTap: () => setState(() => _customLabel = l)),
          ]),
        ],
        const SizedBox(height: Space.md),
        if (list.isEmpty)
          EmptyState(
            image: Img.emptyMeasurements,
            title: 'Nothing logged yet',
            message: _type == MeasurementType.waist
                ? 'Measure around your belly button, relaxed, first thing in the morning.'
                : 'Measure at the same time of day each week for honest trends.',
            action: 'Add ${_type.label.toLowerCase()}',
            onAction: _add,
          )
        else ...[
          BfCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Units.formatMeasurement(_type, list.last.point.value, units), style: BfType.number(34, color: c.text)),
                const Spacer(),
                if (list.length > 1)
                  Text(Units.formatDelta(_type, list.last.point.value - list.first.point.value, units),
                      style: BfType.number(16, color: c.secondary)),
              ]),
              Text(list.length > 1 ? 'since ${fmt.format(list.first.point.date.toLocalDateTime())}' : 'first entry', style: t.bodySmall),
              if (list.length > 1) ...[
                const SizedBox(height: Space.md),
                DrawInLineChart(
                  color: _type == MeasurementType.weight ? c.secondary : c.primary,
                  points: [
                    for (final m in list)
                      ChartPoint(m.point.date.daysSince(list.first.point.date).toDouble(), Units.toDisplay(_type, m.point.value, units))
                  ],
                  formatY: (v) => Units.format(v),
                ),
              ],
            ]),
          ).enter(context),
          const SizedBox(height: Space.md),
          for (var i = list.length - 1; i >= 0; i--)
            Dismissible(
              key: ValueKey(list[i].id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: Space.lg),
                decoration: BoxDecoration(color: c.danger.withValues(alpha: 0.2), borderRadius: Radii.tile),
                child: Icon(BfIcons.delete, color: c.danger),
              ),
              onDismissed: (_) => ref.read(lifestyleRepoProvider).deleteMeasurement(list[i].id),
              child: Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: BfCard(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                  child: Row(children: [
                    Text(fmt.format(list[i].point.date.toLocalDateTime()), style: t.bodyMedium),
                    const Spacer(),
                    Text(Units.formatMeasurement(_type, list[i].point.value, units), style: BfType.number(16, color: c.text)),
                  ]),
                ),
              ),
            ),
          Text('Swipe an entry left to delete it.', textAlign: TextAlign.center, style: t.bodySmall),
        ],
      ],
    );
  }
}
