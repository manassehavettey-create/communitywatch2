import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';

/// 44 px round icon button on a muted fill.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.filled = false,
    this.size = 44,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool filled;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = background ?? (filled ? c.ink : c.surfaceMuted);
    final fg = foreground ?? (filled ? c.onInk : c.ink);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onPressed!();
                  },
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, size: size * 0.46, color: onPressed == null ? fg.withValues(alpha: 0.4) : fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill chip: selected = filled ink, otherwise hairline outline.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = Motion.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: m.fast,
          curve: Motion.curve,
          padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16, vertical: dense ? 7 : 10),
          decoration: BoxDecoration(
            color: selected ? c.ink : Colors.transparent,
            borderRadius: Radii.pillAll,
            border: Border.all(color: selected ? c.ink : c.hairline, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: selected ? c.onInk : c.ink), const SizedBox(width: 6)],
              Text(label, style: context.text.labelMedium?.copyWith(color: selected ? c.onInk : c.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x6, Space.x2, Space.x3),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.titleLarge)),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Flat colour-block card.
class BlockCard extends StatelessWidget {
  const BlockCard({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.padding = const EdgeInsets.all(Space.x5),
    this.radius = Radii.lg,
  });

  final Widget child;
  final Color? color;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? context.colors.surface,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Screen title in the large display style.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, Space.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: context.text.displayLarge)),
                if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: context.text.bodySmall)],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

void showFolioSnack(BuildContext context, String message, {String? action, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(message),
      action: action == null ? null : SnackBarAction(label: action, onPressed: onAction ?? () {}),
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Standard confirm dialog. Returns true when confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final c = context.colors;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: c.danger, foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}
