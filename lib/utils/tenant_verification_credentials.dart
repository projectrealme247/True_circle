import 'profile_data.dart';
import 'viewer_profile.dart';

/// GDPR-safe landlord-facing verification summary — no raw financial fields.
class TenantVerificationCredentials {
  const TenantVerificationCredentials({
    required this.tierLabel,
    required this.tierTextColor,
    required this.tierBackgroundColor,
    required this.trustStage,
    this.track,
    this.showTrackChecklist = false,
  });

  final String tierLabel;
  final int tierTextColor; // stored as ARGB for testability — use Color in UI
  final int tierBackgroundColor;
  final TrustStage trustStage;
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
    final stage = _stageFromSession(session);
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

    final badge = _badgeForStage(stage);

    return TenantVerificationCredentials(
      tierLabel: badge.label,
      tierTextColor: badge.textColor,
      tierBackgroundColor: badge.backgroundColor,
      trustStage: stage,
      track: track,
      showTrackChecklist: showTrackChecklist,
    );
  }

  static TrustStage _stageFromSession(Map<String, dynamic> session) {
    final rawStage = session['trust_stage'];
    if (rawStage is int) {
      return TrustStage.fromLevel(rawStage);
    }

    final tier = ProfileData.text(session['trust_tier']).toLowerCase();
    if (tier == 'sound') return TrustStage.idVerified;
    if (tier == 'grand') return TrustStage.socialVerified;

    final identityTier = ProfileData.text(session['identity_trust_tier']).toLowerCase();
    if (identityTier.contains('id_verified')) return TrustStage.idVerified;
    if (identityTier.contains('social')) return TrustStage.socialVerified;

    return TrustStage.casual;
  }

  static const _neutralTextColor = 0xFF717171;
  static const _neutralBackgroundColor = 0xFFF0F0F0;

  static _TierBadge _badgeForStage(TrustStage stage) {
    final label = switch (stage) {
      TrustStage.idVerified => 'Sound',
      TrustStage.socialVerified => 'Grand',
      _ => 'Just Landed',
    };
    return _TierBadge(
      label: label,
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
