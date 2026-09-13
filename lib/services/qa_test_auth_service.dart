import 'package:flutter/foundation.dart';

import '../config/market/dublin_commuter_hubs.dart';
import '../models/marketplace_space.dart';
import '../models/move_in_timing.dart';
import '../models/onboarding_user_role.dart';
import '../models/profile_onboarding_models.dart';
import '../screens/auth_screen.dart';
import 'active_mode_service.dart';
import 'auth_service.dart';
import 'commute_scoring_service.dart';
import 'marketplace_context_notifier.dart';
import 'profile_onboarding_repository.dart';
import 'profile_state_notifier.dart';
import 'profile_storage_service.dart';
import 'user_session_store.dart';

/// Persistent one-click QA identities (debug only). No password.
enum QaTestAccount {
  landlordIndependent(
    'landlord.independent',
    'qa-landlord-independent-uuid',
    'landlord.independent@truecircle.qa',
  ),
  landlordShared(
    'landlord.shared',
    'qa-landlord-shared-uuid',
    'landlord.shared@truecircle.qa',
  ),
  seekerIndependent(
    'seeker.independent',
    'qa-seeker-independent-uuid',
    'seeker.independent@truecircle.qa',
  ),
  seekerShared(
    'seeker.shared',
    'qa-seeker-shared-uuid',
    'seeker.shared@truecircle.qa',
  );

  const QaTestAccount(this.id, this.userId, this.email);

  final String id;
  final String userId;
  final String email;

  bool get isLandlord =>
      this == QaTestAccount.landlordIndependent ||
      this == QaTestAccount.landlordShared;

  bool get isSharedSpace =>
      this == QaTestAccount.landlordShared ||
      this == QaTestAccount.seekerShared;

  String get slotKey => 'circlekey_qa_profile_$id';

  String get buttonLabel => id;
}

abstract final class QaTestAuthService {
  static bool get isEnabled => kDebugMode;

  static bool isQaSession(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) return false;
    if (session['qa_mode'] == true) return true;
    final userId = session['supabase_user_id']?.toString();
    return QaTestAccount.values.any((account) => account.userId == userId);
  }

  static bool isQaSeekerSession(Map<String, dynamic>? session) {
    if (!isQaSession(session)) return false;
    return UserRole.fromSession(session) == UserRole.seeker;
  }

  /// QA identities use real local listings — do not inject Ranelagh harness.
  static bool allowMockHostListings(Map<String, dynamic>? session) {
    return !isQaSession(session);
  }

  static Future<void> enter(QaTestAccount account) async {
    assert(kDebugMode, 'QaTestAuthService must never be called in production');
    final storedSlot = await ProfileStorageService.loadSlot(account.slotKey);
    final session = mergeAccountSession(account, storedSlot);
    await _persistSession(account, session);
  }

  @visibleForTesting
  static Map<String, dynamic> mergeAccountSession(
    QaTestAccount account,
    Map<String, dynamic>? existing,
  ) {
    final defaults = defaultsFor(account);
    final sameIdentity = existing != null &&
        existing['supabase_user_id']?.toString() == account.userId;
    if (!sameIdentity) {
      return Map<String, dynamic>.from(defaults);
    }
    return {
      ...defaults,
      ...existing,
      ..._identityLock(account),
    };
  }

  static Map<String, dynamic> _identityLock(QaTestAccount account) {
    final now = DateTime.now().toUtc().toIso8601String();
    final space = account.isSharedSpace
        ? MarketplaceSpace.sharedSpace
        : MarketplaceSpace.fullRental;
    final role =
        account.isLandlord ? UserRole.landlord : UserRole.seeker;
    final track = switch (account) {
      QaTestAccount.landlordIndependent =>
        ProfileOnboardingTrack.landlordEntirePlace,
      QaTestAccount.landlordShared =>
        ProfileOnboardingTrack.landlordSharedSpace,
      QaTestAccount.seekerIndependent =>
        ProfileOnboardingTrack.seekerEntirePlace,
      QaTestAccount.seekerShared => ProfileOnboardingTrack.seekerSharedSpace,
    };
    return {
      UserRole.sessionKey: role.storageToken,
      'email': account.email,
      'supabase_user_id': account.userId,
      'qa_account_id': account.id,
      'qa_mode': true,
      'demo_mode': true,
      'onboarding_intent': account.isLandlord ? 'provider' : 'seeker',
      'profile_onboarding_track': track.storageToken,
      'preferred_arrangement': space.arrangementBackend,
      'preferred_property_type': space.towerPropertyType,
      'active_marketplace_space': space.storageToken,
      ActiveModeService.lastActiveModeKey: account.isLandlord
          ? ActiveMode.hosting.storageToken
          : ActiveMode.explore.storageToken,
      ActiveModeService.lastModeUpdatedAtKey: now,
    };
  }

  static Map<String, dynamic> defaultsFor(QaTestAccount account) {
    final lock = _identityLock(account);
    const tcdHub = DublinCommuterHubs.tcd;
    return switch (account) {
      QaTestAccount.landlordIndependent => {
          ...lock,
          'full_name': 'QA Independent Host',
          'host_profile_complete': true,
          'linkedin_verified': true,
          'listingSeed_listingMode': 'entire_place',
          'detected_city': 'Dublin',
        },
      QaTestAccount.landlordShared => {
          ...lock,
          'full_name': 'QA Shared Host',
          'host_profile_complete': true,
          'linkedin_verified': true,
          'listingSeed_listingMode': 'shared_space',
          'detected_city': 'Dublin',
        },
      QaTestAccount.seekerIndependent => {
          ...lock,
          'full_name': 'QA Independent Seeker',
          'detected_city': 'Dublin',
          'mother_tongue': 'English',
          'spoken_languages': ['English'],
          'occupant_type': 'professional',
          'budget_min': 1400,
          'budget_max': 2800,
          'linkedin_verified': true,
          'linkedin_company': 'TrueCircle QA',
          'linkedin_title': 'Product Designer',
          'commute_method': CommuteMethod.backendPublicTransportWalking,
          'maximum_commute_budget_minutes': 60,
          'move_in_window': SeekerMoveInWindow.flexible.storageToken,
          ...DublinCommuterHubs.persistFields(tcdHub),
        },
      QaTestAccount.seekerShared => {
          ...lock,
          'full_name': 'QA Shared Seeker',
          'detected_city': 'Dublin',
          'mother_tongue': 'English',
          'spoken_languages': ['English'],
          'occupant_type': 'student',
          'seeker_persona': 'student',
          'budget_min': 700,
          'budget_max': 1400,
          'light_trust_verified': true,
          'light_trust_method': 'university_email',
          'verified_university_email': 'qa****@tcd.ie',
          'commute_method': CommuteMethod.backendPublicTransportWalking,
          'maximum_commute_budget_minutes': 45,
          'move_in_window': SeekerMoveInWindow.flexible.storageToken,
          ...DublinCommuterHubs.persistFields(tcdHub),
        },
    };
  }

  static Future<void> _persistSession(
    QaTestAccount account,
    Map<String, dynamic> session,
  ) async {
    var next = Map<String, dynamic>.from(session);
    next = await ProfileOnboardingRepository.ensureLegacyHostTrackPersisted(next);
    UserSessionStore.current = next;
    AuthScreen.currentUserSession = next;
    profileStateNotifier.commitPersisted(next);
    await ProfileStorageService.save(next);
    await ProfileStorageService.saveSlot(account.slotKey, next);
    await marketplaceContextNotifier.refresh();
    authSessionNotifier.refresh();
  }
}
