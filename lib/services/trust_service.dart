import '../config/market/market_config.dart';
import '../debug/agent_log.dart';
import '../screens/auth_screen.dart';
import '../utils/irish_university_domains.dart';
import '../utils/profile_data.dart';
import '../utils/viewer_profile.dart';
import 'profile_storage_service.dart';

/// Manages trust stage transitions for the progressive trust funnel.
abstract final class TrustService {
  static bool isAtLeastStage(TrustStage minimum) =>
      currentStage().level >= minimum.level;

  static bool isSocialVerifiedOrAbove() =>
      isAtLeastStage(TrustStage.socialVerified);

  static bool isIdVerifiedOrAbove() => isAtLeastStage(TrustStage.idVerified);

  /// Current trust stage from session.
  static TrustStage currentStage() {
    final session = AuthScreen.currentUserSession;
    if (session == null) return TrustStage.anonymous;
    final raw = session['trust_stage'];
    if (raw is int) return TrustStage.fromLevel(raw);
    return TrustStage.casual;
  }

  /// Upgrade to Stage 2 after LinkedIn verification.
  static Future<void> upgradeSocial({
    required String company,
    required String jobTitle,
    String? linkedinSub,
    String? linkedinEmail,
    String? linkedinName,
    String? linkedinPictureUrl,
  }) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

    session['trust_stage'] = TrustStage.socialVerified.level;
    session['identity_trust_tier'] = 'Social_Verified';
    session['linkedin_verified'] = true;
    session['linkedin_company'] = company;
    session['linkedin_title'] = jobTitle;
    session['company'] = company;
    session['job_title'] = jobTitle;
    if (linkedinSub != null) session['linkedin_sub'] = linkedinSub;
    if (linkedinEmail != null) session['linkedin_email'] = linkedinEmail;
    if (linkedinName != null) session['linkedin_name'] = linkedinName;
    if (linkedinPictureUrl != null) {
      session['linkedin_picture_url'] = linkedinPictureUrl;
    }
    if (ProfileData.text(session['full_name']).isEmpty &&
        linkedinName != null &&
        linkedinName.trim().isNotEmpty) {
      session['full_name'] = linkedinName.trim();
    }

