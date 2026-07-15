import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/services/active_mode_service.dart';

void main() {
  group('ActiveModeService.resolveLandingRoute', () {
    Map<String, dynamic> dualCapableSession({
      String mode = 'explore',
      String? updatedAt,
    }) =>
        {
          'email': 'dual@example.com',
          'onboarding_intent': 'seeker',
          'host_profile_complete': true,
          'budget_max': 2000,
          'detected_city': 'Dublin',
          'full_name': 'Dual User',
          'mother_tongue': 'English',
          'spoken_languages': ['English'],
          ActiveModeService.lastActiveModeKey: mode,
          if (updatedAt != null)
            ActiveModeService.lastModeUpdatedAtKey: updatedAt,
        };

    test('host-capable with zero listings routes to add-listing', () {
      final session = {
        'email': 'host@example.com',
        'onboarding_intent': 'provider',
        'host_profile_complete': true,
      };

      final resolution = ActiveModeService.resolveLandingRoute(
        session: session,
        ownedListingCount: 0,
      );

      expect(resolution.action, LandingAction.navigate);
      expect(resolution.route, '/add-listing');
    });

    test('stale dual-capable session prompts mode refresh', () {
      final staleDate = DateTime.now()
          .subtract(const Duration(days: 120))
          .toUtc()
          .toIso8601String();
      final session = dualCapableSession(updatedAt: staleDate);

      final resolution = ActiveModeService.resolveLandingRoute(
        session: session,
        ownedListingCount: 2,
      );

      expect(resolution.action, LandingAction.showStaleModePrompt);
      expect(resolution.route, isNull);
    });

    test('hosting mode with owned listings routes to dashboard', () {
      final session = dualCapableSession(mode: 'hosting');

      final resolution = ActiveModeService.resolveLandingRoute(
        session: session,
        ownedListingCount: 2,
      );

      expect(resolution.action, LandingAction.navigate);
      expect(resolution.route, '/landlord-dashboard');
    });

    test('default explore path routes to marketplace', () {
      final session = {
        'email': 'seeker@example.com',
        'onboarding_intent': 'seeker',
        'budget_max': 1800,
        'detected_city': 'Dublin',
        'full_name': 'Seeker',
        'mother_tongue': 'English',
        'spoken_languages': ['English'],
        ActiveModeService.lastActiveModeKey: 'explore',
        ActiveModeService.lastModeUpdatedAtKey:
            DateTime.now().toUtc().toIso8601String(),
      };

      final resolution = ActiveModeService.resolveLandingRoute(
        session: session,
        ownedListingCount: 0,
      );

      expect(resolution.action, LandingAction.navigate);
      expect(resolution.route, '/');
    });
  });

  group('ActiveModeService.unreadActivityFor', () {
    test('explore mode surfaces host applicant badge', () {
      final session = {
        'onboarding_intent': 'provider',
        'host_profile_complete': true,
        'budget_max': 2000,
        'detected_city': 'Dublin',
        'full_name': 'Dual Host',
        'mother_tongue': 'English',
        'spoken_languages': ['English'],
        ActiveModeService.lastActiveModeKey: 'explore',
      };

      final unread = ActiveModeService.unreadActivityFor(
        session: session,
        activeMode: ActiveMode.explore,
        hostApplicantCount: 4,
        seekerStrongMatchCount: 2,
      );

      expect(unread.hostBadgeCount, 4);
      expect(unread.seekerBadgeCount, 0);
    });

    test('hosting mode surfaces seeker strong-match badge', () {
      final session = {
        'onboarding_intent': 'provider',
        'host_profile_complete': true,
        'budget_max': 2000,
        'detected_city': 'Dublin',
        'full_name': 'Dual Host',
        'mother_tongue': 'English',
        'spoken_languages': ['English'],
        ActiveModeService.lastActiveModeKey: 'hosting',
      };

      final unread = ActiveModeService.unreadActivityFor(
        session: session,
        activeMode: ActiveMode.hosting,
        hostApplicantCount: 4,
        seekerStrongMatchCount: 3,
      );

      expect(unread.hostBadgeCount, 0);
      expect(unread.seekerBadgeCount, 3);
    });
  });
}
