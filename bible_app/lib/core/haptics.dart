import 'package:flutter/services.dart';

/// Subtle haptics, used only for verse selection, highlighting and
/// completion moments.
abstract final class Haptics {
  static Future<void> select() => HapticFeedback.selectionClick();
  static Future<void> light() => HapticFeedback.lightImpact();
  static Future<void> success() => HapticFeedback.mediumImpact();
}
