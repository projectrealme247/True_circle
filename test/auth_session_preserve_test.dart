import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:true_circle/services/auth_service.dart';
import 'package:true_circle/services/user_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR0cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
      );
    }
  });

  setUp(() {
    UserSessionStore.current = null;
  });

  group('AuthService.shouldPreserveLocalSession', () {
    test('preserves demo_mode sessions', () {
      expect(
        AuthService.shouldPreserveLocalSession({
          'demo_mode': true,
          'supabase_user_id': 'demo-seeker-uuid',
          'email': 'demo.seeker@truecircle.dev',
        }),
        isTrue,
      );
    });

    test('preserves local identity without demo_mode', () {
      expect(
        AuthService.shouldPreserveLocalSession({
          'email': 'real.user@example.com',
          'supabase_user_id': 'user-1',
        }),
        isTrue,
      );
    });

    test('does not preserve empty or missing sessions', () {
      expect(AuthService.shouldPreserveLocalSession(null), isFalse);
      expect(AuthService.shouldPreserveLocalSession({}), isFalse);
    });
  });

  test('bootstrap without Supabase does not clear in-memory demo session',
      () async {
    SharedPreferences.setMockInitialValues({});
    UserSessionStore.current = {
      'demo_mode': true,
      'email': 'demo.seeker@truecircle.dev',
      'supabase_user_id': 'demo-seeker-uuid',
      'role': 'seeker',
    };

    await AuthService.bootstrap();

    expect(UserSessionStore.current?['demo_mode'], isTrue);
    expect(UserSessionStore.current?['email'], 'demo.seeker@truecircle.dev');
    expect(AuthService.isSignedIn(UserSessionStore.current), isTrue);
  });
}
