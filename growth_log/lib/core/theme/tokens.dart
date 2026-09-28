import 'package:flutter/material.dart';

/// Raw palette extracted from the UI references. See DESIGN.md.
abstract final class Palette {
  static const lime = Color(0xFFC8EC64);
  static const limeSoft = Color(0xFFEBFBD2);
  static const limeDeep = Color(0xFF9CC23A);
  static const ink = Color(0xFF0E101C);
  static const inkCard = Color(0xFF1B2121);
  static const canvas = Color(0xFFF5F5F2);
  static const cream = Color(0xFFFAF3E6);
  static const white = Color(0xFFFFFFFF);
  static const hairline = Color(0xFFE6E6E6);
  static const muted = Color(0xFF6B6D76);

  static const lavender = Color(0xFFB6A3FF);
  static const butter = Color(0xFFF4DD7D);
  static const apricot = Color(0xFFF7CC7E);
  static const sky = Color(0xFFBCC9EC);
  static const blush = Color(0xFFF2B1DC);
  static const sage = Color(0xFFAEBE91);
  static const electric = Color(0xFF012AFE);
  static const berry = Color(0xFFB5307A);
  static const danger = Color(0xFFD9404A);

  // Dark mode surfaces.
  static const darkCanvas = Color(0xFF0B0C10);
  static const darkSurface = Color(0xFF16181D);
  static const darkCard = Color(0xFF1F2127);
  static const darkHairline = Color(0xFF2A2D35);
  static const darkMuted = Color(0xFF9A9CA6);

  /// Colours a user can pick for a skill. Text on these is always [ink].
  static const skillColors = <Color>[
    lime,
    lavender,
    butter,
    apricot,
    sky,
    blush,
    sage,
    Color(0xFF9FE2D0), // mint, same lightness family
  ];
}

abstract final class Space {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  /// Horizontal screen gutter.
  static const gutter = 20.0;

  /// Space reserved at the bottom of tab screens for the floating dock.
  static const dockClearance = 120.0;
}

abstract final class Radii {
  static const sm = 14.0;
  static const card = 28.0;
  static const cardSmall = 20.0;
  static const hero = 32.0;
  static const dock = 36.0;
  static const pill = 999.0;

  static const cardR = BorderRadius.all(Radius.circular(card));
  static const cardSmallR = BorderRadius.all(Radius.circular(cardSmall));
  static const heroR = BorderRadius.all(Radius.circular(hero));
  static const pillR = BorderRadius.all(Radius.circular(pill));
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 520);
  static const spring = Curves.easeOutBack;
  static const standard = Curves.easeOutCubic;
}

abstract final class Shadows {
  static const dock = [
    BoxShadow(color: Color(0x2E000000), offset: Offset(0, 12), blurRadius: 24),
  ];
}
