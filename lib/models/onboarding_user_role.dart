import 'onboarding_user_intent.dart';
import '../services/active_mode_service.dart';

/// Active role fork on the master onboarding gateway.
///
/// Superseded by [ActiveModeService] — kept for legacy gateway copy only.
@Deprecated('Use ActiveModeService.capabilities and ActiveMode')
enum UserRole {
  seeker,
  landlord,
  unassigned;

  static UserRole fromSession(Map<String, dynamic>? session) {
    if (session == null) return UserRole.unassigned;
    final caps = ActiveModeService.capabilitiesFor(session);
    if (caps.canHost && !caps.canSeek) return UserRole.landlord;
    if (caps.canSeek && !caps.canHost) return UserRole.seeker;
    final raw =
        session[ActiveModeService.onboardingIntentKey]?.toString().trim().toLowerCase() ??
            '';
    return switch (raw) {
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
