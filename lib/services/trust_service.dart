import '../screens/auth_screen.dart';
import '../utils/viewer_profile.dart';
import 'profile_storage_service.dart';

/// Manages trust stage transitions for the progressive trust funnel.
abstract final class TrustService {
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
    };
  }

  /// Any signed-in user (Stage 1+) can publish. Trust badges and the
  /// multiplier handle ranking -- no gatekeeping.
  static bool canPublish() =>
      currentStage().level >= TrustStage.casual.level;

  /// Contacting a host involves real transactions, so Stage 3 is required.
  static bool canContact() =>
      currentStage().level >= TrustStage.idVerified.level;
}
