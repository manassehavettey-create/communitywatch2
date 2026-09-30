import 'package:flutter/foundation.dart';

/// Tracks the provider's request quota from response headers and decides how
/// often live data may be polled. Protects the API-Football free tier
/// (100 requests/day) from being drained by polling.
class RequestBudget extends ChangeNotifier {
  RequestBudget({this.dailyLimit, this.remaining, this.minuteRemaining, DateTime? updatedAt}) : updatedAt = updatedAt ?? DateTime.now();

  int? dailyLimit;
  int? remaining;
  int? minuteRemaining;
  DateTime updatedAt;

  /// User preference: "battery/data saver" doubles intervals.
  bool saver = false;

  void update({int? dailyLimit, int? remaining, int? minuteRemaining}) {
    this.dailyLimit = dailyLimit ?? this.dailyLimit;
    this.remaining = remaining ?? this.remaining;
    this.minuteRemaining = minuteRemaining ?? this.minuteRemaining;
    updatedAt = DateTime.now();
    notifyListeners();
  }

  void markExhausted() {
    remaining = 0;
    updatedAt = DateTime.now();
    notifyListeners();
  }

  /// Quota resets at 00:00 UTC; treat an old reading as unknown.
  int? get effectiveRemaining {
    final now = DateTime.now().toUtc();
    final u = updatedAt.toUtc();
    if (now.year != u.year || now.month != u.month || now.day != u.day) return null;
    return remaining;
  }

  bool get exhausted => effectiveRemaining == 0;

  /// Live polling interval, or null when polling must pause to keep a
  /// reserve for user-initiated screens.
  Duration? liveInterval() {
    final r = effectiveRemaining;
    Duration d;
    if (r == null || r > 5000) {
      d = const Duration(seconds: 20);
    } else if (r > 1000) {
      d = const Duration(seconds: 30);
    } else if (r > 200) {
      d = const Duration(seconds: 60);
    } else if (r > 60) {
      d = const Duration(seconds: 120);
    } else if (r > 20) {
      d = const Duration(minutes: 5);
    } else {
      return null;
    }
    return saver ? d * 2 : d;
  }

  bool get livePaused => liveInterval() == null;
}
