import '../config/app_env.dart';
import '../config/market/dublin_commuter_hubs.dart';
import '../data/dublin_mock_data.dart';
import '../models/marketplace_space.dart';
import '../screens/auth_screen.dart';
import 'commute_scoring_service.dart';
import 'marketplace_context_notifier.dart';
import 'profile_storage_service.dart';
import 'user_session_store.dart';

abstract final class DemoAuthService {
  static bool get isEnabled => AppEnv.demoAuthBypass;

  static Future<void> enterAsDemoLandlord() async {
    final session = <String, dynamic>{
      'email': 'demo.landlord@truecircle.dev',
      'full_name': 'Demo Landlord',
      'role': 'host',
      'supabase_user_id': 'demo-landlord-uuid',
      'trust_tier': 'Sound',
      'trust_stage': 3,
      'identity_trust_tier': 'Corporate_Ready',
      'preferred_arrangement': MarketplaceSpace.sharedSpace.arrangementBackend,
      'preferred_property_type': MarketplaceSpace.sharedSpace.towerPropertyType,
      'active_marketplace_space': MarketplaceSpace.sharedSpace.storageToken,
      'demo_mode': true,
      'demo_listing_id': DublinMockData.listingId,
    };
    await _persistSession(session);
  }

  static Future<void> enterAsDemoSeeker() async {
    const tcdHub = DublinCommuterHubs.tcd;
    final session = <String, dynamic>{
      'email': 'demo.seeker@truecircle.dev',
      'full_name': 'Demo Seeker',
      'role': 'seeker',
      'supabase_user_id': 'demo-seeker-uuid',
      'detected_city': 'Dublin',
      'mother_tongue': 'English',
      'spoken_languages': ['English'],
      'trust_tier': 'Just Landed',
      'trust_stage': 1,
      'identity_trust_tier': 'Casual_Browser',
      'commute_method': CommuteMethod.backendPublicTransportWalking,
      'maximum_commute_budget_minutes': 45,
      'preferred_arrangement': MarketplaceSpace.sharedSpace.arrangementBackend,
      'preferred_property_type': MarketplaceSpace.sharedSpace.towerPropertyType,
      'active_marketplace_space': MarketplaceSpace.sharedSpace.storageToken,
      'demo_mode': true,
      ...DublinCommuterHubs.persistFields(tcdHub),
    };
    await _persistSession(session);
  }

  static Future<void> _persistSession(Map<String, dynamic> session) async {
    final next = Map<String, dynamic>.from(session);
    UserSessionStore.current = next;
    AuthScreen.currentUserSession = next;
    await ProfileStorageService.save(next);
    await marketplaceContextNotifier.refresh();
  }
}
