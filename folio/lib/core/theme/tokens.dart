import 'package:flutter/material.dart';

/// Spacing scale (4 pt base). See DESIGN.md.
abstract final class Space {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x14 = 56;

  /// Horizontal screen gutter.
  static const double gutter = 20;

  /// Bottom padding that keeps content clear of the floating nav bar.
  static const double navClearance = 112;
}

abstract final class Radii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 20;
  static const double lg = 28;
  static const double xl = 36;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// The pastel "shelf" colours shared by collections, stat tiles and
/// highlights. Order is persisted (by index) in the database — only append.
enum ShelfColor {
  butter(Color(0xFFF8D96A), Color(0xFFFCF0C4), 'Butter'),
  mint(Color(0xFFB5EBCB), Color(0xFFDDF5E6), 'Mint'),
  sky(Color(0xFFA9CBF2), Color(0xFFDCE9FA), 'Sky'),
  rose(Color(0xFFF7C3D6), Color(0xFFFBE3EC), 'Rose'),
  lilac(Color(0xFFCDB8FA), Color(0xFFE7DEFD), 'Lilac'),
  peach(Color(0xFFF9A77E), Color(0xFFFDE3D5), 'Peach'),
  lime(Color(0xFFD6F26B), Color(0xFFEEF8C8), 'Lime'),
  lavender(Color(0xFFA58BF7), Color(0xFFE7DEFD), 'Lavender');

  const ShelfColor(this.strong, this.tint, this.label);

  final Color strong;
  final Color tint;
  final String label;

  static ShelfColor fromIndex(int i) => (i >= 0 && i < values.length) ? values[i] : ShelfColor.butter;

  /// Colours offered for highlights (first five).
  static const List<ShelfColor> highlightColors = [butter, mint, sky, rose, lilac];

  /// Colours offered for collections.
  static const List<ShelfColor> collectionColors = [lavender, lime, butter, peach, mint, sky];

  /// Card background in the given brightness: the pale tint in light mode,
  /// a dimmed version of the strong colour in dark mode.
  Color cardBackground(Brightness b) =>
      b == Brightness.light ? tint : Color.alphaBlend(strong.withValues(alpha: 0.22), const Color(0xFF1C1A18));

  /// Foreground to use on [cardBackground].
  Color cardForeground(Brightness b) => b == Brightness.light ? const Color(0xFF161514) : const Color(0xFFEDE6D8);
}

/// Semantic colours exposed as a ThemeExtension so every widget reads them
/// from the active theme (light / dark).
@immutable
class FolioColors extends ThemeExtension<FolioColors> {
  const FolioColors({
    required this.paper,
    required this.surface,
    required this.surfaceMuted,
    required this.hairline,
    required this.ink,
    required this.inkMuted,
    required this.onInk,
    required this.lavender,
    required this.lime,
    required this.danger,
    required this.shadow,
  });

  final Color paper;
  final Color surface;
  final Color surfaceMuted;
  final Color hairline;
  final Color ink;
  final Color inkMuted;
  final Color onInk;
  final Color lavender;
  final Color lime;
  final Color danger;
  final Color shadow;

  static const light = FolioColors(
    paper: Color(0xFFF6F1E7),
    surface: Color(0xFFFFFDF8),
    surfaceMuted: Color(0xFFEDE6D8),
    hairline: Color(0xFFE2DACB),
    ink: Color(0xFF161514),
    inkMuted: Color(0xFF6B665E),
    onInk: Color(0xFFF6F1E7),
    lavender: Color(0xFFA58BF7),
    lime: Color(0xFFD6F26B),
    danger: Color(0xFFD9534A),
    shadow: Color(0x14161514),
  );

  static const dark = FolioColors(
    paper: Color(0xFF121110),
    surface: Color(0xFF1C1A18),
    surfaceMuted: Color(0xFF262320),
    hairline: Color(0xFF34302B),
    ink: Color(0xFFEDE6D8),
    inkMuted: Color(0xFF9D968A),
    onInk: Color(0xFF121110),
    lavender: Color(0xFFB6A2F5),
    lime: Color(0xFFC9E26A),
    danger: Color(0xFFEF7A70),
    shadow: Color(0x00000000),
  );

  List<BoxShadow> get floatingShadow =>
      shadow.a == 0 ? const [] : [BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8))];

  @override
  FolioColors copyWith() => this;

  @override
  FolioColors lerp(ThemeExtension<FolioColors>? other, double t) {
    if (other is! FolioColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FolioColors(
      paper: l(paper, other.paper),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      hairline: l(hairline, other.hairline),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      onInk: l(onInk, other.onInk),
      lavender: l(lavender, other.lavender),
      lime: l(lime, other.lime),
      danger: l(danger, other.danger),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension FolioThemeX on BuildContext {
  FolioColors get colors => Theme.of(this).extension<FolioColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  Brightness get brightness => Theme.of(this).brightness;
}
