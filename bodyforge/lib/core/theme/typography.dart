import 'package:flutter/material.dart';

/// Type scale. Display/headline/numbers use Sora (geometric, heavy),
/// body/labels use Manrope. Numbers always use tabular figures so timers and
/// counters don't jitter while ticking.
abstract final class BfType {
  static const display = 'Sora';
  static const body = 'Manrope';

  /// Glyphs the brand fonts lack (₵ ✓ → ≈ …) come from a tiny bundled subset
  /// so they look the same on every phone.
  static const fallback = ['BfSymbols'];

  static const _tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme(Color text, Color muted) => TextTheme(
        displayLarge: TextStyle(
            fontFamily: display, fontFamilyFallback: fallback, fontSize: 56, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -1.5, color: text),
        displayMedium: TextStyle(
            fontFamily: display, fontFamilyFallback: fallback, fontSize: 44, fontWeight: FontWeight.w700, height: 1.05, letterSpacing: -1.2, color: text),
        displaySmall: TextStyle(
            fontFamily: display, fontFamilyFallback: fallback, fontSize: 34, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -0.8, color: text),
        headlineLarge: TextStyle(
            fontFamily: display, fontFamilyFallback: fallback, fontSize: 28, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.5, color: text),
        headlineMedium: TextStyle(
            fontFamily: display, fontFamilyFallback: fallback, fontSize: 24, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.4, color: text),
        headlineSmall: TextStyle(
            fontFamily: display, fontFamilyFallback: fallback, fontSize: 20, fontWeight: FontWeight.w600, height: 1.25, letterSpacing: -0.2, color: text),
        titleLarge: TextStyle(
            fontFamily: display, fontFamilyFallback: fallback, fontSize: 18, fontWeight: FontWeight.w600, height: 1.3, color: text),
        titleMedium: TextStyle(
            fontFamily: body, fontFamilyFallback: fallback, fontSize: 16, fontWeight: FontWeight.w700, height: 1.35, color: text),
        titleSmall: TextStyle(
            fontFamily: body, fontFamilyFallback: fallback, fontSize: 14, fontWeight: FontWeight.w700, height: 1.35, color: text),
        bodyLarge: TextStyle(
            fontFamily: body, fontFamilyFallback: fallback, fontSize: 16, fontWeight: FontWeight.w500, height: 1.45, color: text),
        bodyMedium: TextStyle(
            fontFamily: body, fontFamilyFallback: fallback, fontSize: 14, fontWeight: FontWeight.w500, height: 1.45, color: text),
        bodySmall: TextStyle(
            fontFamily: body, fontFamilyFallback: fallback, fontSize: 12, fontWeight: FontWeight.w500, height: 1.4, color: muted),
        labelLarge: TextStyle(
            fontFamily: body, fontFamilyFallback: fallback, fontSize: 15, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 0.1, color: text),
        labelMedium: TextStyle(
            fontFamily: body, fontFamilyFallback: fallback, fontSize: 13, fontWeight: FontWeight.w600, height: 1.2, color: text),
        labelSmall: TextStyle(
            fontFamily: body, fontFamilyFallback: fallback, fontSize: 11, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 0.8, color: muted),
      );

  /// Giant numerals (timer, counters).
  static TextStyle number(double size, {Color? color, FontWeight weight = FontWeight.w600}) => TextStyle(
        fontFamily: display,
        fontFamilyFallback: fallback,
        fontSize: size,
        fontWeight: weight,
        height: 1.0,
        letterSpacing: -size * 0.03,
        color: color,
        fontFeatures: _tabular,
      );

  /// Small caps-style overline ("TODAY'S MISSION").
  static TextStyle overline(Color color) => TextStyle(
        fontFamily: body,
        fontFamilyFallback: fallback,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        height: 1.2,
        color: color,
      );
}
