import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Typography: Archivo (variable width/weight) for display and numerals,
/// Inter for body copy. Variable axes are set explicitly via [FontVariation].
abstract final class AppType {
  static TextStyle display(double size, {double weight = 800, double width = 112, Color? color, double height = 1.02, double spacing = -0.5, bool italic = false}) =>
      TextStyle(
        fontFamily: 'Archivo',
        fontSize: size,
        height: height,
        letterSpacing: spacing,
        color: color,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        fontWeight: _weight(weight),
        fontVariations: [FontVariation('wght', weight), FontVariation('wdth', width)],
      );

  /// Tabular numerals for scores/stats so digits never jitter while updating.
  static TextStyle numeric(double size, {double weight = 800, Color? color, double width = 100}) => display(size, weight: weight, width: width, color: color, spacing: -0.5, height: 1.0)
      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static TextStyle body(double size, {double weight = 400, Color? color, double height = 1.35, double spacing = 0}) => TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        height: height,
        letterSpacing: spacing,
        color: color,
        fontWeight: _weight(weight),
        fontVariations: [FontVariation('wght', weight)],
      );

  /// Uppercase overline used for competition names and section labels.
  static TextStyle overline({Color? color, double size = 11.5}) => body(size, weight: 650, color: color, spacing: 1.1, height: 1.2);

  static FontWeight _weight(double w) => FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];
}

ThemeData buildTheme(AppColors c) {
  final brightness = c.isDark ? Brightness.dark : Brightness.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.away,
    onSecondary: c.bg,
    error: c.loss,
    onError: c.bg,
    surface: c.surface,
    onSurface: c.text,
    surfaceContainerHighest: c.surface3,
    outline: c.hairline,
  );

  final textTheme = TextTheme(
    displayLarge: AppType.display(44, color: c.text, spacing: -1.2),
    displayMedium: AppType.display(34, color: c.text, spacing: -1),
    displaySmall: AppType.display(28, color: c.text),
    headlineMedium: AppType.display(24, weight: 760, width: 106, color: c.text),
    headlineSmall: AppType.display(20, weight: 740, width: 104, color: c.text, spacing: -0.2),
    titleLarge: AppType.display(18, weight: 720, width: 102, color: c.text, spacing: -0.1),
    titleMedium: AppType.body(16, weight: 620, color: c.text),
    titleSmall: AppType.body(14, weight: 620, color: c.text),
    bodyLarge: AppType.body(16, color: c.text),
    bodyMedium: AppType.body(14.5, color: c.text),
    bodySmall: AppType.body(13, color: c.textMuted),
    labelLarge: AppType.body(14, weight: 620, color: c.text),
    labelMedium: AppType.overline(color: c.textMuted),
    labelSmall: AppType.body(12, weight: 560, color: c.textMuted),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    fontFamily: 'Inter',
    textTheme: textTheme,
    extensions: [c],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleMedium,
      iconTheme: IconThemeData(color: c.text),
      systemOverlayStyle: c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.textFaint,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onAccent : c.textMuted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.surface3),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface2,
      hintStyle: AppType.body(15, color: c.textFaint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: const OutlineInputBorder(borderRadius: Radii.pillAll, borderSide: BorderSide.none),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.surface3,
      contentTextStyle: AppType.body(14, color: c.text),
      shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent, linearTrackColor: c.surface3),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}
