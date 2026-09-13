import '../models/applicant_trust_tier.dart';
import '../services/trust_service.dart';
import 'profile_data.dart';
/// GDPR-safe landlord-facing verification summary — no raw financial fields.
class TenantVerificationCredentials {
  const TenantVerificationCredentials({
    required this.tierLabel,
    required this.tierTextColor,
    required this.tierBackgroundColor,
    required this.isVerifiedUser,
    this.track,
    this.showTrackChecklist = false,
  });

  /// Display label: ✅ Verified User or empty — never Just Landed / Grand / Sound.
  final String tierLabel;
  final int tierTextColor; // stored as ARGB for testability — use Color in UI
  final int tierBackgroundColor;
  final bool isVerifiedUser;
  final TenantVerificationTrack? track;
  final bool showTrackChecklist;

  static const complianceStamp =
      'Verified in Dublin. This profile satisfies all EU GDPR data minimization '
      'guidelines. Raw documentation was destroyed immediately following '
      'cryptographic validation.';

  /// Keys that must never surface in landlord verification UI.
  static const sensitiveFieldDenylist = {
    'monthly_salary_eur',
    'current_balance_eur',
    'salary',
    'balance',
    'iban',
    'account_number',
    'transactions',
    'transaction_history',
    'open_banking_verification_seal',
    'corporate_verification_seal',
    'employment_letter_path',
    'onboarding_letter_path',
    'passkey_public_key',
  };

  static bool containsSensitiveExposure(Map<String, dynamic> session) {
    return sensitiveFieldDenylist.any(session.containsKey);
  }

  static TenantVerificationCredentials fromSession(Map<String, dynamic> session) {
    final trackToken = ProfileData.text(session['verification_track']);

    TenantVerificationTrack? track;
    var showTrackChecklist = false;

    if (trackToken == 'Corporate Track' &&
        session['employment_verified'] == true) {
      track = TenantVerificationTrack.corporate;
      showTrackChecklist = true;
    } else if (trackToken == 'Open Banking Track' &&
        session['financial_verified'] == true) {
      track = TenantVerificationTrack.openBanking;
      showTrackChecklist = true;
    }

    final verified = TrustService.meetsContactVerification(session);
    final badge = _badgeForContact(verified);

    return TenantVerificationCredentials(
      tierLabel: badge.label,
      tierTextColor: badge.textColor,
      tierBackgroundColor: badge.backgroundColor,
      isVerifiedUser: verified,
      track: track,
      showTrackChecklist: showTrackChecklist,
    );
  }

  static const _neutralTextColor = 0xFF717171;
  static const _neutralBackgroundColor = 0xFFF0F0F0;

  static _TierBadge _badgeForContact(bool verified) {
    return _TierBadge(
      label: verified ? ApplicantTrustTier.verifiedUserLabel : '',
      textColor: _neutralTextColor,
      backgroundColor: _neutralBackgroundColor,
    );
  }
}

enum TenantVerificationTrack {
  corporate,
  openBanking,
}

extension TenantVerificationTrackCopy on TenantVerificationTrack {
  String get successBadge => switch (this) {
        TenantVerificationTrack.corporate =>
          'Identity & Employment Verified: Corporate Track',
        TenantVerificationTrack.openBanking =>
          'Identity & Finances Verified: Open Banking Track',
      };

  String get subtitle => switch (this) {
        TenantVerificationTrack.corporate =>
          'Verified via Ephemeral Corporate Document Matching & Dublin Employer '
          'Registry Cross-Check. Financial capability backed by verified contract '
          'salary metrics.',
        TenantVerificationTrack.openBanking =>
          'Authenticated directly via a secure, read-once European Open Banking live '
          'stream. Income liquidity and bank KYC profile matches user account perfectly.',
      };

  String get neutralStatusBadge => switch (this) {
        TenantVerificationTrack.corporate =>
          'Financial Status: Pre-Arrival / Relocator Mode',
        TenantVerificationTrack.openBanking =>
          'Employment Status: Self-Declared / Local Resident',
      };
}

class _TierBadge {
  const _TierBadge({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
  });

  final String label;
  final int textColor;
  final int backgroundColor;
}
