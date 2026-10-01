/// Supabase client configuration, injected at build time via --dart-define.
///
/// Run the app with:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// NEVER put real values here. Only public client config (anon key) belongs
/// in the app. Service-role keys and JWT secrets must stay server-side.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
