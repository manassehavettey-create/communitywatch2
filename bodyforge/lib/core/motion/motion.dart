import 'package:flutter/widgets.dart';

/// The single source of truth for motion. Every animated widget reads its
/// durations, curves and stagger from here, and asks [Motion.of] whether the
/// user has requested reduced motion.
abstract final class Motion {
  // Durations.
  static const instant = Duration(milliseconds: 90);
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 460);
  static const slower = Duration(milliseconds: 720);
  static const hero = Duration(milliseconds: 520);
  static const countUp = Duration(milliseconds: 1100);
  static const chartDraw = Duration(milliseconds: 900);
  static const celebration = Duration(milliseconds: 1800);

  // Curves.
  static const standard = Curves.easeOutCubic;
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const decelerate = Curves.easeOutQuart;
  static const exit = Curves.easeInCubic;
  static const spring = Curves.easeOutBack;
  static const gentleSpring = Cubic(0.34, 1.36, 0.64, 1.0);

  // Stagger.
  static const staggerStep = Duration(milliseconds: 55);
  static const staggerMaxItems = 8;

  /// Delay for the nth item in a staggered list, capped so long lists don't
  /// take forever to settle.
  static Duration stagger(int index, {Duration base = Duration.zero}) =>
      base + staggerStep * (index.clamp(0, staggerMaxItems));

  // Standard offsets for enter animations (in logical px / fractions).
  static const enterSlide = 0.06; // fraction of child height for slideY
  static const pressScale = 0.96;

  /// True when the OS "reduce motion" / "remove animations" setting is on.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Returns [d] or zero when motion is reduced.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}
