import 'package:flutter/material.dart';

import 'tokens.dart';

/// Theme-aware colour roles. Access with `context.bf`.
@immutable
class BfColors extends ThemeExtension<BfColors> {
  const BfColors({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.outline,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.tertiary,
    required this.ember,
    required this.sheet,
    required this.onSheet,
    required this.success,
    required this.warning,
    required this.danger,
    required this.navBar,
    required this.shadow,
    required this.isDark,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color outline;
  final Color text;
  final Color textMuted;
  final Color textFaint;

  /// Forge Lime. Always paired with [onPrimary] (ink) text.
  final Color primary;
  final Color onPrimary;

  /// Lime used *as text* on the canvas. Lime on white fails contrast, so the
  /// light theme uses a deep olive (≈5:1 on white).
  Color get accentText => isDark ? primary : const Color(0xFF5B7500);

  /// Lavender.
  final Color secondary;
  final Color onSecondary;

  /// Lilac.
  final Color tertiary;
  final Color ember;

  /// The white "bottom sheet" surface used in the player / cards (paper).
  final Color sheet;
  final Color onSheet;

  final Color success;
  final Color warning;
  final Color danger;
  final Color navBar;
  final Color shadow;
  final bool isDark;

  static const dark = BfColors(
    canvas: BfPalette.canvasDark,
    surface: BfPalette.surfaceDark,
    surfaceRaised: BfPalette.surfaceRaisedDark,
    outline: BfPalette.outlineDark,
    text: Color(0xFFF5F5F2),
    textMuted: Color(0xFFA9A9B2),
    textFaint: Color(0xFF6E6E78),
    primary: BfPalette.lime,
    onPrimary: BfPalette.ink,
    secondary: BfPalette.lavender,
    onSecondary: BfPalette.ink,
    tertiary: BfPalette.lilac,
    ember: BfPalette.ember,
    sheet: BfPalette.paper,
    onSheet: BfPalette.ink,
    success: BfPalette.success,
    warning: BfPalette.warning,
    danger: BfPalette.danger,
    navBar: Color(0xFF26262B),
    shadow: Color(0x66000000),
    isDark: true,
  );

  static const light = BfColors(
    canvas: BfPalette.canvasLight,
    surface: BfPalette.surfaceLight,
    surfaceRaised: BfPalette.surfaceRaisedLight,
    outline: BfPalette.outlineLight,
    text: BfPalette.ink,
    textMuted: Color(0xFF5E5E66),
    textFaint: Color(0xFF9A9AA2),
    primary: BfPalette.limeDeep,
    onPrimary: BfPalette.ink,
    secondary: BfPalette.lavenderDeep,
    onSecondary: BfPalette.ink,
    tertiary: BfPalette.lilacSoft,
    ember: BfPalette.emberDeep,
    sheet: BfPalette.surfaceLight,
    onSheet: BfPalette.ink,
    success: Color(0xFF2FB86A),
    warning: Color(0xFFE0A21B),
    danger: Color(0xFFE5484D),
    navBar: BfPalette.ink,
    shadow: Color(0x1A1B1B24),
    isDark: false,
  );

  @override
  BfColors copyWith({Color? primary, Color? secondary}) => BfColors(
        canvas: canvas,
        surface: surface,
        surfaceRaised: surfaceRaised,
        outline: outline,
        text: text,
        textMuted: textMuted,
        textFaint: textFaint,
        primary: primary ?? this.primary,
        onPrimary: onPrimary,
        secondary: secondary ?? this.secondary,
        onSecondary: onSecondary,
        tertiary: tertiary,
        ember: ember,
        sheet: sheet,
        onSheet: onSheet,
        success: success,
        warning: warning,
        danger: danger,
        navBar: navBar,
        shadow: shadow,
        isDark: isDark,
      );

  @override
  BfColors lerp(BfColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return BfColors(
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      outline: l(outline, other.outline),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      textFaint: l(textFaint, other.textFaint),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      secondary: l(secondary, other.secondary),
      onSecondary: l(onSecondary, other.onSecondary),
      tertiary: l(tertiary, other.tertiary),
      ember: l(ember, other.ember),
      sheet: l(sheet, other.sheet),
      onSheet: l(onSheet, other.onSheet),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      navBar: l(navBar, other.navBar),
      shadow: l(shadow, other.shadow),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }

  /// Soft single shadow used on light theme cards; none on dark.
  List<BoxShadow> get cardShadow => isDark
      ? const []
      : [BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8))];

  /// Pick a readable text colour for a given background.
  Color onColor(Color background) =>
      background.computeLuminance() > 0.45 ? BfPalette.ink : const Color(0xFFF5F5F2);
}

extension BfColorsX on BuildContext {
  BfColors get bf => Theme.of(this).extension<BfColors>()!;
}
