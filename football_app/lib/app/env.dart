import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Run with: `flutter run --dart-define=API_FOOTBALL_KEY=your_key`
abstract final class Env {
  static const apiKey = String.fromEnvironment('API_FOOTBALL_KEY');
  static bool get hasKey => apiKey.isNotEmpty;

  /// Demo data exists only in debug builds; the constant lets the compiler
  /// tree-shake the toggle out of release builds.
  static const bool demoAllowed = kDebugMode;
}
