import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

enum PillStyle { ink, lime, outline, surface }

/// The primary button: a full pill, optionally with a trailing arrow bubble
/// like the "Start" buttons in the references.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = PillStyle.ink,
    this.icon,
    this.trailingArrow = false,
    this.loading = false,
    this.expand = false,
    this.height = 56,
    this.foreground,
    this.background,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillStyle style;
  final IconData? icon;
  final bool trailingArrow;
  final bool loading;
  final bool expand;
  final double height;
  final Color? foreground;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    final (bg, fg, border) = switch (style) {
      PillStyle.ink => (gl.inverse, gl.onInverse, null),
      PillStyle.lime => (Palette.lime, Palette.ink, null),
      PillStyle.surface => (gl.surface, gl.text, gl.hairline),
      PillStyle.outline => (Colors.transparent, gl.text, gl.text),
    };
    final background = this.background ?? bg;
    final foreground = this.foreground ?? fg;
    final disabled = onPressed == null || loading;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        else if (icon != null)
          Icon(icon, size: 20, color: foreground),
        if (loading || icon != null) const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.button.copyWith(color: foreground),
          ),
        ),
        if (trailingArrow) ...[
          const SizedBox(width: 12),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: foreground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIconsBold.arrowRight,
              size: 16,
              color: background == Colors.transparent ? gl.canvas : background,
            ),
          ),
        ],
      ],
    );

    return Opacity(
      opacity: disabled && !loading ? 0.45 : 1,
      child: Pressable(
        onTap: disabled ? null : onPressed,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: Motion.fast,
          height: height,
          padding: EdgeInsets.only(
            left: 24,
            right: trailingArrow ? 12 : 24,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: Radii.pillR,
            border: border == null ? null : Border.all(color: border, width: 1.4),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// 44px circular toolbar button with a hairline border.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 44,
    this.background,
    this.foreground,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  final Color? background;
  final Color? foreground;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onPressed,
        semanticLabel: tooltip,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: background ?? gl.surface,
                shape: BoxShape.circle,
                border: background == null
                    ? Border.all(color: gl.hairline)
                    : null,
              ),
              child: Icon(icon, size: size * 0.45, color: foreground ?? gl.text),
            ),
            if (badge)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Palette.lime,
                    shape: BoxShape.circle,
                    border: Border.all(color: gl.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The big black circle with a ↗ arrow from the onboarding reference.
class ArrowCircleButton extends StatelessWidget {
  const ArrowCircleButton({
    super.key,
    required this.onPressed,
    this.size = 64,
    this.color = Palette.ink,
    this.iconColor = Palette.white,
    this.icon = PhosphorIconsBold.arrowUpRight,
    this.tooltip = 'Next',
  });

  final VoidCallback? onPressed;
  final double size;
  final Color color;
  final Color iconColor;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      scale: 0.92,
      semanticLabel: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: size * 0.38),
      ),
    );
  }
}
