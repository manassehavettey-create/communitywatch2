import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(FolioColors.light, Brightness.light);
  static ThemeData dark() => _build(FolioColors.dark, Brightness.dark);

  static ThemeData _build(FolioColors c, Brightness b) {
    final text = buildTextTheme(c.ink, c.inkMuted);
    final scheme = ColorScheme(
      brightness: b,
      primary: c.ink,
      onPrimary: c.onInk,
      secondary: c.lavender,
      onSecondary: const Color(0xFF161514),
      tertiary: c.lime,
      onTertiary: const Color(0xFF161514),
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.ink,
      surfaceContainerHighest: c.surfaceMuted,
      surfaceContainerHigh: c.surfaceMuted,
      surfaceContainer: c.surface,
      surfaceContainerLow: c.surface,
      outline: c.hairline,
      outlineVariant: c.hairline,
      onSurfaceVariant: c.inkMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.paper,
      canvasColor: c.paper,
      fontFamily: Fonts.ui,
      textTheme: text,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
      highlightColor: Colors.transparent,
      dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: b == Brightness.light
            ? SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        showDragHandle: true,
        dragHandleColor: c.hairline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        contentTextStyle: text.labelLarge?.copyWith(color: c.onInk),
        actionTextColor: c.lime,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceMuted,
        hintStyle: text.bodyMedium?.copyWith(color: c.inkMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: const OutlineInputBorder(
          borderRadius: Radii.pillAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.pillAll,
          borderSide: BorderSide(color: c.lavender, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.ink,
          foregroundColor: c.onInk,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          side: BorderSide(color: c.hairline, width: 1.5),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ink,
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onInk : c.inkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.ink : c.surfaceMuted,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.ink,
        inactiveTrackColor: c.surfaceMuted,
        thumbColor: c.ink,
        overlayColor: c.lavender.withValues(alpha: 0.18),
        trackHeight: 6,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.ink,
        linearTrackColor: c.surfaceMuted,
        circularTrackColor: c.surfaceMuted,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.ink,
        selectionColor: c.lavender.withValues(alpha: 0.35),
        selectionHandleColor: c.lavender,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.ink,
        textColor: c.ink,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
