import '../services/active_mode_service.dart';
import '../services/trust_service.dart';
import 'listing_data.dart';
import 'profile_data.dart';
import 'viewer_profile.dart';

/// Trust badges and completion logic for the polymorphic identity layer.
abstract final class PolymorphicIdentity {
  static const enterpriseVerifiedLabel = '🔵 Enterprise Verified';
  static const verifiedProfessionalHostLabel = '🔒 Verified Professional Host';

  static bool isAtLeastSocialVerified() =>
      TrustService.currentStage().level >= TrustStage.socialVerified.level;

  static bool isAtLeastIdVerified() =>
      TrustService.currentStage().level >= TrustStage.idVerified.level;

  /// Seeker-facing enterprise badge (Working Professionals cohort).
  static bool showEnterpriseVerifiedSeekerBadge(
    Map<String, dynamic>? session,
  ) {
    if (session == null || !isAtLeastSocialVerified()) return false;

    final cohort = ViewerProfile.seekerCohortFromSession(session);
    if (cohort != SeekerCohort.workingProfessional) return false;

    return session['linkedin_verified'] == true ||
        session['employment_letter_verified'] == true ||
        ProfileData.text(session['company']).isNotEmpty;
  }

  /// Host-facing badge inherited onto listing cards.
  static bool showVerifiedProfessionalHostBadge(
    Map<String, dynamic> listing,
  ) =>
      ListingData.hostTrustStage(listing) >= TrustStage.socialVerified.level;

  static bool useHostCompletionDenominator({
    required Map<String, dynamic>? session,
    required int ownedListingCount,
  }) {
    final caps = ActiveModeService.capabilitiesFor(session)
        .withOwnedListingCount(ownedListingCount);
    return (ActiveModeService.current == ActiveMode.hosting && caps.canHost) ||
        ownedListingCount > 1;
  }
}
