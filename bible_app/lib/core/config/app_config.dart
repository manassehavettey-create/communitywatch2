/// Build-time configuration, passed with
/// `flutter run --dart-define-from-file=env/config.json`.
///
/// env/config.json is gitignored; env/config.example.json documents the
/// keys. Nothing secret is hard-coded, and the app works fully offline
/// (without accounts or sync) when these are empty.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// OAuth client ids for native Google sign-in. The web client id is used
  /// as the server client id so Supabase can verify the ID token.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  /// Deep link Supabase redirects to after email confirmation, password
  /// reset and web OAuth.
  static const authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'app.scripture.bibleapp://auth-callback',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasGoogle => googleWebClientId.isNotEmpty;
}
