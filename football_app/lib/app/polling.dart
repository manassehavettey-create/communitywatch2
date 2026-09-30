import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/request_budget.dart';
import '../data/models/models.dart';

extension CacheForRef on Ref {
  /// Keep an auto-dispose provider alive for [d] after its last listener
  /// leaves, so tab switches and back navigation are instant.
  void cacheFor(Duration d) {
    final link = keepAlive();
    final timer = Timer(d, link.close);
    onDispose(timer.cancel);
  }
}

/// Emits [load] results, re-polling at the budget-aware live interval while
/// [shouldPoll] holds and someone is listening. Riverpod pauses listeners of
/// off-screen widgets, so hidden tabs stop polling automatically.
///
/// Network failures after the first success re-emit the last value flagged
/// `stale` (never fabricated) and keep retrying on the same schedule.
Stream<Fresh<T>> pollingStream<T>(
  Ref ref, {
  required Future<Fresh<T>> Function(bool force) load,
  required bool Function(T value) shouldPoll,
  required RequestBudget budget,
  Duration? fixedInterval,
  double Function(T value)? intervalMultiplier,
}) async* {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  Fresh<T>? last;
  var first = true;
  while (!disposed) {
    try {
      final v = await load(!first);
      last = v;
      if (disposed) return;
      yield v;
    } on DataException catch (e) {
      if (last == null) rethrow;
      if (disposed) return;
      yield Fresh(last.data, fetchedAt: last.fetchedAt, stale: true, provenance: last.provenance);
      if (e.kind == DataErrorKind.auth || e.kind == DataErrorKind.plan) return;
    }
    first = false;
    if (!shouldPoll(last.data)) return;

    // Wait for the next slot; if the budget is nearly exhausted, pause until
    // it recovers (quota resets at 00:00 UTC).
    while (!disposed) {
      final base = fixedInterval ?? budget.liveInterval();
      if (base != null) {
        final mult = intervalMultiplier?.call(last.data) ?? 1;
        await Future<void>.delayed(base * mult);
        break;
      }
      await Future<void>.delayed(const Duration(minutes: 1));
    }
  }
}
