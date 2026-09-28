import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../db/database.dart';
import 'remote_store.dart';
import 'sync_engine.dart';

enum SyncPhase { localOnly, offline, idle, syncing, error }

class SyncStatus {
  const SyncStatus(this.phase, {this.lastSynced, this.pending = 0, this.error});

  final SyncPhase phase;
  final DateTime? lastSynced;
  final int pending;
  final String? error;

  SyncStatus copyWith({
    SyncPhase? phase,
    DateTime? lastSynced,
    int? pending,
    String? error,
  }) => SyncStatus(
    phase ?? this.phase,
    lastSynced: lastSynced ?? this.lastSynced,
    pending: pending ?? this.pending,
    error: error,
  );
}

/// Decides when to sync: after local changes (debounced), when the
/// connection returns, when the app resumes, and every few minutes, with
/// exponential back-off after failures.
class SyncService with WidgetsBindingObserver {
  SyncService(this.db, {Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final AppDatabase db;
  final Connectivity _connectivity;

  final _status = StreamController<SyncStatus>.broadcast();
  SyncStatus _current = const SyncStatus(SyncPhase.localOnly);

  RemoteStore? _remote;
  String? _userId;
  bool _online = true;
  bool _running = false;
  bool _again = false;
  int _failures = 0;
  Timer? _debounce;
  Timer? _periodic;
  Timer? _retry;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<int>? _outboxSub;

  SyncStatus get status => _current;
  Stream<SyncStatus> get statusChanges => _status.stream;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _connSub = _connectivity.onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      if (online && !_online) {
        _online = true;
        schedule(immediate: true);
      } else if (!online) {
        _online = false;
        _emit(_current.copyWith(phase: _phaseWhenIdle()));
      }
    });
    _outboxSub = db
        .customSelect(
          'SELECT COUNT(*) AS n FROM outbox',
          readsFrom: {db.outbox},
        )
        .watchSingle()
        .map((r) => r.read<int>('n'))
        .listen((n) {
          _emit(_current.copyWith(pending: n));
          if (n > 0) schedule();
        });
    _periodic = Timer.periodic(const Duration(minutes: 5), (_) => schedule());
  }

  /// Called when the signed-in user changes.
  void setAccount({required String? userId, required RemoteStore? remote}) {
    _userId = userId;
    _remote = remote;
    _failures = 0;
    _emit(_current.copyWith(phase: _phaseWhenIdle()));
    if (userId != null) schedule(immediate: true);
  }

  SyncPhase _phaseWhenIdle() {
    if (_remote == null || _userId == null) return SyncPhase.localOnly;
    return _online ? SyncPhase.idle : SyncPhase.offline;
  }

  void schedule({bool immediate = false}) {
    if (_remote == null || _userId == null || !_online) return;
    _debounce?.cancel();
    _debounce = Timer(
      immediate ? Duration.zero : const Duration(seconds: 3),
      syncNow,
    );
  }

  Future<void> syncNow() async {
    final remote = _remote, user = _userId;
    if (remote == null || user == null || !_online) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _retry?.cancel();
    _emit(_current.copyWith(phase: SyncPhase.syncing));
    try {
      await SyncEngine(db, remote, userId: user).sync();
      _failures = 0;
      _emit(
        _current.copyWith(phase: SyncPhase.idle, lastSynced: DateTime.now()),
      );
    } catch (e) {
      _failures++;
      _emit(_current.copyWith(phase: SyncPhase.error, error: e.toString()));
      final wait = Duration(
        seconds: math.min(300, 5 * math.pow(2, _failures - 1).toInt()),
      );
      _retry = Timer(wait, syncNow);
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        schedule();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) schedule(immediate: true);
  }

  void _emit(SyncStatus s) {
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _periodic?.cancel();
    _retry?.cancel();
    await _connSub?.cancel();
    await _outboxSub?.cancel();
    await _status.close();
  }
}
