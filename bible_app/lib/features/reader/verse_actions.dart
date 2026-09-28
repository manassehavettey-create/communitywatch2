import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/icons.dart';

import '../../core/haptics.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/layout.dart';

/// Floating panel for the current verse selection.
class VerseActionsPanel extends StatelessWidget {
  const VerseActionsPanel({
    super.key,
    required this.label,
    required this.currentHighlight,
    required this.bookmarked,
    required this.noteCount,
    required this.onHighlight,
    required this.onClearHighlight,
    required this.onBookmark,
    required this.onNote,
    required this.onCopy,
    required this.onShareText,
    required this.onShareCard,
    required this.onSave,
    required this.onClose,
  });

  final String label;
  final HighlightColor? currentHighlight;
  final bool bookmarked;
  final int noteCount;
  final ValueChanged<HighlightColor> onHighlight;
  final VoidCallback onClearHighlight;
  final VoidCallback onBookmark;
  final VoidCallback onNote;
  final VoidCallback onCopy;
  final VoidCallback onShareText;
  final VoidCallback onShareCard;
  final VoidCallback onSave;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = Motion.of(context);
    return Material(
      color: p.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.xl)),
        side: p.isDark ? BorderSide(color: p.line) : BorderSide.none,
      ),
      shadowColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(Radii.xl)),
          boxShadow: floatingShadow(p),
        ),
        padding: const EdgeInsets.fromLTRB(
          Space.x5,
          Space.x3,
          Space.x3,
          Space.x4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: m.fast,
                    transitionBuilder: (c, a) =>
                        FadeTransition(opacity: a, child: c),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.titleS.copyWith(color: p.ink),
                    ),
                  ),
                ),
                CircleIconButton(
                  icon: PhosphorIconsBold.x,
                  tooltip: 'Clear selection',
                  size: 36,
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: Space.x3),
            // Highlight colours
            Row(
              children: [
                for (final c in HighlightColor.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _ColorDot(
                      color: c.base(p),
                      label: '${c.label} highlight',
                      selected: currentHighlight == c,
                      onTap: () {
                        Haptics.light();
                        onHighlight(c);
                      },
                    ),
                  ),
                if (currentHighlight != null)
                  CircleIconButton(
                    icon: PhosphorIconsRegular.eraser,
                    tooltip: 'Remove highlight',
                    size: 36,
                    onPressed: () {
                      Haptics.light();
                      onClearHighlight();
                    },
                  ),
              ],
            ),
            const SizedBox(height: Space.x3),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Action(
                    icon: bookmarked
                        ? PhosphorIconsFill.bookmarkSimple
                        : PhosphorIconsRegular.bookmarkSimple,
                    label: bookmarked ? 'Bookmarked' : 'Bookmark',
                    onTap: onBookmark,
                    active: bookmarked,
                  ),
                  _Action(
                    icon: PhosphorIconsRegular.notePencil,
                    label: noteCount > 0 ? 'Notes ($noteCount)' : 'Note',
                    onTap: onNote,
                  ),
                  _Action(
                    icon: PhosphorIconsRegular.heart,
                    label: 'Save',
                    onTap: onSave,
                  ),
                  _Action(
                    icon: PhosphorIconsRegular.copy,
                    label: 'Copy',
                    onTap: onCopy,
                  ),
                  _Action(
                    icon: PhosphorIconsRegular.shareNetwork,
                    label: 'Share',
                    onTap: onShareText,
                  ),
                  _Action(
                    icon: PhosphorIconsRegular.image,
                    label: 'Card',
                    onTap: onShareCard,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = Motion.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Pressable(
        onTap: onTap,
        scale: 0.88,
        child: AnimatedContainer(
          duration: m.fast,
          curve: m.standard,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? p.ink : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? Icon(
                  PhosphorIconsBold.check,
                  size: 16,
                  color: p.onPastel,
                ).animate().scale(duration: m.fast, curve: Curves.easeOutBack)
              : null,
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: Space.x2),
      child: Semantics(
        button: true,
        label: label,
        child: Pressable(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: active ? p.tangerine : p.paperDeep,
              borderRadius: Radii.pillAll,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: active ? p.onPastel : p.ink),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppType.label.copyWith(
                    color: active ? p.onPastel : p.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Edits a note (new or existing). Returns the text, or null if cancelled.
/// An empty result on an existing note means delete.
class NoteEditorSheet extends StatefulWidget {
  const NoteEditorSheet({
    super.key,
    required this.reference,
    this.initial = '',
    this.existing = false,
  });

  final String reference;
  final String initial;
  final bool existing;

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.x6, 0, Space.x6, Space.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: widget.existing ? 'Edit note' : 'New note'),
            Text(
              widget.reference,
              style: AppType.label.copyWith(color: p.inkSoft),
            ),
            const SizedBox(height: Space.x3),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              style: AppType.body.copyWith(color: p.ink),
              decoration: const InputDecoration(
                hintText: 'What stands out to you?',
              ),
            ),
            const SizedBox(height: Space.x4),
            Row(
              children: [
                if (widget.existing)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, ''),
                    icon: const Icon(PhosphorIconsRegular.trash, size: 18),
                    label: const Text('Delete'),
                  ),
                const Spacer(),
                ValueListenableBuilder(
                  valueListenable: _controller,
                  builder: (context, v, _) => PillButton(
                    label: 'Save note',
                    compact: true,
                    onPressed: v.text.trim().isEmpty
                        ? null
                        : () => Navigator.pop(context, _controller.text.trim()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
