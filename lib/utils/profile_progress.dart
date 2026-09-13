import '../services/active_mode_service.dart';
import '../services/auth_service.dart';
import '../services/profile_state_notifier.dart';
import 'profile_data.dart';

/// Home explore onboarding / profile-completion banner states.
enum HomeOnboardingBannerState {
  hidden,
  signInRequired,
  completeProfile,
  continueProfile,
}

/// Seeker vs host completion surfaces.
enum ProfileCompletionAudience {
  seeker,
  host,
}

/// Single source of truth for profile completion % across home + profile surfaces.
abstract final class ProfileProgress {
  /// Resolves which onboarding banner (if any) the marketplace feed should show.
  ///
  /// Host completion prompts live on the landlord dashboard — not the marketplace.
  static HomeOnboardingBannerState homeBannerState(
    Map<String, dynamic>? session, {
    required bool signedIn,
  }) {
    if (!signedIn) return HomeOnboardingBannerState.signInRequired;
    if (ActiveModeService.current == ActiveMode.hosting) {
      return HomeOnboardingBannerState.hidden;
    }
    if (!ProfileData.isProfileIncomplete(session)) {
      return HomeOnboardingBannerState.hidden;
    }
    final pct = seekerPercent(session);
    if (pct <= 0) return HomeOnboardingBannerState.completeProfile;
    return HomeOnboardingBannerState.continueProfile;
  }

  /// Host profile completion banner for the landlord dashboard.
  ///
  /// Hidden once the host has published at least one listing — listing
  /// creation already collected the operational host basics. Remaining
  /// gaps (e.g. phone) belong on Profile, not a dashboard nag.
  static HomeOnboardingBannerState hostBannerState(
    Map<String, dynamic>? session, {
    required bool signedIn,
    int ownedListingCount = 0,
  }) {
    if (!signedIn) return HomeOnboardingBannerState.hidden;
    if (!ActiveModeService.capabilities.canHost) {
      return HomeOnboardingBannerState.hidden;
    }
    if (ownedListingCount > 0) {
      return HomeOnboardingBannerState.hidden;
    }
    if (!isHostProfileIncomplete(session)) {
      return HomeOnboardingBannerState.hidden;
    }
    final pct = hostPercent(session);
    if (pct <= 0) return HomeOnboardingBannerState.completeProfile;
    return HomeOnboardingBannerState.continueProfile;
  }

  /// Convenience wrapper using [AuthService.isSignedIn].
  static HomeOnboardingBannerState homeBannerStateForSession(
    Map<String, dynamic>? session,
  ) =>
      homeBannerState(
        session,
        signedIn: AuthService.isSignedIn(session),
      );

  static int seekerPercent(Map<String, dynamic>? session) =>
      ProfileData.calculateProfileCompletionPercentage(
        session ?? profileStateNotifier.session,
      );

  static int hostPercent(Map<String, dynamic>? session) {
    if (session == null) return 0;
    final checks = _hostCompletionChecks(session);
    if (checks.isEmpty) return 0;
    final filled = checks.where((check) => check).length;
    return ((filled / checks.length) * 100).round().clamp(0, 100);
  }

  static int percent(
    Map<String, dynamic>? session, {
    required int ownedListingCount,
    ProfileCompletionAudience audience = ProfileCompletionAudience.seeker,
  }) =>
      audience == ProfileCompletionAudience.host
          ? hostPercent(session)
          : seekerPercent(session);

  static List<String> missingFields(
    Map<String, dynamic>? session, {
    required int ownedListingCount,
    ProfileCompletionAudience audience = ProfileCompletionAudience.seeker,
  }) {
    final resolved = session ?? profileStateNotifier.session;
    if (audience == ProfileCompletionAudience.host) {
      return missingHostFields(resolved);
    }
    return ProfileData.missingFieldsForCompletion(resolved);
  }

  static bool isHostProfileIncomplete(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) return true;
    if (session['host_profile_complete'] == true) {
      return ProfileData.text(
            session['contact_phone'] ?? session['contact_phone_e164'],
          ).isEmpty;
    }
    return ProfileData.text(session['full_name']).isEmpty ||
        ProfileData.text(
          session['contact_phone'] ?? session['contact_phone_e164'],
        ).isEmpty;
  }

  static List<bool> _hostCompletionChecks(Map<String, dynamic> session) => [
        ProfileData.text(session['full_name']).isNotEmpty,
        ProfileData.text(session['email']).isNotEmpty,
        ProfileData.text(
          session['contact_phone'] ?? session['contact_phone_e164'],
        ).isNotEmpty,
        session['host_profile_complete'] == true ||
            ProfileData.text(session['pending_listing_location']).isNotEmpty,
      ];

  static List<String> missingHostFields(Map<String, dynamic>? session) {
    if (session == null) {
      return const ['Full name', 'Contact phone', 'Listing area'];
    }
    final missing = <String>[];
    if (ProfileData.text(session['full_name']).isEmpty) {
      missing.add('Full name');
    }
    if (ProfileData.text(session['email']).isEmpty) missing.add('Email');
    if (ProfileData.text(
      session['contact_phone'] ?? session['contact_phone_e164'],
    ).isEmpty) {
      missing.add('Contact phone');
    }
    if (session['host_profile_complete'] != true &&
        ProfileData.text(session['pending_listing_location']).isEmpty) {
      missing.add('Listing area');
    }
    return missing;
  }
}
