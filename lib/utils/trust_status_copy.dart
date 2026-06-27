import 'viewer_profile.dart';

/// Standardized user-facing trust tier copy (landlord + seeker surfaces).
abstract final class TrustStatusCopy {
  static const justLandedBrowsing =
      'You are currently browsing as a Just Landed profile. '
      'Complete verification to connect with premium hosts instantly.';

  static bool usesLegacyCasualLabel(TrustStage stage) =>
      stage == TrustStage.casual || stage == TrustStage.anonymous;
}
