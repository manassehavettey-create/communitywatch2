import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../domain/catalog/achievements.dart';
import '../assets.dart';
import '../motion/motion.dart';
import '../theme/bf_colors.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'icons.dart';
import 'motion_widgets.dart';

enum BfButtonKind { primary, secondary, dark, ghost, danger }

/// Pill button in the reference style (lime primary, lavender secondary,
/// ink "dark", outline ghost).
class BfButton extends StatelessWidget {
  const BfButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = BfButtonKind.primary,
    this.icon,
    this.trailingIcon,
    this.expand = true,
    this.loading = false,
    this.height = 58,
  });

  final String label;
  final VoidCallback? onPressed;
  final BfButtonKind kind;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool expand;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final (bg, fg, border) = switch (kind) {
      BfButtonKind.primary => (c.primary, c.onPrimary, null),
      BfButtonKind.secondary => (c.secondary, c.onSecondary, null),
      BfButtonKind.dark => (c.isDark ? c.sheet : BfPalette.ink, c.isDark ? BfPalette.ink : Colors.white, null),
      BfButtonKind.ghost => (Colors.transparent, c.text, c.outline),
      BfButtonKind.danger => (c.danger.withValues(alpha: 0.14), c.danger, null),
    };
    final disabled = onPressed == null || loading;
    final child = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      decoration: BoxDecoration(
        color: disabled && kind != BfButtonKind.ghost ? bg.withValues(alpha: 0.45) : bg,
        borderRadius: Radii.pillAll,
        border: border == null ? null : Border.all(color: border, width: 1.4),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
          else ...[
            if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: Space.xs)],
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg)),
            ),
            if (trailingIcon != null) ...[const SizedBox(width: Space.xs), Icon(trailingIcon, size: 20, color: fg)],
          ],
        ],
      ),
    );
    return Pressable(
      onTap: disabled ? null : onPressed,
      borderRadius: Radii.pillAll,
      semanticLabel: label,
      child: child,
    );
  }
}

/// Round icon button (white on dark, ink on light) from the references.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = Sizes.iconButton,
    this.background,
    this.foreground,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? background;
  final Color? foreground;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final bg = background ?? (c.isDark ? c.sheet : BfPalette.ink);
    final fg = foreground ?? (c.isDark ? BfPalette.ink : Colors.white);
    final btn = Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      scale: 0.9,
      semanticLabel: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: size * 0.44),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Standard card surface.
class BfCard extends StatelessWidget {
  const BfCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(Space.lg),
    this.onTap,
    this.radius = Radii.card,
    this.rings = false,
    this.ringColor,
    this.clip = true,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius radius;

  /// Draw the concentric-ring texture inside the card.
  final bool rings;
  final Color? ringColor;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final bg = color ?? c.surface;
    Widget inner = Padding(padding: padding, child: child);
    if (rings) {
      inner = Stack(children: [
        Positioned.fill(
            child: ConcentricRings(color: ringColor ?? c.onColor(bg).withValues(alpha: 0.07))),
        inner,
      ]);
    }
    final box = Container(
      decoration: BoxDecoration(color: bg, borderRadius: radius, boxShadow: c.cardShadow),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: inner,
    );
    if (onTap == null) return box;
    return Pressable(onTap: onTap, borderRadius: radius, scale: 0.98, child: box);
  }
}

/// Filter / choice chip: selected = sheet fill + ink text, else outlined.
class PillChip extends StatelessWidget {
  const PillChip({super.key, required this.label, required this.selected, this.onTap, this.icon, this.dense = false});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final fg = selected ? BfPalette.ink : c.text;
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.pillAll,
      scale: 0.94,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.medium),
        curve: Motion.standard,
        padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 18, vertical: dense ? 8 : 12),
        decoration: BoxDecoration(
          color: selected ? (c.isDark ? c.sheet : c.primary) : Colors.transparent,
          borderRadius: Radii.pillAll,
          border: Border.all(color: selected ? Colors.transparent : c.outline, width: 1.3),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
        ]),
      ),
    );
  }
}

/// A big selectable option card used in onboarding and sheets.
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
    this.leading,
    this.multi = false,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final t = Theme.of(context).textTheme;
    final bg = selected ? c.primary : c.surface;
    final fg = selected ? BfPalette.ink : c.text;
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.tile,
      scale: 0.98,
      semanticLabel: title,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.medium),
        curve: Motion.standard,
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: Radii.tile,
          border: Border.all(color: selected ? Colors.transparent : c.outline),
        ),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: Space.md)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleMedium?.copyWith(color: fg)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: t.bodySmall?.copyWith(color: selected ? BfPalette.ink.withValues(alpha: 0.7) : c.textMuted)),
              ],
            ]),
          ),
          const SizedBox(width: Space.sm),
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.fast),
            transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w),
            child: Icon(
              selected
                  ? (multi ? BfIcons.checkBoxOn : BfIcons.radioOn)
                  : (multi ? BfIcons.checkBoxOff : BfIcons.radioOff),
              key: ValueKey(selected),
              color: selected ? BfPalette.ink : c.textFaint,
            ),
          ),
        ]),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.sm),
      child: Row(children: [
        Expanded(child: Text(title, style: t.headlineSmall)),
        if (action != null)
          Pressable(
            onTap: onAction,
            borderRadius: Radii.pillAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(action!, style: t.labelMedium?.copyWith(color: context.bf.textMuted)),
            ),
          ),
      ]),
    );
  }
}

