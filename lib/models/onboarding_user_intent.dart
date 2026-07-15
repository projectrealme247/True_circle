import 'package:flutter/material.dart';

import '../services/active_mode_service.dart';

/// Strategic intent captured at onboarding — seeker vs property provider.
///
/// Prefer [ActiveModeService.capabilities] for runtime host/seeker detection.
@Deprecated('Use ActiveModeService.capabilities — intent is onboarding-only')
enum OnboardingUserIntent {
  seeker('seeker', "I'm looking for a place"),
  provider('provider', 'I have a space to rent');

  const OnboardingUserIntent(this.storageToken, this.segmentLabel);

  final String storageToken;
  final String segmentLabel;

  /// Material icon — renders on first paint (unlike emoji in [segmentLabel]).
  IconData get segmentIcon => switch (this) {
        OnboardingUserIntent.seeker => Icons.search,
        OnboardingUserIntent.provider => Icons.home_outlined,
      };

  static OnboardingUserIntent fromSession(Map<String, dynamic>? session) {
    final raw =
        session?[ActiveModeService.onboardingIntentKey]?.toString().trim().toLowerCase();
    return switch (raw) {
      'provider' || 'landlord' || 'host' => OnboardingUserIntent.provider,
      _ => OnboardingUserIntent.seeker,
    };
  }
}
