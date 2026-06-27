abstract final class AppEnv {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const demoAuthBypass = bool.fromEnvironment(
    'DEMO_AUTH_BYPASS',
    defaultValue: false,
  );
  static const demoMockHarness = bool.fromEnvironment(
    'DEMO_MOCK_HARNESS',
    defaultValue: false,
  );
}
