import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

enum PillVariant { primary, secondary, tonal, accent }

/// Pill-shaped button: ink (primary), outlined (secondary), paper-deep
/// (tonal) or tangerine (accent). Presses scale down slightly.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = PillVariant.primary,
    this.expand = false,
    this.compact = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final PillVariant variant;
  final bool expand;
  final bool compact;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, fg, border) = switch (variant) {
      PillVariant.primary => (p.ink, p.paper, null),
      PillVariant.secondary => (Colors.transparent, p.ink, p.ink),
      PillVariant.tonal => (p.paperDeep, p.ink, null),
      PillVariant.accent => (p.tangerine, const Color(0xFF141414), null),
    };
    final enabled = onPressed != null && !busy;
    final height = compact ? 40.0 : 56.0;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: compact ? 18 : 20, color: fg),
        if (busy || icon != null) const SizedBox(width: Space.x2),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: (compact ? AppType.label : AppType.titleS).copyWith(
              color: fg,
            ),
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: Space.x2),
          Icon(trailingIcon, size: 20, color: fg),
        ],
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        child: AnimatedOpacity(
          opacity: enabled || busy ? 1 : 0.4,
          duration: Motion.of(context).fast,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: Radii.pillAll,
              border: border == null
                  ? null
                  : Border.all(color: border, width: 1.5),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// 44 px round icon button on paper-deep (or a supplied colour).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.background,
    this.foreground,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? background;
  final Color? foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Pressable(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background ?? p.paperDeep,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: size * 0.46, color: foreground ?? p.ink),
          ),
        ),
      ),
    );
  }
}

/// Scales its child to 96% while pressed. The shared press feedback for
/// cards and buttons.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    final interactive = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: interactive ? (_) => _set(true) : null,
      onTapUp: interactive ? (_) => _set(false) : null,
      onTapCancel: interactive ? () => _set(false) : null,
      child: AnimatedScale(
        scale: _down && !m.reduced ? widget.scale : 1,
        duration: m.instant,
        curve: MotionTokens.standard,
        child: widget.child,
      ),
    );
  }
}
