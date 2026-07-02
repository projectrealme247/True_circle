/// Strategic intent captured at onboarding — seeker vs property provider.
enum OnboardingUserIntent {
  seeker('seeker', '🔍 I\'m looking for a place'),
  provider('provider', '🏠 I have a space to rent');

  const OnboardingUserIntent(this.storageToken, this.segmentLabel);

  final String storageToken;
  final String segmentLabel;

  static OnboardingUserIntent fromSession(Map<String, dynamic>? session) {
    final raw = session?['onboarding_intent']?.toString().trim().toLowerCase() ??
        session?['view_preference_override']?.toString().trim().toLowerCase();
    return switch (raw) {
      'provider' || 'landlord' || 'host' => OnboardingUserIntent.provider,
      _ => OnboardingUserIntent.seeker,
    };
  }
}
