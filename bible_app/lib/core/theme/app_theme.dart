import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

/// App-wide appearance setting.
enum AppThemeMode {
  system('Match system'),
  light('Light'),
  dark('Night');

  const AppThemeMode(this.label);
  final String label;

  ThemeMode get themeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  static AppThemeMode fromName(String? name) => AppThemeMode.values.firstWhere(
    (m) => m.name == name,
    orElse: () => AppThemeMode.system,
  );
}

abstract final class AppTheme {
  static ThemeData light() => _build(AppPalette.light);
  static ThemeData dark() => _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final brightness = p.isDark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.ink,
      onPrimary: p.paper,
      secondary: p.tangerine,
      onSecondary: const Color(0xFF141414),
      error: const Color(0xFFC2371B),
      onError: Colors.white,
      surface: p.paper,
      onSurface: p.ink,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.paperDeep,
      surfaceContainerHigh: p.paperDeep,
      surfaceContainerHighest: p.paperDeep,
      onSurfaceVariant: p.inkSoft,
      outline: p.line,
      outlineVariant: p.line,
      inverseSurface: p.ink,
      onInverseSurface: p.paper,
    );
    final text = AppType.textTheme(p.ink, p.inkSoft);

    OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
      borderRadius: Radii.smAll,
      borderSide: BorderSide(color: c, width: w),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.paper,
      canvasColor: p.paper,
      fontFamily: Fonts.ui,
      textTheme: text,
      extensions: [p],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: p.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.titleM.copyWith(color: p.ink),
        systemOverlayStyle: p.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: p.ink, size: 22),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.paperDeep,
        hintStyle: AppType.body.copyWith(color: p.inkMute),
        labelStyle: AppType.label.copyWith(color: p.inkSoft),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x4,
        ),
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        focusedBorder: border(p.ink),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.tangerine,
        selectionColor: p.tangerine.withValues(alpha: 0.3),
        selectionHandleColor: p.tangerine,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? p.surface : p.ink,
        contentTextStyle: AppType.label.copyWith(
          color: p.isDark ? p.ink : p.paper,
        ),
        actionTextColor: p.tangerine,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        titleTextStyle: AppType.titleM.copyWith(color: p.ink),
        contentTextStyle: AppType.body.copyWith(color: p.inkSoft),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.paper : p.inkMute,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.ink : p.paperDeep,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.ink : p.line,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.ink,
        inactiveTrackColor: p.line,
        thumbColor: p.ink,
        overlayColor: p.ink.withValues(alpha: 0.08),
        trackHeight: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.ink,
        linearTrackColor: p.line,
        circularTrackColor: p.line,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.ink,
          textStyle: AppType.label,
          shape: const StadiumBorder(),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
