import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/services/demo_auth_service.dart';

void main() {
  group('DemoAuthService.mergeDemoSeekerSession', () {
    test('fresh entry uses clean defaults', () {
      final merged = DemoAuthService.mergeDemoSeekerSession(null);

      expect(merged['email'], DemoAuthService.demoSeekerEmail);
      expect(merged['mother_tongue'], 'English');
      expect(merged['spoken_languages'], ['English']);
      expect(merged['budget_max'], 2500);
      expect(merged['commute_destination_hub_id'], 'tcd');
      expect(merged['demo_mode'], isTrue);
      expect(merged.containsKey('food_preference'), isFalse);
    });

    test('does not merge stale non-demo session', () {
      final merged = DemoAuthService.mergeDemoSeekerSession({
        'email': 'real.user@example.com',
        'spoken_languages': ['Hindi', 'Tamil'],
        'budget_max': 2000,
      });

      expect(merged['spoken_languages'], ['English']);
      expect(merged['budget_max'], 2500);
    });

    test('does not merge demo landlord session into seeker', () {
      final merged = DemoAuthService.mergeDemoSeekerSession({
        'demo_mode': true,
        'email': 'demo.landlord@truecircle.dev',
        'role': 'host',
        'spoken_languages': ['Hindi'],
        'budget_max': 9999,
      });

      expect(merged['spoken_languages'], ['English']);
      expect(merged['budget_max'], 2500);
      expect(merged['role'], 'seeker');
    });

    test('demoSeekerDefaults omits food_preference', () {
      final defaults = DemoAuthService.demoSeekerDefaults();
      expect(defaults.containsKey('food_preference'), isFalse);
    });

    test('re-entry preserves onboarding answers for same demo seeker', () {
      final prior = {
        ...DemoAuthService.demoSeekerDefaults(),
        'spoken_languages': ['English', 'Malayalam', 'Telugu', 'Kannada'],
        'budget_min': 1500,
        'budget_max': 2000,
        'full_name': 'Demo Seeker',
        'occupant_type': 'student',
      };

      final merged = DemoAuthService.mergeDemoSeekerSession(prior);

      expect(merged['spoken_languages'],
          ['English', 'Malayalam', 'Telugu', 'Kannada']);
      expect(merged['budget_max'], 2000);
      expect(merged['budget_min'], 1500);
      expect(merged['occupant_type'], 'student');
      // Defaults still seed identity markers when missing from prior save.
      expect(merged['email'], DemoAuthService.demoSeekerEmail);
      expect(merged['demo_mode'], isTrue);
    });
  });

  group('DemoAuthService.isDemoSeekerSession', () {
    test('matches demo seeker email or user id', () {
      expect(
        DemoAuthService.isDemoSeekerSession({
          'demo_mode': true,
          'email': DemoAuthService.demoSeekerEmail,
        }),
        isTrue,
      );
      expect(
        DemoAuthService.isDemoSeekerSession({
          'demo_mode': true,
          'supabase_user_id': DemoAuthService.demoSeekerUserId,
        }),
        isTrue,
      );
    });

    test('rejects demo_mode without seeker identity', () {
      expect(
        DemoAuthService.isDemoSeekerSession({
          'demo_mode': true,
          'email': 'demo.landlord@truecircle.dev',
        }),
        isFalse,
      );
    });
  });
}