class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: BfType.overline(color ?? context.bf.textMuted));
}

/// Small stat block: label over a big value.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.color, this.caption, this.onColor});
  final String label;
  final Widget value;
  final Color? color;
  final String? caption;
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final bg = color ?? c.surface;
    final fg = onColor ?? c.onColor(bg);
    return BfCard(
      color: bg,
      padding: const EdgeInsets.all(Space.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Overline(label, color: fg.withValues(alpha: 0.7)),
        const SizedBox(height: Space.xs),
        DefaultTextStyle.merge(style: BfType.number(26, color: fg), child: value),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(caption!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg.withValues(alpha: 0.7))),
        ],
      ]),
    );
  }
}

/// Asset image with an on-brand painted fallback (never a grey box).
class AppImage extends StatelessWidget {
  const AppImage(this.path, {super.key, this.fit = BoxFit.contain, this.alignment = Alignment.bottomCenter, this.fallback, this.semanticLabel, this.width, this.height});
  final String? path;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? fallback;
  final String? semanticLabel;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final fb = fallback ?? const _Fallback();
    if (path == null) return fb;
    return Image.asset(
      path!,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => fb,
      frameBuilder: (context, child, frame, sync) {
        if (sync || Motion.reduced(context)) return child;
        return AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: Motion.medium, child: child);
      },
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback();
  @override
  Widget build(BuildContext context) =>
      Center(child: Icon(BfIcons.bolt, size: 48, color: context.bf.textFaint.withValues(alpha: 0.4)));
}

/// Typographic tile used for foods without a photo: pastel category colour,
/// big initials and the ring texture — deliberate, not a placeholder.
class MonogramTile extends StatelessWidget {
  const MonogramTile({super.key, required this.text, required this.color, this.size = 96});
  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words = text.split(RegExp(r'[\s&]+')).where((w) => w.isNotEmpty).toList();
    final initials = words.length >= 2 ? '${words[0][0]}${words[1][0]}' : text.substring(0, text.length >= 2 ? 2 : 1);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.28)),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        const Positioned.fill(child: ConcentricRings(color: Color(0x14000000), alignment: Alignment(1.2, 1.2), rings: 5)),
        Center(
          child: Text(initials.toUpperCase(),
              style: BfType.number(size * 0.34, color: BfPalette.ink, weight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

/// Achievement medallion: rendered medal image + icon overlay; greyed and
/// dimmed when locked.
class MedalBadge extends StatelessWidget {
  const MedalBadge({super.key, required this.def, required this.unlocked, this.size = 88, this.glow = false});
  final AchievementDef def;
  final bool unlocked;
  final double size;
  final bool glow;

  Color _tierColor() => switch (def.tier) {
        MedalTier.lavender => BfPalette.lavender,
        MedalTier.lime => BfPalette.lime,
        MedalTier.ember => BfPalette.ember,
      };

  @override
  Widget build(BuildContext context) {
    Widget medal = SizedBox.square(
      dimension: size,
      child: Stack(alignment: Alignment.center, children: [
        AppImage(Img.medal(def.tier), fit: BoxFit.contain, alignment: Alignment.center,
            fallback: Icon(BfIcons.hexagon, size: size, color: _tierColor())),
        Icon(BfIcons.forAchievement(def.icon), size: size * 0.34, color: _tierColor()),
      ]),
    );
    if (!unlocked) {
      medal = Opacity(
        opacity: 0.38,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.33, 0.33, 0.33, 0, 0, //
            0.33, 0.33, 0.33, 0, 0,
            0.33, 0.33, 0.33, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: medal,
        ),
      );
    } else if (glow) {
      medal = Glow(color: _tierColor(), radius: size * 0.75, child: medal);
    }
    return medal;
  }
}

/// Illustrated empty state with a gentle float animation.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.image, required this.title, required this.message, this.action, this.onAction, this.imageHeight = 150});
  final String image;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget img = SizedBox(height: imageHeight, child: AppImage(image, alignment: Alignment.center));
    if (!Motion.reduced(context)) {
      img = img
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: -4, end: 4, duration: 2400.ms, curve: Curves.easeInOut);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.xl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        img,
        const SizedBox(height: Space.lg),
        Text(title, style: t.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: Space.xs),
        Text(message, style: t.bodyMedium?.copyWith(color: context.bf.textMuted), textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: Space.lg),
          BfButton(label: action!, onPressed: onAction, expand: false),
        ],
      ]).enter(context),
    );
  }
}

/// Skeleton shimmer while data loads.
class Shimmer extends StatelessWidget {
  const Shimmer({super.key, this.height = 120, this.radius = Radii.card, this.width});
  final double height;
  final double? width;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    Widget box = Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: c.surface, borderRadius: radius),
    );
    if (Motion.reduced(context)) return box;
    return box
        .animate(onPlay: (ctl) => ctl.repeat())
        .shimmer(duration: 1300.ms, color: c.surfaceRaised.withValues(alpha: 0.9));
  }
}

/// Modal bottom sheet in the app style.
Future<T?> showBfSheet<T>(BuildContext context, {required WidgetBuilder builder, bool scroll = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.bf.surface,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: scroll ? SingleChildScrollView(child: builder(ctx)) : builder(ctx),
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: TextStyle(color: destructive ? ctx.bf.danger : ctx.bf.text, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
