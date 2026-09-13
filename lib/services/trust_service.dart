import '../screens/auth_screen.dart';
import '../utils/irish_university_domains.dart';
import '../utils/profile_data.dart';
import '../utils/viewer_profile.dart';
import 'profile_storage_service.dart';

/// Manages verification method flags and related session upgrades.
/// Does not write trust_stage / identity_trust_tier (T3).
abstract final class TrustService {
  /// Upgrade after LinkedIn verification.
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

    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
  }

  /// Upgrade after ID verification (Aadhaar + Passkey).
  static Future<void> upgradeIdVerified({
    String? verifiedName,
  }) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

    session['is_aadhaar_verified'] = true;
    if (verifiedName != null) {
      session['verified_legal_name'] = verifiedName;
    }

    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
  }

  /// Track A — Dublin light trust via university email.
  static Future<void> upgradeLightTrust({
    required String method,
    String? verifiedEmail,
  }) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

    session['light_trust_verified'] = true;
    session['light_trust_method'] = method;
    if (verifiedEmail != null) {
      session['verified_university_email'] =
          IrishUniversityDomains.maskEmail(verifiedEmail);
    }

    // Promoted from pre-arrival Path B — clear contact-only flags.
    session.remove('invite_code_verified');
    session.remove('invite_code_used');
    session.remove('invited_by_user_id');
    session.remove('onboarding_letter_verified');
    session.remove('onboarding_letter_path');
    session.remove('pre_arrival_contact_ready');
    session.remove('pre_arrival_student');

    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
  }

  /// Path B — student declaration (no invite code or document upload).
  static Future<void> submitPreArrivalStudentDeclaration() async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

    session['pre_arrival_student'] = true;
    session['pre_arrival_contact_ready'] = true;

    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
  }

  /// True when Path B declaration is set, or a legacy invite+letter session.
  static bool preArrivalContactReady([Map<String, dynamic>? raw]) {
    final session = raw ?? AuthScreen.currentUserSession;
    if (session == null) return false;
    return meetsPreArrivalUnlock(session);
  }

  /// Declaration, stored ready flag, or legacy invite + letter.
  static bool meetsPreArrivalUnlock(Map<String, dynamic> session) {
    if (session['pre_arrival_student'] == true) return true;
    if (session['pre_arrival_contact_ready'] == true) return true;
    return session['invite_code_verified'] == true &&
        session['onboarding_letter_verified'] == true;
  }

  /// Corporate Track — server-verified employment document (zero-retention).
  static Future<void> upgradeCorporateDocument({
    required String verificationSeal,
    required String verifiedAt,
    String verificationTrack = 'Corporate Track',
  }) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

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

  /// Open Banking Track — deferred/legacy financial-signal stamp.
  /// Does not verify income, salary, or rent affordability. Tokens never stored.
  static Future<void> upgradeOpenBanking({
    required String verificationSeal,
    required String verifiedAt,
    String verificationTrack = 'Open Banking Track',
    String? institutionLabel,
  }) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

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

    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
  }

  /// Legacy family budget-proof writer — retained for stored sessions.
  /// Not used as a contact-unlock path (families use LinkedIn / employment).
  static Future<void> submitJitFamilyBudgetProof({
    required String localPath,
  }) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

    session['family_budget_proof_verified'] = true;
    session['family_budget_proof_path'] = localPath;
    session['jit_verification_method'] = 'family_budget_proof';

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

  /// Stamp non-ranking host metadata onto a listing before publishing.
  /// Does not write host_trust_stage / host_trust_multiplier / host_verified_badge.
  static Map<String, dynamic> stampListingTrust(Map<String, dynamic> listing) {
    final session = AuthScreen.currentUserSession;
    if (session == null) return listing;

    return {
      ...listing,
      if (session['linkedin_verified'] == true)
        'host_linkedin_badge':
            '${session['linkedin_title'] ?? ''} at ${session['linkedin_company'] ?? ''}'
                .trim(),
      // Pre-arrival host signal (declaration or legacy ready flag).
      'host_pre_arrival_badge': preArrivalContactReady(),
    };
  }

  /// Contacting a host — verification-signal gates by seeker cohort.
  static bool canContact() =>
      meetsContactVerification(AuthScreen.currentUserSession);

  /// Same criteria as [canContact], for any session map (badges, landlord views).
  ///
  /// Students: university email OR pre-arrival declaration (legacy letter still counts).
  /// Professionals / families: LinkedIn OR employment verified.
  /// Does **not** use trust_stage / trust_tier / identity_trust_tier.
  static bool meetsContactVerification(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) return false;

    final cohort = ViewerProfile.seekerCohortFromSession(session);
    if (cohort == SeekerCohort.student) {
      return _hasStudentContactVerification(session);
    }
    return _hasProfessionalContactVerification(session);
  }

  static bool _hasStudentContactVerification(Map<String, dynamic> session) {
    if (meetsPreArrivalUnlock(session)) return true;
    if (session['onboarding_letter_verified'] == true) return true;
    if (session['light_trust_verified'] == true) return true;
    return ProfileData.text(session['verified_university_email']).isNotEmpty;
  }

  static bool _hasProfessionalContactVerification(Map<String, dynamic> session) {
    return session['linkedin_verified'] == true ||
        session['employment_verified'] == true ||
        session['employment_letter_verified'] == true;
  }
}
