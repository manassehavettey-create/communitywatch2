import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/phosphor_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/segmented_pills.dart';
import '../../../core/widgets/states.dart';
import '../application/skill_providers.dart';
import 'widgets/skill_cards.dart';

class SkillsScreen extends ConsumerStatefulWidget {
  const SkillsScreen({super.key});

  @override
  ConsumerState<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends ConsumerState<SkillsScreen> {
  bool _archived = false;

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(skillsOverviewProvider);
    final totalSec = active.value?.fold<int>(0, (a, s) => a + s.totalSec) ?? 0;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabHeader(
            bold: 'Skills',
            italic: 'in the making',
            subtitle: active.value == null || active.value!.isEmpty
                ? null
                : '${Fmt.plural(active.value!.length, 'skill')} · ${Fmt.hours(totalSec)} hours so far',
            actions: [
              CircleIconButton(
                icon: PhosphorIconsBold.plus,
                tooltip: 'New skill',
                background: Palette.lime,
                foreground: Palette.ink,
                onPressed: () => context.push(Routes.newSkill),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.md,
            ),
            child: SegmentedPills<bool>(
              values: const [false, true],
              selected: _archived,
              labelOf: (v) => v ? 'Archived' : 'Active',
              onChanged: (v) => setState(() => _archived = v),
              selectedColor: context.gl.inverse,
              selectedForeground: context.gl.onInverse,
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.medium,
              child: _archived
                  ? const _ArchivedList(key: ValueKey('archived'))
                  : _ActiveList(key: const ValueKey('active'), value: active),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveList extends ConsumerWidget {
  const _ActiveList({super.key, required this.value});

  final AsyncValue<List<SkillStats>> value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: value,
      onRetry: () => ref.invalidate(skillsOverviewProvider),
      data: (skills) {
        if (skills.isEmpty) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(
              top: Space.xl,
              bottom: Space.dockClearance,
            ),
            child: EmptyState(
              image: AppAssets.emptySkills,
              title: 'Plant your first flag',
              message: 'Pick something you want to get better at. Every session moves you toward mastery.',
              actionLabel: 'Add a skill',
              onAction: () => context.push(Routes.newSkill),
            ),
          );
        }
        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.dockClearance,
          ),
          buildDefaultDragHandles: false,
          itemCount: skills.length,
          proxyDecorator: (child, _, _) =>
              Material(color: Colors.transparent, child: child),
          onReorderItem: (from, to) {
            final ids = skills.map((s) => s.skill.id).toList();
            ids.insert(to, ids.removeAt(from));
            ref.read(hapticsProvider).light();
            guarded(
              context,
              () => ref.read(skillRepositoryProvider).reorder(ids),
            );
          },
          itemBuilder: (context, i) {
            final s = skills[i];
            return Padding(
              key: ValueKey(s.skill.id),
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: FadeSlideIn(
                index: i,
                child: SkillListCard(
                  stats: s,
                  dragHandle: skills.length > 1
                      ? ReorderableDragStartListener(
                          index: i,
                          child: Semantics(
                            label: 'Reorder ${s.skill.name}',
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                PhosphorIconsBold.dotsSixVertical,
                                color: Palette.ink,
                                size: 20,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ArchivedList extends ConsumerWidget {
  const _ArchivedList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(archivedSkillsProvider),
      onRetry: () => ref.invalidate(archivedSkillsProvider),
      data: (skills) {
        if (skills.isEmpty) {
          return const SingleChildScrollView(
            padding: EdgeInsets.only(
              top: Space.xl,
              bottom: Space.dockClearance,
            ),
            child: EmptyState(
              image: AppAssets.emptySearch,
              title: 'Nothing archived',
              message: "Archive a skill you're pausing. Its hours and history stay safe here.",
              compact: true,
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.dockClearance,
          ),
          itemCount: skills.length,
          separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
          itemBuilder: (_, i) =>
              SkillListCard(stats: skills[i], archived: true),
        );
      },
    );
  }
}
