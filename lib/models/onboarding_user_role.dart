import 'onboarding_user_intent.dart';
import '../services/active_mode_service.dart';

/// Canonical signed-in role used for post-auth routing decisions.
enum UserRole {
  seeker('seeker'),
  landlord('landlord'),
  unassigned('unassigned');

  const UserRole(this.storageToken);

  /// Persisted on session under `role`.
  final String storageToken;

  static const sessionKey = 'role';

  /// Prefer explicit [sessionKey], then capabilities, then onboarding intent.
  static UserRole fromSession(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) return UserRole.unassigned;

    final roleRaw = session[sessionKey]?.toString().trim().toLowerCase() ?? '';
    final fromRole = switch (roleRaw) {
      'seeker' => UserRole.seeker,
      'landlord' || 'host' || 'provider' => UserRole.landlord,
      _ => null,
    };
    if (fromRole != null) return fromRole;

    final caps = ActiveModeService.capabilitiesFor(session);
    if (caps.canHost && !caps.canSeek) return UserRole.landlord;
    if (caps.canSeek && !caps.canHost) return UserRole.seeker;

    final intentRaw = session[ActiveModeService.onboardingIntentKey]
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    return switch (intentRaw) {
      'provider' || 'landlord' || 'host' => UserRole.landlord,
      'seeker' => UserRole.seeker,
      _ => UserRole.unassigned,
    };
  }

  OnboardingUserIntent? toIntent() => switch (this) {
        UserRole.seeker => OnboardingUserIntent.seeker,
        UserRole.landlord => OnboardingUserIntent.provider,
        UserRole.unassigned => null,
      };

  String get primaryActionLabel => switch (this) {
        UserRole.seeker => 'Find your home →',
        UserRole.landlord => 'Create your listing →',
        UserRole.unassigned => 'Continue →',
      };
}
