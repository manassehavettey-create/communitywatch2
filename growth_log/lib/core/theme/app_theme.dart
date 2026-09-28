import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

const _ui = 'Urbanist';
const _display = 'Archivo';

/// Semantic colours that change between light and dark mode.
@immutable
class GLColors extends ThemeExtension<GLColors> {
  const GLColors({
    required this.canvas,
    required this.surface,
    required this.card,
    required this.text,
    required this.muted,
    required this.hairline,
    required this.inverse,
    required this.onInverse,
  });

  final Color canvas;
  final Color surface;
  final Color card;
  final Color text;
  final Color muted;
  final Color hairline;

  /// The high-contrast block colour: ink in light mode, white in dark mode.
  final Color inverse;
  final Color onInverse;

  static const light = GLColors(
    canvas: Palette.canvas,
    surface: Palette.white,
    card: Palette.white,
    text: Palette.ink,
    muted: Palette.muted,
    hairline: Palette.hairline,
    inverse: Palette.ink,
    onInverse: Palette.white,
  );

  static const dark = GLColors(
    canvas: Palette.darkCanvas,
    surface: Palette.darkSurface,
    card: Palette.darkCard,
    text: Color(0xFFF3F3F0),
    muted: Palette.darkMuted,
    hairline: Palette.darkHairline,
    inverse: Palette.white,
    onInverse: Palette.ink,
  );

  @override
  GLColors copyWith({
    Color? canvas,
    Color? surface,
    Color? card,
    Color? text,
    Color? muted,
    Color? hairline,
    Color? inverse,
    Color? onInverse,
  }) {
    return GLColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      hairline: hairline ?? this.hairline,
      inverse: inverse ?? this.inverse,
      onInverse: onInverse ?? this.onInverse,
    );
  }

  @override
  GLColors lerp(GLColors? other, double t) {
    if (other == null) return this;
    return GLColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      inverse: Color.lerp(inverse, other.inverse, t)!,
      onInverse: Color.lerp(onInverse, other.onInverse, t)!,
    );
  }
}

/// Type scale from DESIGN.md.
abstract final class AppText {
  static const display = TextStyle(
    fontFamily: _display,
    fontWeight: FontWeight.w900,
    fontSize: 44,
    height: 1.0,
    letterSpacing: -1.2,
  );
  static const displayItalic = TextStyle(
    fontFamily: _display,
    fontWeight: FontWeight.w300,
    fontStyle: FontStyle.italic,
    fontSize: 44,
    height: 1.0,
    letterSpacing: -1.2,
  );
  static const headline = TextStyle(
    fontFamily: _ui,
    fontWeight: FontWeight.w700,
    fontSize: 28,
    height: 1.15,
    letterSpacing: -0.4,
  );
  static const title = TextStyle(
    fontFamily: _ui,
    fontWeight: FontWeight.w600,
    fontSize: 20,
    height: 1.2,
  );
  static const subtitle = TextStyle(
    fontFamily: _ui,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 1.3,
  );
  static const body = TextStyle(
    fontFamily: _ui,
    fontWeight: FontWeight.w500,
    fontSize: 15,
    height: 1.4,
  );
  static const caption = TextStyle(
    fontFamily: _ui,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 1.3,
    letterSpacing: 0.2,
  );
  static const numeral = TextStyle(
    fontFamily: _ui,
    fontWeight: FontWeight.w700,
    fontSize: 32,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const button = TextStyle(
    fontFamily: _ui,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    letterSpacing: 0.1,
  );
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, GLColors.light);
  static ThemeData dark() => _build(Brightness.dark, GLColors.dark);

  static ThemeData _build(Brightness brightness, GLColors c) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.inverse,
      onPrimary: c.onInverse,
      secondary: Palette.lime,
      onSecondary: Palette.ink,
      tertiary: Palette.lavender,
      onTertiary: Palette.ink,
      error: Palette.danger,
      onError: Palette.white,
      surface: c.surface,
      onSurface: c.text,
      surfaceContainerHighest: c.card,
      outline: c.hairline,
      outlineVariant: c.hairline,
    );

    TextStyle t(TextStyle s) => s.copyWith(color: c.text);
    final textTheme = TextTheme(
      displayLarge: t(AppText.display),
      displayMedium: t(AppText.display.copyWith(fontSize: 36)),
      headlineMedium: t(AppText.headline),
      headlineSmall: t(AppText.headline.copyWith(fontSize: 24)),
      titleLarge: t(AppText.title),
      titleMedium: t(AppText.subtitle),
      titleSmall: t(AppText.body.copyWith(fontWeight: FontWeight.w600)),
      bodyLarge: t(AppText.body.copyWith(fontSize: 16)),
      bodyMedium: t(AppText.body),
      bodySmall: t(AppText.caption).copyWith(color: c.muted),
      labelLarge: t(AppText.button),
      labelMedium: t(AppText.caption.copyWith(fontWeight: FontWeight.w600)),
      labelSmall: t(AppText.caption),
    );

    const pillShape = StadiumBorder();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: _ui,
      textTheme: textTheme,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      splashFactory: InkSparkle.splashFactory,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: t(AppText.subtitle),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.inverse,
          foregroundColor: c.onInverse,
          shape: pillShape,
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: AppText.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          shape: pillShape,
          side: BorderSide(color: c.text, width: 1.4),
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: AppText.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.text,
          shape: pillShape,
          textStyle: AppText.button,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: AppText.body.copyWith(color: c.muted),
        labelStyle: AppText.body.copyWith(color: c.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: Radii.cardSmallR,
          borderSide: BorderSide(color: c.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.cardSmallR,
          borderSide: BorderSide(color: c.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.cardSmallR,
          borderSide: BorderSide(color: c.text, width: 1.4),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: Radii.cardSmallR,
          borderSide: BorderSide(color: Palette.danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: Radii.cardSmallR,
          borderSide: BorderSide(color: Palette.danger, width: 1.4),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.canvas,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.hairline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.hero)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.cardR),
        titleTextStyle: t(AppText.title),
        contentTextStyle: t(AppText.body),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.inverse,
        contentTextStyle: AppText.body.copyWith(color: c.onInverse),
        actionTextColor: Palette.lime,
        shape: const RoundedRectangleBorder(borderRadius: Radii.cardSmallR),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Palette.ink : c.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Palette.lime : c.hairline,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.text,
        linearTrackColor: c.hairline,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.cardR),
        dialHandColor: Palette.lime,
        hourMinuteShape: const RoundedRectangleBorder(
          borderRadius: Radii.cardSmallR,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.cardR),
        todayBorder: BorderSide(color: c.text),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Palette.ink : null,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Palette.lime : null,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

extension ThemeX on BuildContext {
  GLColors get gl => Theme.of(this).extension<GLColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
