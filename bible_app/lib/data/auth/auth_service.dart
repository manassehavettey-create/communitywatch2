import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

class AppUser {
  const AppUser({required this.id, this.email, this.displayName});

  final String id;
  final String? email;
  final String? displayName;
}

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Email/password and Google sign-in through Supabase Auth. When Supabase
/// isn't configured the app runs local-only and [available] is false.
class AuthService {
  AuthService._(this._client);

  /// Initialises Supabase if configured. Safe to call once at start-up.
  static Future<AuthService> create() async {
    if (!AppConfig.hasSupabase) return AuthService._(null);
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
    return AuthService._(Supabase.instance.client);
  }

  /// For tests and local-only builds.
  factory AuthService.disabled() => AuthService._(null);

  final SupabaseClient? _client;

  bool get available => _client != null;

  SupabaseClient? get client => _client;

  AppUser? get currentUser => _toUser(_client?.auth.currentUser);

  Stream<AppUser?> get userChanges {
    final c = _client;
    if (c == null) return Stream.value(null);
    return c.auth.onAuthStateChange
        .map((s) => _toUser(s.session?.user))
        .distinct((a, b) => a?.id == b?.id);
  }

  static AppUser? _toUser(User? u) => u == null
      ? null
      : AppUser(
          id: u.id,
          email: u.email,
          displayName:
              (u.userMetadata?['full_name'] ?? u.userMetadata?['name'])
                  as String?,
        );

  SupabaseClient _require() {
    final c = _client;
    if (c == null) {
      throw AuthFailure('Accounts are not set up in this build.');
    }
    return c;
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _require().auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  /// Returns true when the account still needs its email confirmed.
  Future<bool> signUpWithEmail(
    String email,
    String password, {
    String? name,
  }) async {
    try {
      final res = await _require().auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: kIsWeb ? null : AppConfig.authRedirectUrl,
        data: {
          if (name != null && name.trim().isNotEmpty) 'full_name': name.trim(),
        },
      );
      return res.session == null;
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _require().auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? null : AppConfig.authRedirectUrl,
      );
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  bool _googleReady = false;

  Future<void> signInWithGoogle() async {
    final client = _require();
    if (kIsWeb) {
      await client.auth.signInWithOAuth(OAuthProvider.google);
      return;
    }
    if (!AppConfig.hasGoogle) {
      throw AuthFailure('Google sign-in is not set up in this build.');
    }
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(
        clientId:
            defaultTargetPlatform == TargetPlatform.iOS &&
                AppConfig.googleIosClientId.isNotEmpty
            ? AppConfig.googleIosClientId
            : null,
        serverClientId: AppConfig.googleWebClientId,
      );
      _googleReady = true;
    }
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw AuthFailure('Sign-in was cancelled.');
      }
      throw AuthFailure('Google sign-in failed. Please try again.');
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw AuthFailure('Google did not return an identity token.');
    }
    try {
      await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  Future<void> signOut() async {
    final c = _client;
    if (c == null) return;
    await c.auth.signOut();
    if (!kIsWeb && _googleReady) await GoogleSignIn.instance.signOut();
  }

  static String _friendly(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) {
      return 'That email and password don’t match.';
    }
    if (m.contains('already registered')) {
      return 'There’s already an account with that email. Try signing in.';
    }
    if (m.contains('email not confirmed')) {
      return 'Please confirm your email first — check your inbox.';
    }
    if (m.contains('password')) return e.message;
    if (m.contains('network') || m.contains('socket')) {
      return 'You’re offline. Try again when you’re connected.';
    }
    return e.message;
  }
}
