import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// The flat colour-block card from the references.
class GLCard extends StatelessWidget {
  const GLCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(Space.lg),
    this.radius = Radii.card,
    this.onTap,
    this.onLongPress,
    this.border = false,
    this.clip = false,
    this.semanticLabel,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool border;
  final bool clip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    final card = Container(
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: color ?? gl.card,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: gl.hairline) : null,
      ),
      child: child,
    );
    if (onTap == null && onLongPress == null) {
      return semanticLabel == null
          ? card
          : Semantics(label: semanticLabel, child: card);
    }
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
      child: card,
    );
  }
}

/// Small rounded label, e.g. "Medium" / "Apprentice" on skill cards.
class TagChip extends StatelessWidget {
  const TagChip(
    this.label, {
    super.key,
    this.color,
    this.foreground,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color? color;
  final Color? foreground;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? Palette.ink;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 12,
        vertical: dense ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.55),
        borderRadius: Radii.pillR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: dense ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(
      Space.gutter,
      Space.xl,
      Space.gutter,
      Space.sm,
    ),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: context.text.titleLarge),
            ),
          ),
          if (actionLabel != null && onAction != null)
            Pressable(
              onTap: onAction,
              semanticLabel: actionLabel,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text(
                  '$actionLabel  ›',
                  style: AppText.caption.copyWith(
                    color: context.gl.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small stat block: label, big value, optional image/icon.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.color,
    this.foreground,
    this.leading,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? color;
  final Color? foreground;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? context.gl.text;
    return GLCard(
      color: color,
      onTap: onTap,
      radius: Radii.cardSmall,
      padding: const EdgeInsets.all(Space.md),
      semanticLabel: '$label: $value${caption == null ? '' : ', $caption'}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: fg.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ?leading,
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppText.numeral.copyWith(color: fg, fontSize: 26),
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(
                  color: fg.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
