import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'buttons.dart';

/// Oversized two-line screen title with an optional italic sub-line and
/// trailing actions (reference: "My Notes").
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x4,
        Space.gutter,
        Space.x5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null || actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x4),
              child: Row(
                children: [
                  ?leading,
                  const Spacer(),
                  for (final a in actions) ...[
                    const SizedBox(width: Space.x2),
                    a,
                  ],
                ],
              ),
            ),
          Semantics(
            header: true,
            child: Text(title, style: AppType.displayL.copyWith(color: p.ink)),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.x1),
              child: Text(
                subtitle!,
                style: AppType.displayItalic.copyWith(color: p.inkSoft),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small section label with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x6,
        Space.gutter,
        Space.x3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: AppType.titleM.copyWith(color: p.ink)),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// A horizontally scrolling row of pill filter chips with optional counts.
class ChipRow<T> extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.labelOf,
    this.countOf,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T) labelOf;
  final int? Function(T)? countOf;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = Motion.of(context);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.x2),
        itemBuilder: (context, i) {
          final o = options[i];
          final on = o == selected;
          final count = countOf?.call(o);
          return Semantics(
            selected: on,
            button: true,
            child: Pressable(
              onTap: () => onSelected(o),
              child: AnimatedContainer(
                duration: m.fast,
                curve: MotionTokens.standard,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? p.ink : Colors.transparent,
                  borderRadius: Radii.pillAll,
                  border: Border.all(color: on ? p.ink : p.line, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labelOf(o),
                      style: AppType.label.copyWith(
                        color: on ? p.paper : p.inkSoft,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: on ? p.paper : p.paperDeep,
                          borderRadius: Radii.pillAll,
                        ),
                        child: Text(
                          '$count',
                          style: AppType.caption.copyWith(color: p.ink),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Grabber + optional title for bottom sheets.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, this.title, this.trailing});

  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: Space.x3),
        Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(color: p.line, borderRadius: Radii.pillAll),
        ),
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.x6,
              Space.x4,
              Space.x4,
              Space.x2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: AppType.titleL.copyWith(color: p.ink),
                  ),
                ),
                ?trailing,
              ],
            ),
          )
        else
          const SizedBox(height: Space.x3),
      ],
    );
  }
}

/// Opens a rounded bottom sheet that sizes to its content and respects the
/// keyboard.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    sheetAnimationStyle: AnimationStyle(
      duration: Motion.of(context).slow,
      reverseDuration: Motion.of(context).base,
      curve: MotionTokens.standard,
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: builder(context),
    ),
  );
}

/// Confirmation dialog for destructive actions.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shows a floating snack bar message.
void toast(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}
