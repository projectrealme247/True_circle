import '../services/trust_service.dart';
import '../utils/profile_data.dart';

/// Internal trust-profile mapping for persistence / payloads.
/// Landlord UI must use [isVerifiedUser] / [verifiedUserLabel] only — never
/// surface Just Landed / Grand / Sound to hosts.
enum ApplicantTrustTier {
  justLanded('Just Landed'),
  grand('Grand'),
  sound('Sound');

  const ApplicantTrustTier(this.storageToken);

  /// Canonical storage value in `user_trust_profiles.trust_tier`.
  final String storageToken;

  /// @deprecated Use [storageToken]. Kept for callers still naming it displayToken.
  String get displayToken => storageToken;

  static const verifiedUserLabel = '✅ Verified User';

  bool get isVerifiedUser => this != ApplicantTrustTier.justLanded;

  String get landlordBadgeLabel =>
      isVerifiedUser ? verifiedUserLabel : '';

  int get sortPriority => switch (this) {
        ApplicantTrustTier.sound => 3,
        ApplicantTrustTier.grand => 2,
        ApplicantTrustTier.justLanded => 1,
      };

  /// Legacy [trust_tier] string only — no trust_stage / identity_trust_tier.
  static ApplicantTrustTier fromTrustProfile({String? trustTier}) {
    final tierRaw = ProfileData.text(trustTier).toLowerCase();
    if (tierRaw.contains('sound')) return ApplicantTrustTier.sound;
    if (tierRaw.contains('grand')) return ApplicantTrustTier.grand;
    return ApplicantTrustTier.justLanded;
  }

  /// Contact-unlock method flags take precedence over legacy tier strings.
  static ApplicantTrustTier fromSession(Map<String, dynamic> session) {
    if (TrustService.meetsContactVerification(session)) {
      return ApplicantTrustTier.sound;
    }
    return fromTrustProfile(trustTier: ProfileData.text(session['trust_tier']));
  }
}
