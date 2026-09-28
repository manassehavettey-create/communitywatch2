import 'package:flutter/widgets.dart';

/// Motion tokens (DESIGN.md → Motion). Always read durations through
/// [Motion.of] so the system "reduce motion" setting is respected.
abstract final class MotionTokens {
  static const instant = Duration(milliseconds: 90);
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 360);
  static const celebrate = Duration(milliseconds: 900);

  /// Delay between staggered items, and the most items that get a delay.
  static const stagger = Duration(milliseconds: 45);
  static const staggerCap = 8;

  /// Opacity-only fallback duration when motion is reduced.
  static const reducedFade = Duration(milliseconds: 120);

  static const standard = Cubic(0.2, 0, 0, 1);
  static const exit = Cubic(0.3, 0, 1, 1);

  static const spring = SpringDescription(mass: 1, stiffness: 420, damping: 34);
}

/// Motion resolved against the current accessibility settings.
class Motion {
  const Motion._(this.reduced);

  factory Motion.of(BuildContext context) =>
      Motion._(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  /// True when the platform asks for reduced motion.
  final bool reduced;

  Duration get instant => reduced ? Duration.zero : MotionTokens.instant;
  Duration get fast => reduced ? MotionTokens.reducedFade : MotionTokens.fast;
  Duration get base => reduced ? MotionTokens.reducedFade : MotionTokens.base;
  Duration get slow => reduced ? MotionTokens.reducedFade : MotionTokens.slow;
  Duration get celebrate =>
      reduced ? MotionTokens.reducedFade : MotionTokens.celebrate;

  Curve get standard => reduced ? Curves.linear : MotionTokens.standard;

  /// Stagger delay for item [index] in a list.
  Duration staggerFor(int index) => reduced
      ? Duration.zero
      : MotionTokens.stagger *
            (index < MotionTokens.staggerCap ? index : MotionTokens.staggerCap);

  /// Vertical travel for reveal animations.
  double get rise => reduced ? 0 : 16;
}
