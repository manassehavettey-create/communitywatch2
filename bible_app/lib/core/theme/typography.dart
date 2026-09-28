import 'package:flutter/material.dart';

/// Font families bundled in assets/fonts (all SIL OFL).
abstract final class Fonts {
  static const display = 'Fraunces';
  static const ui = 'Urbanist';
  static const hand = 'Caveat';
}

/// Scripture typefaces offered in reader settings.
enum ScriptureFont {
  literata('Literata', 'Literata', true),
  sourceSerif('Source Serif', 'SourceSerif4', true),
  urbanist('Urbanist', 'Urbanist', true),
  atkinson('Atkinson Hyperlegible', 'AtkinsonHyperlegible', false);

  const ScriptureFont(this.label, this.family, this.variable);

  final String label;
  final String family;

  /// Variable fonts need an explicit `wght` axis value to render weights.
  final bool variable;

  static ScriptureFont fromName(String? name) => ScriptureFont.values
      .firstWhere((f) => f.name == name, orElse: () => ScriptureFont.literata);
}

/// Builds a style for a (possibly variable) font. Flutter doesn't map
/// [FontWeight] onto a variable font's `wght` axis on every platform, so the
/// axis is set explicitly as well.
TextStyle fontStyle(
  String family, {
  required double size,
  double? height,
  FontWeight weight = FontWeight.w400,
  double letterSpacing = 0,
  Color? color,
  FontStyle? style,
  bool variable = true,
  List<FontVariation> extraAxes = const [],
}) {
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    height: height,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    color: color,
    fontStyle: style,
    fontVariations: variable
        ? [FontVariation.weight(weight.value.toDouble()), ...extraAxes]
        : null,
  );
}

TextStyle _display(double size, double height, {FontStyle? style}) => fontStyle(
  Fonts.display,
  size: size,
  height: height / size,
  weight: FontWeight.w600,
  letterSpacing: -size * 0.02,
  style: style,
  // Soft, low-contrast cut of Fraunces; optical size follows the size.
  extraAxes: [
    const FontVariation('SOFT', 60),
    FontVariation('opsz', size.clamp(9, 144).toDouble()),
  ],
);

TextStyle _ui(double size, double height, FontWeight weight) =>
    fontStyle(Fonts.ui, size: size, height: height / size, weight: weight);

/// App type scale (DESIGN.md → Type scale).
abstract final class AppType {
  static final displayL = _display(44, 46);
  static final displayM = _display(34, 38);
  static final displayS = _display(26, 30);
  static final titleL = _ui(24, 30, FontWeight.w700);
  static final titleM = _ui(19, 24, FontWeight.w700);
  static final titleS = _ui(16, 20, FontWeight.w700);
  static final body = _ui(16, 24, FontWeight.w500);
  static final bodySmall = _ui(14, 20, FontWeight.w500);
  static final label = _ui(14, 18, FontWeight.w600);
  static final caption = _ui(12, 16, FontWeight.w500);
  static final overline = fontStyle(
    Fonts.ui,
    size: 11,
    height: 14 / 11,
    weight: FontWeight.w700,
    letterSpacing: 1.1,
  );

  /// Light italic sub-line under a display heading ("just for today").
  static final displayItalic = fontStyle(
    Fonts.ui,
    size: 26,
    height: 30 / 26,
    weight: FontWeight.w300,
    style: FontStyle.italic,
    letterSpacing: -0.4,
  );

  static final hand = fontStyle(Fonts.hand, size: 22, height: 1.1);

  static TextTheme textTheme(Color ink, Color soft) => TextTheme(
    displayLarge: displayL.copyWith(color: ink),
    displayMedium: displayM.copyWith(color: ink),
    displaySmall: displayS.copyWith(color: ink),
    headlineMedium: titleL.copyWith(color: ink),
    titleLarge: titleL.copyWith(color: ink),
    titleMedium: titleM.copyWith(color: ink),
    titleSmall: titleS.copyWith(color: ink),
    bodyLarge: body.copyWith(color: ink),
    bodyMedium: bodySmall.copyWith(color: ink),
    bodySmall: caption.copyWith(color: soft),
    labelLarge: label.copyWith(color: ink),
    labelMedium: caption.copyWith(color: ink),
    labelSmall: overline.copyWith(color: soft),
  );
}
