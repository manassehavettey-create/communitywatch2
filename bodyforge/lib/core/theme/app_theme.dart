import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bf_colors.dart';
import 'tokens.dart';
import 'typography.dart';

abstract final class AppTheme {
  static ThemeData dark() => _build(BfColors.dark, Brightness.dark);
  static ThemeData light() => _build(BfColors.light, Brightness.light);

  static ThemeData _build(BfColors c, Brightness brightness) {
    final text = BfType.textTheme(c.text, c.textMuted);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.secondary,
      onSecondary: c.onSecondary,
      tertiary: c.tertiary,
      onTertiary: BfPalette.ink,
      error: c.danger,
      onError: BfPalette.ink,
      surface: c.surface,
      onSurface: c.text,
      surfaceContainerHighest: c.surfaceRaised,
      outline: c.outline,
      outlineVariant: c.outline,
      shadow: c.shadow,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      fontFamily: BfType.body,
      textTheme: text,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
      highlightColor: Colors.transparent,
      dividerTheme: DividerThemeData(color: c.outline, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: c.text,
        titleTextStyle: text.titleMedium,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: Radii.card),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 18),
        hintStyle: text.bodyLarge?.copyWith(color: c.textFaint),
        labelStyle: text.bodyMedium?.copyWith(color: c.textMuted),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: c.text),
        border: const OutlineInputBorder(borderRadius: Radii.tile, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: Radii.tile, borderSide: BorderSide(color: c.outline)),
        focusedBorder: OutlineInputBorder(borderRadius: Radii.tile, borderSide: BorderSide(color: c.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: Radii.tile, borderSide: BorderSide(color: c.danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: Radii.tile, borderSide: BorderSide(color: c.danger, width: 2)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        showDragHandle: true,
        dragHandleColor: c.outline,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.cardLarge),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.isDark ? c.sheet : BfPalette.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.isDark ? BfPalette.ink : Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: Radii.tile),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? BfPalette.ink : c.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceRaised),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.surfaceRaised,
        thumbColor: c.primary,
        overlayColor: c.primary.withValues(alpha: 0.15),
        valueIndicatorColor: c.primary,
        valueIndicatorTextStyle: text.labelMedium?.copyWith(color: BfPalette.ink),
        trackHeight: 6,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary, linearTrackColor: c.surfaceRaised),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.primary.withValues(alpha: 0.35),
        selectionHandleColor: c.primary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
