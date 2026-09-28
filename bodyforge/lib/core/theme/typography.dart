import 'package:flutter/material.dart';

/// Type scale. Display/headline/numbers use Sora (geometric, heavy),
/// body/labels use Manrope. Numbers always use tabular figures so timers and
/// counters don't jitter while ticking.
abstract final class BfType {
  static const display = 'Sora';
  static const body = 'Manrope';

  static const _tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme(Color text, Color muted) => TextTheme(
        displayLarge: TextStyle(
            fontFamily: display, fontSize: 56, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -1.5, color: text),
        displayMedium: TextStyle(
            fontFamily: display, fontSize: 44, fontWeight: FontWeight.w700, height: 1.05, letterSpacing: -1.2, color: text),
        displaySmall: TextStyle(
            fontFamily: display, fontSize: 34, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -0.8, color: text),
        headlineLarge: TextStyle(
            fontFamily: display, fontSize: 28, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.5, color: text),
        headlineMedium: TextStyle(
            fontFamily: display, fontSize: 24, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.4, color: text),
        headlineSmall: TextStyle(
            fontFamily: display, fontSize: 20, fontWeight: FontWeight.w600, height: 1.25, letterSpacing: -0.2, color: text),
        titleLarge: TextStyle(
            fontFamily: display, fontSize: 18, fontWeight: FontWeight.w600, height: 1.3, color: text),
        titleMedium: TextStyle(
            fontFamily: body, fontSize: 16, fontWeight: FontWeight.w700, height: 1.35, color: text),
        titleSmall: TextStyle(
            fontFamily: body, fontSize: 14, fontWeight: FontWeight.w700, height: 1.35, color: text),
        bodyLarge: TextStyle(
            fontFamily: body, fontSize: 16, fontWeight: FontWeight.w500, height: 1.45, color: text),
        bodyMedium: TextStyle(
            fontFamily: body, fontSize: 14, fontWeight: FontWeight.w500, height: 1.45, color: text),
        bodySmall: TextStyle(
            fontFamily: body, fontSize: 12, fontWeight: FontWeight.w500, height: 1.4, color: muted),
        labelLarge: TextStyle(
            fontFamily: body, fontSize: 15, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 0.1, color: text),
        labelMedium: TextStyle(
            fontFamily: body, fontSize: 13, fontWeight: FontWeight.w600, height: 1.2, color: text),
        labelSmall: TextStyle(
            fontFamily: body, fontSize: 11, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 0.8, color: muted),
      );

  /// Giant numerals (timer, counters).
  static TextStyle number(double size, {Color? color, FontWeight weight = FontWeight.w600}) => TextStyle(
        fontFamily: display,
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
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        height: 1.2,
        color: color,
      );
}
