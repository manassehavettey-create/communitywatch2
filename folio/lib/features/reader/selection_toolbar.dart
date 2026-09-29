import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/icons.dart';

import '../../core/theme/tokens.dart';

enum SelectionAction { bookmark, note, copy, share, askAi, explain }

/// Floating toolbar shown when text is selected: highlight colours on top,
/// actions below. Slides up like a mini bottom sheet.
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({super.key, required this.onHighlight, required this.onAction, required this.dark});

  final ValueChanged<ShelfColor> onHighlight;
  final ValueChanged<SelectionAction> onAction;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF262320) : const Color(0xFF161514);
    const fg = Color(0xFFF6F1E7);
    Widget action(IconData icon, String label, SelectionAction a) => Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: () {
            HapticFeedback.selectionClick();
            onAction(a);
          },
          radius: 28,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: context.text.labelSmall?.copyWith(color: fg.withValues(alpha: 0.8), letterSpacing: 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Material(
      color: bg,
      borderRadius: Radii.xlAll,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.x3, Space.x3, Space.x3, Space.x2),
        decoration: BoxDecoration(
          borderRadius: Radii.xlAll,
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8))],
          border: dark ? Border.all(color: const Color(0xFF34302B)) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: Space.x2),
                Icon(PhosphorIconsRegular.highlighter, size: 18, color: fg.withValues(alpha: 0.7)),
                const SizedBox(width: Space.x3),
                for (final c in ShelfColor.highlightColors)
                  Padding(
                    padding: const EdgeInsets.only(right: Space.x3),
                    child: Semantics(
                      button: true,
                      label: 'Highlight ${c.label}',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onHighlight(c);
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: c.strong,
                            shape: BoxShape.circle,
                            border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.x2),
            Row(
              children: [
                action(PhosphorIconsRegular.bookmarkSimple, 'Bookmark', SelectionAction.bookmark),
                action(PhosphorIconsRegular.notePencil, 'Note', SelectionAction.note),
                action(PhosphorIconsRegular.copy, 'Copy', SelectionAction.copy),
                action(PhosphorIconsRegular.shareNetwork, 'Share', SelectionAction.share),
                action(PhosphorIconsRegular.sparkle, 'Ask AI', SelectionAction.askAi),
                action(PhosphorIconsRegular.lightbulb, 'Explain', SelectionAction.explain),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
