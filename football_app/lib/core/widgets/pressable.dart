import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Tap target with a subtle press-scale and a light haptic — the single
/// interaction primitive used for cards, rows and buttons.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.975, this.haptic = true, this.semanticLabel});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: _down ? Motion.instant : Motion.base,
          curve: _down ? Curves.easeOut : Motion.spring,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Rounded surface card.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(Space.md), this.color, this.radius = Radii.xl, this.border = false, this.gradient});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final bool border;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? c.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: c.hairline) : null,
        boxShadow: c.isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, child: box);
  }
}

/// Primary pill button (lime with a subtle mint sheen, as in the reference
/// CTA) and a quiet secondary variant.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onTap, this.icon, this.primary = true, this.expand = false, this.busy = false});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool primary;
  final bool expand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = primary ? c.onAccent : c.text;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        else if (icon != null)
          Icon(icon, size: 18, color: fg),
        if (icon != null || busy) const SizedBox(width: 8),
        Text(label, style: context.text.labelLarge?.copyWith(color: fg)),
      ],
    );
    return Pressable(
      onTap: busy ? null : onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.45 : 1,
        duration: Motion.fast,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: Radii.pillAll,
            color: primary ? null : c.surface2,
            gradient: primary ? LinearGradient(colors: [c.accent, Color.lerp(c.accent, c.mint, 0.35)!], begin: Alignment.centerLeft, end: Alignment.centerRight) : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, required this.onTap, this.size = 44, this.tooltip, this.active = false});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final btn = Pressable(
      onTap: onTap,
      semanticLabel: tooltip,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.emphasized,
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: active ? c.accent : c.surface2, border: Border.all(color: active ? c.accent : c.hairline)),
        child: Icon(icon, size: size * 0.44, color: active ? c.onAccent : c.text),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
