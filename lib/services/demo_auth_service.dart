import 'package:flutter/foundation.dart';

import '../config/market/dublin_commuter_hubs.dart';
import '../data/dublin_mock_data.dart';
import '../models/marketplace_space.dart';
import '../models/move_in_timing.dart';
import '../models/onboarding_user_role.dart';
import '../models/profile_onboarding_models.dart';
import '../screens/auth_screen.dart';
import 'auth_service.dart';
import 'commute_scoring_service.dart';
import 'active_mode_service.dart';
import 'marketplace_context_notifier.dart';
import 'profile_onboarding_repository.dart';
import 'profile_state_notifier.dart';
import 'profile_storage_service.dart';
import 'user_session_store.dart';

abstract final class DemoAuthService {
  static const demoSeekerEmail = 'demo.seeker@truecircle.dev';
  static const demoSeekerUserId = 'demo-seeker-uuid';

  static bool get isEnabled => kDebugMode;

  /// True when [session] is an in-progress demo seeker profile for this identity.
  static bool isDemoSeekerSession(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) return false;
    if (session['demo_mode'] != true) return false;
    final email = session['email']?.toString().trim().toLowerCase();
    if (email == demoSeekerEmail) return true;
    final userId = session['supabase_user_id']?.toString().trim();
    return userId == demoSeekerUserId;
  }

  static Future<void> enterAsDemoLandlord() async {
    assert(kDebugMode, 'DemoAuthService must never be called in production');
    final now = DateTime.now().toUtc().toIso8601String();
    // Role first — routing must never see a landlord session without it.
    final session = <String, dynamic>{
      UserRole.sessionKey: UserRole.landlord.storageToken,
      'email': 'demo.landlord@truecircle.dev',
      'full_name': 'Demo Landlord',
      'onboarding_intent': 'provider',
      'supabase_user_id': 'demo-landlord-uuid',
      'trust_tier': 'Sound',
      'preferred_arrangement': MarketplaceSpace.sharedSpace.arrangementBackend,
      'preferred_property_type': MarketplaceSpace.sharedSpace.towerPropertyType,
      'active_marketplace_space': MarketplaceSpace.sharedSpace.storageToken,
      'demo_mode': true,
      'demo_listing_id': DublinMockData.listingId,
      'pending_listing_eircode': 'D02 X285',
      'host_profile_complete': true,
      'profile_onboarding_track':
          ProfileOnboardingTrack.landlordSharedSpace.storageToken,
      ActiveModeService.lastActiveModeKey: ActiveMode.hosting.storageToken,
      ActiveModeService.lastModeUpdatedAtKey: now,
    };
    await _persistSession(session);
  }

  static Map<String, dynamic> demoSeekerDefaults() {
    const tcdHub = DublinCommuterHubs.tcd;
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'email': demoSeekerEmail,
      'full_name': 'Demo Seeker',
      UserRole.sessionKey: UserRole.seeker.storageToken,
      'onboarding_intent': 'seeker',
      ActiveModeService.lastActiveModeKey: ActiveMode.explore.storageToken,
      ActiveModeService.lastModeUpdatedAtKey: now,
      'supabase_user_id': demoSeekerUserId,
      'detected_city': 'Dublin',
      'mother_tongue': 'English',
      'spoken_languages': ['English'],
      'occupant_type': 'professional',
      'budget_min': 1000,
      'budget_max': 2500,
      'trust_tier': 'Just Landed',
      'commute_method': CommuteMethod.backendPublicTransportWalking,
      'maximum_commute_budget_minutes': 60,
      'preferred_arrangement': MarketplaceSpace.sharedSpace.arrangementBackend,
      'preferred_property_type': MarketplaceSpace.sharedSpace.towerPropertyType,
      'active_marketplace_space': MarketplaceSpace.sharedSpace.storageToken,
      'move_in_window': SeekerMoveInWindow.flexible.storageToken,
      'demo_mode': true,
      ...DublinCommuterHubs.persistFields(tcdHub),
    };
  }

  /// Seeds demo seeker defaults, preserving prior onboarding for this demo identity.
  @visibleForTesting
  static Map<String, dynamic> mergeDemoSeekerSession(
    Map<String, dynamic>? existing,
  ) {
    final defaults = demoSeekerDefaults();
    if (!isDemoSeekerSession(existing)) {
      return Map<String, dynamic>.from(defaults);
    }
    return {
      ...defaults,
      ...existing!,
      // Role is authoritative for routing — never inherit landlord role.
      UserRole.sessionKey: UserRole.seeker.storageToken,
      'onboarding_intent': 'seeker',
    };
  }

  static Future<void> enterAsDemoSeeker() async {
    assert(kDebugMode, 'DemoAuthService must never be called in production');
    final inMemory = AuthScreen.currentUserSession;
    final stored = inMemory == null ? await ProfileStorageService.load() : null;
    final existing = inMemory ?? stored;
    final session = mergeDemoSeekerSession(existing);
    await _persistSession(session);
  }

  static Future<void> enterAsNewSeeker() async {
    assert(kDebugMode, 'DemoAuthService must never be called in production');
    final session = <String, dynamic>{
      UserRole.sessionKey: UserRole.seeker.storageToken,
      'onboarding_intent': 'seeker',
      'supabase_user_id': 'new-seeker-uuid',
      'email': 'new.seeker@truecircle.dev',
      'demo_mode': true,
      // No name, no budget, no commute, no languages
      // This forces onboarding to run all steps
    };
    await _persistSession(session);
  }

  static Future<void> enterAsNewLandlord() async {
    assert(kDebugMode, 'DemoAuthService must never be called in production');
    final session = <String, dynamic>{
      UserRole.sessionKey: UserRole.landlord.storageToken,
      'onboarding_intent': 'provider',
      'supabase_user_id': 'new-landlord-uuid',
      'email': 'new.landlord@truecircle.dev',
      'demo_mode': true,
      // Independent Place — skip dedicated host profile; name collected on listing.
      'profile_onboarding_track':
          ProfileOnboardingTrack.landlordEntirePlace.storageToken,
      'listingSeed_listingMode': 'entire_place',
      'active_marketplace_space': MarketplaceSpace.fullRental.storageToken,
    };
    await _persistSession(session);
  }

  static Future<void> _persistSession(Map<String, dynamic> session) async {
    var next = Map<String, dynamic>.from(session);
    next = await ProfileOnboardingRepository.ensureLegacyHostTrackPersisted(next);
    UserSessionStore.current = next;
    AuthScreen.currentUserSession = next;
    profileStateNotifier.commitPersisted(next);
    await ProfileStorageService.save(next);
    await marketplaceContextNotifier.refresh();
    authSessionNotifier.refresh();
  }
}
