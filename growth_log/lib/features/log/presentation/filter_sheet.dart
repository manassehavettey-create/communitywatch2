import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/day_key.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skill_icons.dart';
import '../../skills/application/skill_providers.dart';
import '../application/log_providers.dart';

enum FilterSection { tags, skill, dates }

Future<void> showFilterSheet(BuildContext context, FilterSection section) {
  return showAppSheet<void>(
    context,
    builder: (_) => _FilterSheet(section: section),
  );
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({required this.section});

  final FilterSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(logFilterProvider);
    final ctrl = ref.read(logFilterProvider.notifier);

    Widget choice(
      String label,
      bool selected,
      VoidCallback onTap, {
      Widget? leading,
      Color? color,
    }) {
      final gl = context.gl;
      return Semantics(
        button: true,
        selected: selected,
        child: Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.fast,
            padding: EdgeInsets.fromLTRB(leading == null ? 16 : 6, 8, 16, 8),
            decoration: BoxDecoration(
              color: selected ? (color ?? gl.inverse) : gl.surface,
              borderRadius: Radii.pillR,
              border: Border.all(
                color: selected ? (color ?? gl.inverse) : gl.hairline,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 8)],
                Text(
                  label,
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? (color != null ? Palette.ink : gl.onInverse)
                        : gl.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    switch (section) {
      case FilterSection.tags:
        final tags = ref.watch(allTagsProvider).value ?? const [];
        return SheetScaffold(
          title: 'Filter by tag',
          primaryLabel: 'Done',
          onPrimary: () => Navigator.pop(context),
          child: tags.isEmpty
              ? Text(
                  'No tags yet. Add tags when you write an entry.',
                  style: context.text.bodySmall,
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in tags)
                      choice(
                        '#${t.name} · ${t.count}',
                        filter.tags.contains(t.name),
                        () {
                          final next = {...filter.tags};
                          next.contains(t.name)
                              ? next.remove(t.name)
                              : next.add(t.name);
                          ctrl.set(filter.copyWith(tags: next));
                        },
                      ),
                  ],
                ),
        );
      case FilterSection.skill:
        final active = ref.watch(skillsOverviewProvider).value ?? const [];
        final archived = ref.watch(archivedSkillsProvider).value ?? const [];
        final all = [...active, ...archived];
        return SheetScaffold(
          title: 'Filter by skill',
          primaryLabel: 'Done',
          onPrimary: () => Navigator.pop(context),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              choice(
                'Any skill',
                filter.skillId == null,
                () => ctrl.set(filter.copyWith(skillId: () => null)),
              ),
              for (final s in all)
                choice(
                  s.skill.name,
                  filter.skillId == s.skill.id,
                  () => ctrl.set(filter.copyWith(skillId: () => s.skill.id)),
                  leading: SkillAvatar(skill: s.skill, size: 28),
                  color: Color(s.skill.colorValue),
                ),
            ],
          ),
        );
      case FilterSection.dates:
        final today = ref.watch(todayProvider);
        void setRange(DayKey? from, DayKey? to) =>
            ctrl.set(filter.copyWith(from: () => from, to: () => to));
        final presets = <(String, DayKey?, DayKey?)>[
          ('All time', null, null),
          ('Last 7 days', Days.add(today, -6), today),
          ('Last 30 days', Days.add(today, -29), today),
          ('This month', Days.monthStart(today), today),
          ('This year', Days.yearStart(today), today),
        ];
        return SheetScaffold(
          title: 'Filter by date',
          primaryLabel: 'Done',
          onPrimary: () => Navigator.pop(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in presets)
                    choice(
                      p.$1,
                      filter.from == p.$2 && filter.to == p.$3,
                      () => setRange(p.$2, p.$3),
                    ),
                ],
              ),
              const SizedBox(height: Space.md),
              TextButton(
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: Days.dateOf(today),
                    initialDateRange: filter.from != null && filter.to != null
                        ? DateTimeRange(
                            start: Days.dateOf(filter.from!),
                            end: Days.dateOf(filter.to!),
                          )
                        : null,
                  );
                  if (range != null) {
                    setRange(Days.keyOf(range.start), Days.keyOf(range.end));
                  }
                },
                child: Text(
                  filter.from != null && filter.to != null
                      ? 'Custom: ${Fmt.shortDate(filter.from!)} – ${Fmt.shortDate(filter.to!)}'
                      : 'Pick a custom range…',
                ),
              ),
            ],
          ),
        );
    }
  }
}
