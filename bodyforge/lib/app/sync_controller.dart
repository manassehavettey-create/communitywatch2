import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../data/sync/remote_store.dart';
import '../data/sync/supabase_remote_store.dart';
import '../data/sync/sync_engine.dart';
import 'auth.dart';
import 'config.dart';
import 'providers.dart';
import 'settings.dart';

/// Drives background sync: on reconnect, on app resume, shortly after local
/// changes, and every few minutes while open. Exposes status for the UI badge.
class SyncController extends Notifier<SyncStatus> {
  StreamSubscription<List<ConnectivityResult>>? _conn;
  StreamSubscription<int>? _pending;
  Timer? _debounce;
  Timer? _periodic;
  AppLifecycleListener? _life;
  SyncEngine? _engine;

  @override
  SyncStatus build() {
    final auth = ref.watch(authProvider);
    _dispose();
    ref.onDispose(_dispose);
    if (!auth.isCloud || !AppConfig.cloudEnabled) {
      return const SyncStatus(SyncPhase.localOnly);
    }
    final db = ref.read(databaseProvider);
    _engine = SyncEngine(db, SupabaseRemoteStore(Supabase.instance.client));

    _conn = Connectivity().onConnectivityChanged.listen((r) {
      final online = r.any((x) => x != ConnectivityResult.none);
      if (online) {
        syncNow();
      } else {
        state = state.copyWith(phase: SyncPhase.offline);
      }
    });
    _pending = db.watchPendingChanges().listen((n) {
      state = state.copyWith(pending: n, phase: state.phase);
      if (n > 0) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 4), syncNow);
      }
    });
    _periodic = Timer.periodic(const Duration(minutes: 5), (_) => syncNow());
    _life = AppLifecycleListener(onResume: syncNow);
    Future.microtask(syncNow);
    return const SyncStatus(SyncPhase.idle);
  }

  void _dispose() {
    _conn?.cancel();
    _pending?.cancel();
    _debounce?.cancel();
    _periodic?.cancel();
    _life?.dispose();
  }

  Future<void> syncNow() async {
    final engine = _engine;
    final uid = ref.read(authProvider).userId;
    if (engine == null || uid == null) return;
    final conn = await Connectivity().checkConnectivity();
    if (conn.every((c) => c == ConnectivityResult.none)) {
      state = state.copyWith(phase: SyncPhase.offline);
      return;
    }
    state = state.copyWith(phase: SyncPhase.syncing);
    try {
      await engine.sync(uid);
      final pending = await ref.read(databaseProvider).pendingChanges();
      state = SyncStatus(SyncPhase.synced, pending: pending, lastSynced: DateTime.now());
      _recordDevice(uid, pending);
    } on RemoteUnavailable {
      state = state.copyWith(phase: SyncPhase.offline);
    } catch (e) {
      debugPrint('Sync error: $e');
      state = state.copyWith(phase: SyncPhase.error, message: 'Sync paused — will retry');
    }
  }

  Future<void> _recordDevice(String uid, int pending) async {
    try {
      final install = ref.read(settingsProvider).installId;
      await Supabase.instance.client.from('sync_metadata').upsert({
        'id': '$uid:$install',
        'user_id': uid,
        'app_version': AppConfig.appVersion,
        'last_synced_at': DateTime.now().toUtc().toIso8601String(),
        'pending_changes': pending,
      });
    } catch (_) {
      // Best effort only.
    }
  }
}

final syncProvider = NotifierProvider<SyncController, SyncStatus>(SyncController.new);
