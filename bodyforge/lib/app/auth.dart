import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:uuid/uuid.dart';

import '../data/sync/remote_store.dart';
import '../data/sync/supabase_remote_store.dart';
import 'config.dart';
import 'providers.dart';
import 'settings.dart';

enum AuthMode { signedOut, local, cloud }

@immutable
class AuthState {
  const AuthState(this.mode, {this.userId, this.email, this.awaitingConfirmation});

  final AuthMode mode;

  /// Local-only uuid, or the Supabase user id.
  final String? userId;
  final String? email;

  /// Sign-up succeeded but the email must be confirmed before signing in.
  final String? awaitingConfirmation;

  bool get isSignedIn => userId != null;
  bool get isCloud => mode == AuthMode.cloud;
}

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Accounts. BODYFORGE always works offline: a user can start with a local
/// profile and create an account later — their data is re-keyed and uploaded.
class AuthController extends Notifier<AuthState> {
  static const _localKey = 'bf.auth.localUserId';
  StreamSubscription<dynamic>? _sub;

  SupabaseClient? get _client => AppConfig.cloudEnabled ? Supabase.instance.client : null;

  @override
  AuthState build() {
    ref.onDispose(() => _sub?.cancel());
    final client = _client;
    if (client != null) {
      _sub = client.auth.onAuthStateChange.listen((event) {
        final session = event.session;
        if (event.event == AuthChangeEvent.signedOut && state.isCloud) {
          state = const AuthState(AuthMode.signedOut);
        } else if (session != null && state.userId != session.user.id && state.mode != AuthMode.local) {
          state = AuthState(AuthMode.cloud, userId: session.user.id, email: session.user.email);
        }
      });
      final session = client.auth.currentSession;
      if (session != null) {
        return AuthState(AuthMode.cloud, userId: session.user.id, email: session.user.email);
      }
    }
    final local = ref.read(sharedPrefsProvider).getString(_localKey);
    if (local != null) return AuthState(AuthMode.local, userId: local);
    return const AuthState(AuthMode.signedOut);
  }

  /// Start without an account; everything stays on this phone.
  Future<void> continueOffline() async {
    final id = const Uuid().v4();
    await ref.read(sharedPrefsProvider).setString(_localKey, id);
    state = AuthState(AuthMode.local, userId: id);
  }

  String _friendly(Object e) {
    if (e is AuthException) {
      final m = e.message.toLowerCase();
      if (m.contains('invalid login')) return 'That email and password don\'t match.';
      if (m.contains('already registered')) return 'An account with this email already exists. Try logging in.';
      if (m.contains('email not confirmed')) return 'Please confirm your email first — check your inbox.';
      if (m.contains('password')) return e.message;
      return e.message;
    }
    if (e is TimeoutException || e.toString().contains('SocketException') || e.toString().contains('ClientException')) {
      return 'No internet connection. You can keep training offline and create your account later.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> signUp(String email, String password) async {
    final client = _client;
    if (client == null) throw AuthFailure('Cloud accounts aren\'t configured in this build.');
    try {
      final res = await client.auth.signUp(email: email.trim(), password: password).timeout(const Duration(seconds: 25));
      final user = res.user;
      if (res.session != null && user != null) {
        await _adopt(user.id, user.email);
      } else {
        state = AuthState(state.mode, userId: state.userId, awaitingConfirmation: email.trim());
      }
    } catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  Future<void> signIn(String email, String password) async {
    final client = _client;
    if (client == null) throw AuthFailure('Cloud accounts aren\'t configured in this build.');
    try {
      final res = await client.auth
          .signInWithPassword(email: email.trim(), password: password)
          .timeout(const Duration(seconds: 25));
      final user = res.user;
      if (user == null) throw AuthFailure('Sign-in failed.');
      await _adopt(user.id, user.email);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw AuthFailure(_friendly(e));
    }
  }

  Future<void> resetPassword(String email) async {
    final client = _client;
    if (client == null) throw AuthFailure('Cloud accounts aren\'t configured in this build.');
    try {
      await client.auth.resetPasswordForEmail(email.trim()).timeout(const Duration(seconds: 25));
    } catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  /// Move a local-only profile onto the cloud account, then sync.
  Future<void> _adopt(String cloudId, String? email) async {
    final prefs = ref.read(sharedPrefsProvider);
    final local = prefs.getString(_localKey);
    final db = ref.read(databaseProvider);
    if (local != null && local != cloudId) {
      await db.rekeyUser(local, cloudId);
    }
    await prefs.remove(_localKey);
    state = AuthState(AuthMode.cloud, userId: cloudId, email: email);
  }

  /// Signs out and removes this device's copy of the data. Callers should
  /// warn first if [AppDatabase.pendingChanges] is non-zero.
  Future<void> signOut() async {
    final db = ref.read(databaseProvider);
    await ref.read(notificationsProvider).cancelTrainingReminders();
    await db.wipe();
    await ref.read(sharedPrefsProvider).remove(_localKey);
    try {
      await _client?.auth.signOut();
    } catch (_) {
      // Offline sign-out still clears the local session.
    }
    state = const AuthState(AuthMode.signedOut);
  }

  /// Permanently delete the account and every row of data (server + device).
  Future<void> deleteAccount() async {
    final client = _client;
    if (state.isCloud && client != null) {
      try {
        await SupabaseRemoteStore(client).deleteMyAccount();
      } on RemoteUnavailable {
        throw AuthFailure('You need an internet connection to delete your account from the server.');
      } catch (e) {
        throw AuthFailure(_friendly(e));
      }
    }
    await signOut();
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
