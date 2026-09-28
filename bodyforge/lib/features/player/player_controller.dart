import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../domain/catalog/exercises.dart';
import '../../domain/engine/player.dart';
import '../../domain/models/workout.dart';

/// A plan waiting on the preview screen before it's started.
class PendingSession extends Notifier<WorkoutPlan?> {
  @override
  WorkoutPlan? build() => null;
  void set(WorkoutPlan plan) => state = plan;
  void clear() => state = null;
}

final pendingSessionProvider = NotifierProvider<PendingSession, WorkoutPlan?>(PendingSession.new);

/// Runs the guided workout. Every transition is persisted, so the session
/// (and its timers, which are derived from timestamps) survives the app being
/// backgrounded or killed.
class PlayerController extends Notifier<PlayerSnapshot?> {
  Timer? _ticker;
  AppLifecycleListener? _life;
  bool _loaded = false;

  @override
  PlayerSnapshot? build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _life?.dispose();
    });
    _life = AppLifecycleListener(
      onPause: _onBackground,
      onHide: _onBackground,
      onResume: _onForeground,
    );
    return null;
  }

  DateTime get _now => ref.read(clockProvider).now();

  /// Load a running session from disk (after a restart).
  Future<PlayerSnapshot?> load() async {
    if (_loaded && state != null) return state;
    _loaded = true;
    final s = await ref.read(trainingRepoProvider).getActiveSession();
    if (s != null) {
      state = s.catchUp(_now);
      await _persist();
      _startTicker();
    }
    return state;
  }

  Future<void> start(WorkoutPlan plan, {String? recoveryCheckId}) async {
    final snap = PlayerSnapshot.start(const Uuid().v4(), plan, _now);
    state = snap;
    _loaded = true;
    recoveryId = recoveryCheckId;
    await _persist();
    _startTicker();
  }

  /// Recovery check linked to this session (if one was done today).
  String? recoveryId;

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _tick() {
    final s = state;
    if (s == null || s.isPaused || s.isFinished) return;
    final next = s.catchUp(_now);
    if (next.stepIndex != s.stepIndex) {
      final step = next.current;
      if (step != null && step.isWork) {
        Haptics.heavy();
      } else {
        Haptics.medium();
      }
      state = next;
      _persist();
    }
  }

  Future<void> _persist() async {
    final s = state;
    if (s == null) return;
    await ref.read(trainingRepoProvider).saveActiveSession(s);
  }

  Future<void> _update(PlayerSnapshot Function(PlayerSnapshot s, DateTime now) f) async {
    final s = state;
    if (s == null) return;
    state = f(s, _now);
    await _persist();
    await ref.read(notificationsProvider).cancelRestEnd();
  }

  Future<void> completeWork(int achieved) => _update((s, n) => s.completeWork(achieved, n));
  Future<void> skip() => _update((s, n) => s.skip(n));
  Future<void> skipExercise() => _update((s, n) => s.skipExercise(n));
  Future<void> pause() => _update((s, n) => s.pause(n));
  Future<void> resume() => _update((s, n) => s.resume(n));
  Future<void> extendRest(int seconds) => _update((s, n) => s.extendRest(seconds, n));
  Future<void> finishEarly() => _update((s, n) => s.finishEarly(n));

  Future<void> swap(String exerciseId) async {
    final params = ref.read(paramsProvider);
    if (params == null) return;
    await _update((s, _) => s.swap(exerciseId, params));
  }

  /// Throw the session away without saving.
  Future<void> discard() async {
    _ticker?.cancel();
    state = null;
    await ref.read(trainingRepoProvider).clearActiveSession();
    await ref.read(notificationsProvider).cancelRestEnd();
  }

  /// Called after the completion flow has saved the workout.
  void clear() {
    _ticker?.cancel();
    state = null;
    _loaded = false;
  }

  Future<void> _onBackground() async {
    final s = state;
    if (s == null || s.isFinished || !ref.read(settingsProvider).restAlerts) return;
    await _persist();
    final ends = s.currentStepEndsAt(_now);
    final step = s.current;
    if (ends != null && step != null && step.isRest) {
      final next = step.nextExerciseId == null ? 'next set' : exerciseById(step.nextExerciseId!).name;
      await ref.read(notificationsProvider).scheduleRestEnd(ends, next);
    }
  }

  Future<void> _onForeground() async {
    await ref.read(notificationsProvider).cancelRestEnd();
    _tick();
  }
}

final playerProvider = NotifierProvider<PlayerController, PlayerSnapshot?>(PlayerController.new);
