import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'buttons.dart';

/// Flat colour-block card: the main surface of the design.
class PastelCard extends StatelessWidget {
  const PastelCard({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(Space.x5),
    this.radius = Radii.lg,
    this.semanticLabel,
  });

  final Widget child;

  /// Defaults to cream.
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.cream,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: p.onPastel),
        child: IconTheme.merge(
          data: IconThemeData(color: p.onPastel),
          child: child,
        ),
      ),
    );
    final wrapped = onTap == null && onLongPress == null
        ? card
        : Pressable(onTap: onTap, onLongPress: onLongPress, child: card);
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: wrapped,
    );
  }
}

/// Neutral list card on the paper-deep tone (for lists of entries).
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(Space.x4),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: Radii.mdAll,
        border: Border.all(color: p.line),
      ),
      child: child,
    );
    if (onTap == null && onLongPress == null) return card;
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scale: 0.98,
      child: card,
    );
  }
}
