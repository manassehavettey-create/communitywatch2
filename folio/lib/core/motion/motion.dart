import 'package:flutter/widgets.dart';

/// Motion tokens. Every animated widget goes through [Motion.of] so the
/// system "reduce motion" setting collapses animations to instant changes.
class Motion {
  const Motion._(this.reduced);

  final bool reduced;

  static Motion of(BuildContext context) => Motion._(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  static const Duration _fast = Duration(milliseconds: 160);
  static const Duration _base = Duration(milliseconds: 240);
  static const Duration _slow = Duration(milliseconds: 360);
  static const Duration _stagger = Duration(milliseconds: 30);

  Duration get fast => reduced ? Duration.zero : _fast;
  Duration get base => reduced ? Duration.zero : _base;
  Duration get slow => reduced ? Duration.zero : _slow;

  /// Entrance delay for the [index]th item in a list (capped at 8 items).
  Duration stagger(int index) => reduced ? Duration.zero : _stagger * (index.clamp(0, 8));

  static const Curve curve = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
}
