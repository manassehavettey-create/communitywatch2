import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/app_actions.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/phosphor_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/skill_icons.dart';
import '../data/entry_repository.dart';

Color entryColor(EntryType t) =>
    t == EntryType.win ? Palette.blush : Palette.butter;

class EntryCard extends ConsumerWidget {
  const EntryCard({super.key, required this.view, this.compact = false});

  final EntryView view;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = view.entry;
    final color = entryColor(view.type);
    final skill = view.skill;

    return Dismissible(
      key: ValueKey('entry-${e.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.lg),
        decoration: const BoxDecoration(
          color: Palette.danger,
          borderRadius: Radii.cardR,
        ),
        child: const Icon(PhosphorIconsBold.trash, color: Palette.white),
      ),
      confirmDismiss: (_) => confirm(
        context,
        title: 'Delete this entry?',
        message: 'You can undo right after.',
        confirmLabel: 'Delete',
        destructive: true,
      ),
      onDismissed: (_) async {
        final actions = ref.read(appActionsProvider);
        await guarded(context, () => actions.deleteEntry(view));
        if (context.mounted) {
          showSnack(
            context,
            'Entry deleted',
            actionLabel: 'Undo',
            onAction: () => actions.restoreEntry(view),
          );
        }
      },
      child: GLCard(
        color: color,
        onTap: () => context.push(Routes.entry(e.id)),
        semanticLabel:
            '${view.type.label}${e.mood == null ? '' : ' ${e.mood}'}: ${e.body}. '
            '${view.tags.isEmpty ? '' : 'Tags ${view.tags.join(', ')}. '}'
            '${skill == null ? '' : 'Skill ${skill.name}. '}Tap to edit, swipe to delete',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TagChip(
                    view.isMilestone ? 'Milestone' : view.type.label,
                    icon: view.type == EntryType.win
                        ? PhosphorIconsFill.trophy
                        : PhosphorIconsFill.heart,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    Fmt.time(e.createdAt),
                    style: AppText.caption.copyWith(
                      color: Palette.ink.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  if (e.mood != null)
                    Text(e.mood!, style: const TextStyle(fontSize: 22)),
                ],
              ),
              const SizedBox(height: Space.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      e.body,
                      maxLines: compact ? 3 : 8,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.subtitle.copyWith(
                        color: Palette.ink,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (view.isMilestone) ...[
                    const SizedBox(width: Space.sm),
                    const AppImage(AppAssets.trophy, width: 56, height: 56),
                  ],
                ],
              ),
              if (view.tags.isNotEmpty || skill != null) ...[
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (skill != null)
                      TagChip(
                        skill.name,
                        icon: SkillIcons.of(skill.iconKey),
                        color: Palette.ink,
                        foreground: Color(skill.colorValue),
                        dense: true,
                      ),
                    for (final t in view.tags) TagChip('#$t', dense: true),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
