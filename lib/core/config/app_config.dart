/// App-wide runtime configuration.
///
/// Supabase is OPTIONAL. The app runs fully offline (local-first with Hive).
/// To enable hybrid/online mode, run with:
///   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
///
/// NOTE: the `sbp_...` personal access token is for the Supabase Management
/// API only — the app needs the project's URL + anon key (see
/// docs/SUPABASE_SETUP.md). Never commit real secrets; use --dart-define.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get supabaseEnabled =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Future google_mobile_ads integration flag (see docs/ADS_AND_ONLINE_ROADMAP.md).
  static const bool adsEnabled = bool.fromEnvironment(
    'ADS_ENABLED',
    defaultValue: false,
  );

  static const String appName = 'Chess Arena';
  static const int startingRating = 1200;
  static const int startingCoins = 550;
}
