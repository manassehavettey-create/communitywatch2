import 'package:flutter/widgets.dart';

/// Raw design tokens extracted from the UI references (see DESIGN.md).
/// Widgets should read colours through [BfColors] (theme-aware), and use these
/// spacing / radius constants directly.
abstract final class BfPalette {
  // Brand accents (identical in both themes, slightly deepened in light).
  static const lime = Color(0xFFD4F55A);
  static const limeDeep = Color(0xFFC6EA3E);
  static const lavender = Color(0xFFA99BF7);
  static const lavenderDeep = Color(0xFF9C8CF2);
  static const lilac = Color(0xFFE3B8F5);
  static const lilacSoft = Color(0xFFF0D4FA);
  static const ember = Color(0xFFFF9A3C);
  static const emberDeep = Color(0xFFF5892A);

  // Neutrals.
  static const ink = Color(0xFF111113);
  static const canvasDark = Color(0xFF141416);
  static const surfaceDark = Color(0xFF1F1F23);
  static const surfaceRaisedDark = Color(0xFF2A2A30);
  static const outlineDark = Color(0xFF3A3A42);
  static const canvasLight = Color(0xFFF3F3F0);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceRaisedLight = Color(0xFFEDEDE8);
  static const outlineLight = Color(0xFFDCDCD5);
  static const paper = Color(0xFFF7F7F2);

  // Category pastels (light theme tints, also used for nutrition/recovery).
  static const sky = Color(0xFFBFE3F0);
  static const mint = Color(0xFFCFE8B8);
  static const peach = Color(0xFFF7CBA9);
  static const coral = Color(0xFFF4A39A);
  static const butter = Color(0xFFF6DE82);

  // Semantic.
  static const success = Color(0xFF7FE3A0);
  static const warning = Color(0xFFFFC857);
  static const danger = Color(0xFFFF6B6B);
}

/// 4-pt spacing scale.
abstract final class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Horizontal page gutter.
  static const double gutter = 20;
}

abstract final class Radii {
  static const double sm = 12;
  static const double md = 20;
  static const double lg = 28;
  static const double xl = 32;
  static const double pill = 999;

  static const card = BorderRadius.all(Radius.circular(lg));
  static const cardLarge = BorderRadius.all(Radius.circular(xl));
  static const tile = BorderRadius.all(Radius.circular(md));
  static const small = BorderRadius.all(Radius.circular(sm));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}

abstract final class Sizes {
  static const double iconButton = 48;
  static const double iconButtonLarge = 56;
  static const double navHeight = 72;
  static const double minTap = 44;
}
