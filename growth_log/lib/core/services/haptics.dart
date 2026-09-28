import 'package:flutter/services.dart';

/// Haptic feedback that respects the user's setting.
class Haptics {
  const Haptics({required this.enabled});

  final bool enabled;

  void tap() {
    if (enabled) HapticFeedback.selectionClick();
  }

  void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  /// A short double pulse for celebrations.
  Future<void> success() async {
    if (!enabled) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.heavyImpact();
  }
}
