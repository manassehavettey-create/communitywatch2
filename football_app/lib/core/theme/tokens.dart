import 'package:flutter/material.dart';

/// Design tokens for Touchline. See DESIGN.md for rationale.
///
/// Colors are exposed through [AppColors] (a [ThemeExtension]) so the dark and
/// light themes are designed independently rather than inverted.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.hairline,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.onAccent,
    required this.accentInk,
    required this.mint,
    required this.away,
    required this.live,
    required this.yellowCard,
    required this.redCard,
    required this.win,
    required this.draw,
    required this.loss,
    required this.reported,
    required this.predicted,
    required this.generated,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color hairline;
  final Color text;
  final Color textMuted;
  final Color textFaint;

  /// Signature lime. Used for fills (CTA, active nav, home team series).
  final Color accent;
  final Color onAccent;

  /// Accent used for text/icons on the background (readable in both themes).
  final Color accentInk;
  final Color mint;

  /// Second series color for head-to-head comparisons (away team).
  final Color away;
  final Color live;
  final Color yellowCard;
  final Color redCard;
  final Color win;
  final Color draw;
  final Color loss;

  /// Provenance colors: REPORTED / PREDICTED / APP-GENERATED labels.
  final Color reported;
  final Color predicted;
  final Color generated;
  final bool isDark;

  static const dark = AppColors(
    bg: Color(0xFF0A0C0B),
    surface: Color(0xFF131715),
    surface2: Color(0xFF1B201D),
    surface3: Color(0xFF252B27),
    hairline: Color(0xFF262D29),
    text: Color(0xFFF2F5F1),
    textMuted: Color(0xFF8E978F),
    textFaint: Color(0xFF5E6761),
    accent: Color(0xFFC6F432),
    onAccent: Color(0xFF0A0C0B),
    accentInk: Color(0xFFC6F432),
    mint: Color(0xFF3DDC84),
    away: Color(0xFF9D95FF),
    live: Color(0xFFFF4545),
    yellowCard: Color(0xFFFFD23F),
    redCard: Color(0xFFFF4D4D),
    win: Color(0xFF3DDC84),
    draw: Color(0xFF8E978F),
    loss: Color(0xFFFF5C5C),
    reported: Color(0xFFFFB547),
    predicted: Color(0xFF9D95FF),
    generated: Color(0xFF6FD6FF),
    isDark: true,
  );

  static const light = AppColors(
    bg: Color(0xFFF1F3EF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF4F6F2),
    surface3: Color(0xFFE7EBE5),
    hairline: Color(0xFFE2E6E0),
    text: Color(0xFF0B0E0C),
    textMuted: Color(0xFF5B635D),
    textFaint: Color(0xFF8D958F),
    accent: Color(0xFFC6F432),
    onAccent: Color(0xFF0A0C0B),
    accentInk: Color(0xFF4A7300),
    mint: Color(0xFF12A660),
    away: Color(0xFF5A50E6),
    live: Color(0xFFE5282B),
    yellowCard: Color(0xFFF2B600),
    redCard: Color(0xFFE5282B),
    win: Color(0xFF12A660),
    draw: Color(0xFF7B837D),
    loss: Color(0xFFE5392F),
    reported: Color(0xFFC77700),
    predicted: Color(0xFF5A50E6),
    generated: Color(0xFF0A86B8),
    isDark: false,
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      surface3: l(surface3, other.surface3),
      hairline: l(hairline, other.hairline),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      textFaint: l(textFaint, other.textFaint),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentInk: l(accentInk, other.accentInk),
      mint: l(mint, other.mint),
      away: l(away, other.away),
      live: l(live, other.live),
      yellowCard: l(yellowCard, other.yellowCard),
      redCard: l(redCard, other.redCard),
      win: l(win, other.win),
      draw: l(draw, other.draw),
      loss: l(loss, other.loss),
      reported: l(reported, other.reported),
      predicted: l(predicted, other.predicted),
      generated: l(generated, other.generated),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// 4pt spacing scale.
abstract final class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page gutter.
  static const double gutter = 20;
}

abstract final class Radii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Motion tokens. Short, springy, never decorative filler.
abstract final class Motion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration draw = Duration(milliseconds: 900);

  /// Material 3 "emphasized" — fast start, long gentle settle.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve decelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve spring = Cubic(0.34, 1.36, 0.64, 1.0);

  /// Stagger step for list entrances; capped so long lists never feel slow.
  static const Duration stagger = Duration(milliseconds: 35);
  static const int maxStaggered = 8;

  static Duration staggerFor(int index) =>
      stagger * (index < maxStaggered ? index : maxStaggered);
}

extension AppThemeX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  TextTheme get text => Theme.of(this).textTheme;

  /// True when the OS asks for reduced motion.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}