    // #region agent log
    agentLog(
      location: 'trust_service.dart:upgradeSocial',
      message: 'LinkedIn social upgrade persisted',
      hypothesisId: 'H1',
      data: {
        'fullNameSet': ProfileData.text(session['full_name']).isNotEmpty,
        'trustStage': session['trust_stage'],
        'linkedinVerified': session['linkedin_verified'] == true,
      },
    );
    // #endregion

    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
  }

  /// Upgrade to Stage 3 after ID verification (Aadhaar + Passkey).
  static Future<void> upgradeIdVerified({
    String? verifiedName,
  }) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

    session['trust_stage'] = TrustStage.idVerified.level;
    session['identity_trust_tier'] = 'ID_Verified';
    session['is_aadhaar_verified'] = true;
    if (verifiedName != null) {
      session['verified_legal_name'] = verifiedName;
    }

    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
  }

  /// Track A — Dublin light trust via university email (Stage 3).
  static Future<void> upgradeLightTrust({
    required String method,
    String? verifiedEmail,
  }) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

    session['trust_stage'] = TrustStage.idVerified.level;
    session['identity_trust_tier'] = 'ID_Verified';
    session['light_trust_verified'] = true;
    session['light_trust_method'] = method;
    if (verifiedEmail != null) {
      session['verified_university_email'] =
          IrishUniversityDomains.maskEmail(verifiedEmail);
    }

    // Promoted from pre-arrival Track B — clear contact-only flags.
    session.remove('invite_code_verified');
    session.remove('invited_by_user_id');
    session.remove('onboarding_letter_verified');
    session.remove('onboarding_letter_path');
    session.remove('pre_arrival_contact_ready');

    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
  }

  /// Track B step 1 — invite code redeemed (Stage 2, contact-only path).
  static Future<void> completeInviteCodeRedemption({
    required String code,
    required String invitedByUserId,
  }) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

    session['invite_code_verified'] = true;
    session['invite_code_used'] = code.trim().toUpperCase();
    session['invited_by_user_id'] = invitedByUserId;
    _syncPreArrivalContactReady(session);

    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
  }

  /// Track B step 2 — onboarding letter uploaded (Stage 2, contact-only).
  static Future<void> submitOnboardingLetter({
    required String localPath,
  }) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

    session['onboarding_letter_verified'] = true;
    session['onboarding_letter_path'] = localPath;
    _syncPreArrivalContactReady(session);

    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
  }

  static void _syncPreArrivalContactReady(Map<String, dynamic> session) {
    final ready = session['invite_code_verified'] == true &&
        session['onboarding_letter_verified'] == true;
    session['pre_arrival_contact_ready'] = ready;
  }

  /// True when Track B invite + letter are both complete (Stage 2 contact path).
  static bool preArrivalContactReady() {
    final session = AuthScreen.currentUserSession;
    if (session == null) return false;
    return session['pre_arrival_contact_ready'] == true;
  }

  /// Corporate Track — server-verified employment document (zero-retention).
  static Future<void> upgradeCorporateDocument({
    required String verificationSeal,
    required String verifiedAt,
    String verificationTrack = 'Corporate Track',
  }) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

    session['trust_tier'] = 'Grand';
    session['trust_stage'] = TrustStage.socialVerified.level;
    session['identity_trust_tier'] = 'Social_Verified';
    session['employment_verified'] = true;
    session['verification_track'] = verificationTrack;
    session['corporate_verification_seal'] = verificationSeal;
    session['corporate_verified_at'] = verifiedAt;
    session['employment_letter_verified'] = true;
    session['jit_verification_method'] = 'corporate_document';
    session.remove('employment_letter_path');
    session.remove('onboarding_letter_path');

    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
  }

  /// Open Banking Track — read-once AIS verification (tokens never stored).
  static Future<void> upgradeOpenBanking({
    required String verificationSeal,
    required String verifiedAt,
    String verificationTrack = 'Open Banking Track',
    String? institutionLabel,
  }) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

    session['trust_tier'] = 'Grand';
    session['trust_stage'] = TrustStage.socialVerified.level;
    session['identity_trust_tier'] = 'Social_Verified';
    session['financial_verified'] = true;
    session['verification_track'] = verificationTrack;
    session['open_banking_verification_seal'] = verificationSeal;
    session['open_banking_verified_at'] = verifiedAt;
    session['jit_verification_method'] = 'open_banking';
    if (institutionLabel != null && institutionLabel.isNotEmpty) {
      session['open_banking_institution'] = institutionLabel;
    }

    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
  }

  static Future<void> submitJitEmploymentLetter({
    required String localPath,
  }) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

    session['employment_letter_verified'] = true;
    session['employment_letter_path'] = localPath;
    session['jit_verification_method'] = 'employment_letter';
    session['trust_stage'] = TrustStage.socialVerified.level;
    session['identity_trust_tier'] = 'Social_Verified';
    session['trust_tier'] = 'Grand';

    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
  }

  /// Phase 3 — arriving family: local bank statement summary scan.
  static Future<void> submitJitFamilyBudgetProof({
    required String localPath,
  }) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

    session['family_budget_proof_verified'] = true;
    session['family_budget_proof_path'] = localPath;
    session['jit_verification_method'] = 'family_budget_proof';
    session['trust_stage'] = TrustStage.socialVerified.level;
    session['identity_trust_tier'] = 'Social_Verified';

    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
  }

  /// Bind a passkey to the current session.
  static Future<void> bindPasskey(String publicKey) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

    session['passkey_public_key'] = publicKey;
    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
  }

  /// Stamp trust fields onto a listing before publishing.
  static Map<String, dynamic> stampListingTrust(Map<String, dynamic> listing) {
    final session = AuthScreen.currentUserSession;
    if (session == null) return listing;

    final stage = currentStage();
    final profile = ViewerProfile.fromSession(session);
    final preArrival =
        stage.level < TrustStage.idVerified.level && preArrivalContactReady();

    return {
      ...listing,
      'host_trust_stage': stage.level,
      'host_trust_multiplier': stage.multiplier,
      if (profile != null) 'host_circle_markers': profile.circleMarkers,
      if (session['linkedin_verified'] == true)
        'host_linkedin_badge':
            '${session['linkedin_title'] ?? ''} at ${session['linkedin_company'] ?? ''}'
                .trim(),
      'host_verified_badge': stage == TrustStage.idVerified,
      'host_pre_arrival_badge': preArrival,
    };
  }

  /// Any signed-in user (Stage 1+) can publish. Trust badges and the
  /// multiplier handle ranking -- no gatekeeping.
  static bool canPublish() =>
      currentStage().level >= TrustStage.casual.level;

  /// Contacting a host — cohort-aware progressive trust gates.
  static bool canContact() {
    final session = AuthScreen.currentUserSession;
    if (session == null) return false;

    final stage = currentStage();
    final cohort = ViewerProfile.seekerCohortFromSession(session);

    if (cohort == SeekerCohort.student) {
      if (stage.level >= TrustStage.idVerified.level) return true;

      if (MarketConfig.current.trustVerificationKind ==
          TrustVerificationKind.lightTrust) {
        return stage.level >= TrustStage.socialVerified.level &&
            preArrivalContactReady();
      }

      return false;
    }

    if (cohort.needsJitSocialGate) {
      return stage.level >= TrustStage.socialVerified.level;
    }

    if (stage.level >= TrustStage.idVerified.level) return true;

    if (MarketConfig.current.trustVerificationKind ==
        TrustVerificationKind.lightTrust) {
      return stage.level >= TrustStage.socialVerified.level &&
          preArrivalContactReady();
    }

    return false;
  }
}
