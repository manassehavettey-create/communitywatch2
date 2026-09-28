import 'package:flutter/material.dart';

/// Font families bundled in pubspec.yaml.
abstract final class Fonts {
  static const display = 'Bricolage';
  static const ui = 'Manrope';
  static const reading = 'Literata';
}

/// Variable fonts need the `wght` axis set explicitly to render the
/// requested weight on every platform.
TextStyle _style(
  String family,
  double size,
  int weight, {
  double? height,
  double letterSpacing = 0,
  List<FontFeature>? features,
}) {
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: FontWeight.values.firstWhere(
      (w) => w.value >= weight,
      orElse: () => FontWeight.w900,
    ),
    fontVariations: [FontVariation('wght', weight.toDouble())],
    height: height,
    letterSpacing: letterSpacing,
    fontFeatures: features,
  );
}

TextTheme buildTextTheme(Color ink, Color muted) {
  return TextTheme(
    // display — screen titles
    displayLarge: _style(Fonts.display, 40, 800, height: 1.02, letterSpacing: -0.8)
        .copyWith(color: ink),
    // numeral — big stats / timers
    displayMedium: _style(
      Fonts.display,
      44,
      800,
      height: 1.0,
      letterSpacing: -1.2,
      features: const [FontFeature.tabularFigures()],
    ).copyWith(color: ink),
    displaySmall: _style(Fonts.display, 32, 800, height: 1.05, letterSpacing: -0.6)
        .copyWith(color: ink),
    headlineMedium: _style(Fonts.display, 28, 750, height: 1.1, letterSpacing: -0.4)
        .copyWith(color: ink),
    headlineSmall: _style(Fonts.display, 24, 700, height: 1.15, letterSpacing: -0.3)
        .copyWith(color: ink),
    titleLarge: _style(Fonts.display, 20, 700, height: 1.2, letterSpacing: -0.2)
        .copyWith(color: ink),
    titleMedium: _style(Fonts.ui, 16, 700, height: 1.3).copyWith(color: ink),
    titleSmall: _style(Fonts.ui, 14, 700, height: 1.3).copyWith(color: ink),
    bodyLarge: _style(Fonts.ui, 16, 500, height: 1.5).copyWith(color: ink),
    bodyMedium: _style(Fonts.ui, 15, 500, height: 1.45).copyWith(color: ink),
    bodySmall: _style(Fonts.ui, 12, 600, height: 1.35).copyWith(color: muted),
    labelLarge: _style(Fonts.ui, 14, 700, height: 1.2).copyWith(color: ink),
    labelMedium: _style(Fonts.ui, 13, 700, height: 1.2).copyWith(color: ink),
    labelSmall: _style(Fonts.ui, 11, 700, height: 1.2, letterSpacing: 0.6)
        .copyWith(color: muted),
  );
}

/// Style for reflowed book text in Text view.
TextStyle readingTextStyle({
  required double size,
  required double lineHeight,
  required Color color,
}) =>
    _style(Fonts.reading, size, 420, height: lineHeight).copyWith(color: color);

/// Weight helper for ad-hoc styles that still need variable-font weights.
TextStyle withWeight(TextStyle base, int weight) => base.copyWith(
      fontWeight: FontWeight.values.firstWhere(
        (w) => w.value >= weight,
        orElse: () => FontWeight.w900,
      ),
      fontVariations: [FontVariation('wght', weight.toDouble())],
    );
