import 'package:flutter/material.dart';

/// Colour, spacing and shape tokens. Values mirror DESIGN.md; change them
/// there first.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.paper,
    required this.paperDeep,
    required this.surface,
    required this.ink,
    required this.inkSoft,
    required this.inkMute,
    required this.line,
    required this.tangerine,
    required this.tangerineText,
    required this.coral,
    required this.butter,
    required this.sage,
    required this.sky,
    required this.blush,
    required this.cream,
    required this.onPastel,
    required this.isDark,
  });

  final Color paper;
  final Color paperDeep;
  final Color surface;
  final Color ink;
  final Color inkSoft;
  final Color inkMute;
  final Color line;
  final Color tangerine;
  final Color tangerineText;
  final Color coral;
  final Color butter;
  final Color sage;
  final Color sky;
  final Color blush;
  final Color cream;

  /// Text colour on top of any pastel card (ink in both themes).
  final Color onPastel;
  final bool isDark;

  static const light = AppPalette(
    paper: Color(0xFFF6F0E6),
    paperDeep: Color(0xFFEDE5D6),
    surface: Color(0xFFFBF8F2),
    ink: Color(0xFF141414),
    inkSoft: Color(0xFF5E5A53),
    inkMute: Color(0xFF8F897E),
    line: Color(0xFFDCD5C8),
    tangerine: Color(0xFFF5620F),
    tangerineText: Color(0xFFB8470A),
    coral: Color(0xFFEF845D),
    butter: Color(0xFFF4D352),
    sage: Color(0xFFAAC385),
    sky: Color(0xFFA1BDDD),
    blush: Color(0xFFE9B4C8),
    cream: Color(0xFFF3E9CC),
    onPastel: Color(0xFF141414),
    isDark: false,
  );

  static const dark = AppPalette(
    paper: Color(0xFF121110),
    paperDeep: Color(0xFF1B1A18),
    surface: Color(0xFF211F1C),
    ink: Color(0xFFECE5D8),
    inkSoft: Color(0xFFB3AB9D),
    inkMute: Color(0xFF7C766C),
    line: Color(0xFF2E2B27),
    tangerine: Color(0xFFFF7A33),
    tangerineText: Color(0xFFFF8A4C),
    coral: Color(0xFFD9785A),
    butter: Color(0xFFD9BC4E),
    sage: Color(0xFF93AC74),
    sky: Color(0xFF8DA7C4),
    blush: Color(0xFFCE9DB0),
    cream: Color(0xFFCFC6AA),
    onPastel: Color(0xFF141414),
    isDark: true,
  );

  List<Color> get pastels => [coral, butter, sage, sky, blush, cream];

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      paper: l(paper, other.paper),
      paperDeep: l(paperDeep, other.paperDeep),
      surface: l(surface, other.surface),
      ink: l(ink, other.ink),
      inkSoft: l(inkSoft, other.inkSoft),
      inkMute: l(inkMute, other.inkMute),
      line: l(line, other.line),
      tangerine: l(tangerine, other.tangerine),
      tangerineText: l(tangerineText, other.tangerineText),
      coral: l(coral, other.coral),
      butter: l(butter, other.butter),
      sage: l(sage, other.sage),
      sky: l(sky, other.sky),
      blush: l(blush, other.blush),
      cream: l(cream, other.cream),
      onPastel: l(onPastel, other.onPastel),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

/// 4-point spacing scale.
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

  /// Room reserved under scrolling content for the floating tab bar.
  static const double tabBarClearance = 112;
}

abstract final class Radii {
  static const double xs = 8;
  static const double sm = 14;
  static const double md = 22;
  static const double lg = 30;
  static const double xl = 36;
  static const double pill = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// The single soft shadow used by floating elements in light mode.
List<BoxShadow> floatingShadow(AppPalette p) => p.isDark
    ? const []
    : const [
        BoxShadow(
          color: Color(0x2E141414),
          blurRadius: 32,
          offset: Offset(0, 12),
        ),
      ];

/// Highlight colours offered in the reader, in display order.
enum HighlightColor {
  butter,
  coral,
  sage,
  sky,
  blush;

  Color base(AppPalette p) => switch (this) {
    HighlightColor.butter => p.butter,
    HighlightColor.coral => p.coral,
    HighlightColor.sage => p.sage,
    HighlightColor.sky => p.sky,
    HighlightColor.blush => p.blush,
  };

  /// Fill painted behind highlighted text for the given reader background.
  Color fill(AppPalette p, {required bool darkBackground}) =>
      base(p).withValues(alpha: darkBackground ? 0.28 : 0.55);

  String get label => switch (this) {
    HighlightColor.butter => 'Butter',
    HighlightColor.coral => 'Coral',
    HighlightColor.sage => 'Sage',
    HighlightColor.sky => 'Sky',
    HighlightColor.blush => 'Blush',
  };

  static HighlightColor fromName(String name) => HighlightColor.values
      .firstWhere((c) => c.name == name, orElse: () => HighlightColor.butter);
}
