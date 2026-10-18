import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/services/application_service.dart';
import 'package:true_circle/services/listing_applications_service.dart';
import 'package:true_circle/services/user_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testUserId = 'user-1';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    applicationService.resetForTest();
    UserSessionStore.current = {
      'supabase_user_id': testUserId,
      'full_name': 'Test User',
    };
  });

  group('ApplicationService.applyToListing', () {
    test('creates application for valid listing', () async {
      final created = await applicationService.applyToListing(
        'listing-1',
        testUserId,
        space: MarketplaceSpace.sharedSpace,
      );

      expect(created, isTrue);
      expect(applicationService.getUserApplications(testUserId), hasLength(1));
      expect(
        applicationService.getUserApplications(testUserId).first.listingId,
        'listing-1',
      );
    });

    test('rejects empty listingId without storing', () async {
      final created = await applicationService.applyToListing('', testUserId);

      expect(created, isFalse);
      expect(applicationService.getUserApplications(testUserId), isEmpty);
    });

    test('rejects empty userId without storing', () async {
      final created = await applicationService.applyToListing('listing-1', '');

      expect(created, isFalse);
      expect(applicationService.getUserApplications(testUserId), isEmpty);
    });

    test('prevents duplicate applications for same user and listing', () async {
      expect(
        await applicationService.applyToListing('listing-1', testUserId),
        isTrue,
      );
      expect(
        await applicationService.applyToListing('listing-1', testUserId),
        isFalse,
      );
      expect(applicationService.getUserApplications(testUserId), hasLength(1));
      expect(
        applicationService.hasApplied(
          listingId: 'listing-1',
          userId: testUserId,
        ),
        isTrue,
      );
    });

    test('stores space token for space-aware filtering', () async {
      await applicationService.applyToListing(
        'listing-share',
        testUserId,
        space: MarketplaceSpace.sharedSpace,
      );

      final row = applicationService.allRows().first;
      expect(row['space'], 'shared_space');
    });

    test('concurrent apply calls only create one row', () async {
      final results = await Future.wait([
        applicationService.applyToListing('listing-race', testUserId),
        applicationService.applyToListing('listing-race', testUserId),
        applicationService.applyToListing('listing-race', testUserId),
      ]);

      expect(results.where((created) => created).length, 1);
      expect(applicationService.getUserApplications(testUserId), hasLength(1));
    });
  });

  group('ApplicationService.replaceSeekerCacheWithRemote', () {
    test('replaces that seeker and keeps other users', () async {
      await applicationService.applyToListing('listing-local', testUserId);
      await applicationService.applyToListing('listing-host', 'host-user');

      final replaced = await applicationService.replaceSeekerCacheWithRemote(
        userId: testUserId,
        remoteRows: [
          {
            'id': 'df2752d5-7b98-4eeb-bee5-1bf614c27f5f',
            'listing_id': 'listing-remote',
            'applicant_user_id': testUserId,
            'status': 'viewing_invitation_sent',
            'viewing_date': '27 Oct 2026',
            'viewing_time': '18:00',
            'viewing_location': 'dublin',
          },
        ],
      );

      expect(replaced, hasLength(1));
      expect(replaced.first['status'], 'viewing_invitation_sent');
      expect(replaced.first['viewing_date'], '27 Oct 2026');
      expect(
        applicationService.getUserApplications(testUserId),
        hasLength(1),
      );
      expect(
        applicationService.rowForListingUser(
          listingId: 'listing-remote',
          userId: testUserId,
        )?['viewing_time'],
        '18:00',
      );
      expect(
        applicationService.hasApplied(
          listingId: 'listing-local',
          userId: testUserId,
        ),
        isFalse,
      );
      expect(
        applicationService.getUserApplications('host-user'),
        hasLength(1),
      );
    });
  });

  test('apply uses local storage when Supabase is not ready', () async {
    final row = await ListingApplicationsService.submit(
      listingId: 'listing-offline',
      session: {
        'supabase_user_id': testUserId,
        'full_name': 'Test User',
      },
      space: MarketplaceSpace.sharedSpace,
      compatibilityScore: 80,
    );

    expect(row['listing_id'], 'listing-offline');
    expect(applicationService.allRows(), hasLength(1));
    expect(
      applicationService.hasApplied(
        listingId: 'listing-offline',
        userId: testUserId,
      ),
      isTrue,
    );
  });
}
