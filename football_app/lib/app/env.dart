import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Run with: `flutter run --dart-define=API_FOOTBALL_KEY=your_key`
abstract final class Env {
  static const apiKey = String.fromEnvironment('API_FOOTBALL_KEY');
  static bool get hasKey => apiKey.isNotEmpty;

  /// Demo data exists only in debug builds, or in preview APKs explicitly
  /// built with --dart-define=ALLOW_DEMO=true (clearly badged DEMO). The
  /// constant lets the compiler tree-shake demo code out of normal releases.
  static const bool demoAllowed = kDebugMode || bool.fromEnvironment('ALLOW_DEMO');
}
