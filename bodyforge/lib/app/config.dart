/// Build-time configuration. Values come from a gitignored JSON file passed as
/// `--dart-define-from-file=env/bodyforge.env.json` (see README). The anon key
/// is a public client key; the service-role key must never be used in the app.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Cloud sync / accounts are available only when both values are provided.
  /// Without them BODYFORGE runs fully offline on this device.
  static bool get cloudEnabled => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static const appVersion = '1.0.0';
}
