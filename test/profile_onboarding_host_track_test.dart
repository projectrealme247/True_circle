import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/models/profile_onboarding_models.dart';
import 'package:true_circle/services/profile_onboarding_repository.dart';
import 'package:true_circle/services/profile_portal_inheritance_service.dart';
import 'package:true_circle/services/profile_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProfileStorageService.clear();
  });

  group('ProfileOnboardingRepository.resolveHostTrack', () {
    test('explicit landlord track wins over shared arrangement residue', () {
      final track = ProfileOnboardingRepository.resolveHostTrack({
        'profile_onboarding_track':
            ProfileOnboardingTrack.landlordEntirePlace.storageToken,
        'preferred_arrangement': 'shared',
        'active_marketplace_space': MarketplaceSpace.sharedSpace.storageToken,
      });

      expect(track, ProfileOnboardingTrack.landlordEntirePlace);
    });

    test('active_marketplace_space used when track absent', () {
      final track = ProfileOnboardingRepository.resolveHostTrack({
        'onboarding_intent': 'provider',
        'host_profile_complete': true,
        'preferred_arrangement': 'shared',
        'active_marketplace_space': MarketplaceSpace.sharedSpace.storageToken,
      });

      expect(track, ProfileOnboardingTrack.landlordSharedSpace);
    });

    test('ignores preferred_arrangement when track and space absent', () {
      final track = ProfileOnboardingRepository.resolveHostTrack({
        'onboarding_intent': 'provider',
        'preferred_arrangement': 'shared',
      });

      expect(track, ProfileOnboardingTrack.landlordEntirePlace);
    });

    test('listingSeed_listingMode used before default', () {
      final track = ProfileOnboardingRepository.resolveHostTrack({
        'onboarding_intent': 'provider',
        'listingSeed_listingMode': 'shared_space',
      });

      expect(track, ProfileOnboardingTrack.landlordSharedSpace);
    });
  });

  group('Host Profile UI matches listing inheritance', () {
    test('demo-style legacy host session resolves consistently', () {
      final session = {
        'email': 'demo.landlord@truecircle.dev',
        'onboarding_intent': 'provider',
        'host_profile_complete': true,
        'preferred_arrangement': MarketplaceSpace.sharedSpace.arrangementBackend,
        'active_marketplace_space': MarketplaceSpace.sharedSpace.storageToken,
        'profile_onboarding_track':
            ProfileOnboardingTrack.landlordSharedSpace.storageToken,
      };

      final hostTrack = ProfileOnboardingRepository.resolveHostTrack(session);
      final snapshot =
          ProfileOnboardingRepository.snapshotFromSession(session);
      final prefill =
          ProfilePortalInheritanceService.listingPrefill(snapshot).toDraftMap();

      expect(hostTrack, ProfileOnboardingTrack.landlordSharedSpace);
      expect(snapshot.track, hostTrack);
      expect(prefill['prefill_listing_mode'], 'shared_space');
      expect(prefill['type'], 'Share');
    });

    test('new host without track defaults to entire place everywhere', () {
      final session = {
        'onboarding_intent': 'provider',
      };

      final hostTrack = ProfileOnboardingRepository.resolveHostTrack(session);
      final snapshot =
          ProfileOnboardingRepository.snapshotFromSession(session);
      final prefill =
          ProfilePortalInheritanceService.listingPrefill(snapshot).toDraftMap();

      expect(hostTrack, ProfileOnboardingTrack.landlordEntirePlace);
      expect(snapshot.track, hostTrack);
      expect(prefill['prefill_listing_mode'], 'entire_place');
      expect(prefill['type'], 'Rent');
    });
  });

  group('ensureLegacyHostTrackPersisted', () {
    test('persists derived track once for legacy host sessions', () async {
      final legacy = {
        'email': 'host@example.com',
        'onboarding_intent': 'provider',
        'host_profile_complete': true,
        'active_marketplace_space': MarketplaceSpace.sharedSpace.storageToken,
        'preferred_arrangement': 'shared',
      };

      final migrated =
          await ProfileOnboardingRepository.ensureLegacyHostTrackPersisted(legacy);

      expect(
        migrated['profile_onboarding_track'],
        ProfileOnboardingTrack.landlordSharedSpace.storageToken,
      );

      final stored = await ProfileStorageService.load();
      expect(
        stored?['profile_onboarding_track'],
        ProfileOnboardingTrack.landlordSharedSpace.storageToken,
      );

      final again =
          await ProfileOnboardingRepository.ensureLegacyHostTrackPersisted(migrated);
      expect(again['profile_onboarding_track'], migrated['profile_onboarding_track']);
    });

    test('skips when track already present', () async {
      final session = {
        'host_profile_complete': true,
        'profile_onboarding_track':
            ProfileOnboardingTrack.landlordEntirePlace.storageToken,
        'active_marketplace_space': MarketplaceSpace.sharedSpace.storageToken,
      };

      final result =
          await ProfileOnboardingRepository.ensureLegacyHostTrackPersisted(session);

      expect(result, same(session));
      expect(await ProfileStorageService.load(), isNull);
    });
  });
}
