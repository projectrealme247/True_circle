import '../services/active_mode_service.dart';
import '../services/trust_service.dart';

/// Completion helpers for dual seeker/host identity — no trust-tier badges.
abstract final class PolymorphicIdentity {
  /// @deprecated Enterprise badge removed — use ✅ Verified User via contact unlock.
  static const enterpriseVerifiedLabel = '🔵 Enterprise Verified';

  /// @deprecated Host professional badge removed — no host verification programme.
  static const verifiedProfessionalHostLabel = '🔒 Verified Professional Host';

  /// Never show Enterprise Verified — single badge is ✅ Verified User.
  static bool showEnterpriseVerifiedSeekerBadge(
    Map<String, dynamic>? session,
  ) =>
      false;

  /// Never show host trust badges from listing trust stamps.
  static bool showVerifiedProfessionalHostBadge(
    Map<String, dynamic> listing,
  ) =>
      false;

  /// Seeker Verified User — same criteria as [TrustService.canContact].
  static bool showVerifiedUserBadge(Map<String, dynamic>? session) =>
      TrustService.meetsContactVerification(session);

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
