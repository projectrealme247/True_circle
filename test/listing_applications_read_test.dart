import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/services/application_service.dart';
import 'package:true_circle/services/listing_applications_service.dart';
import 'package:true_circle/services/listing_applications_supabase_service.dart';
import 'package:true_circle/services/user_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testUserId = 'user-1';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    applicationService.resetForTest();
    ListingApplicationsSupabaseService.resetDebugHooks();
    UserSessionStore.current = {
      'supabase_user_id': testUserId,
      'full_name': 'Test User',
    };
  });

  tearDown(ListingApplicationsSupabaseService.resetDebugHooks);

  test('signed-out seeker refresh keeps the local application', () async {
    await applicationService.applyToListing(
      'listing-1',
      testUserId,
      space: MarketplaceSpace.sharedSpace,
    );

    final rows = await ListingApplicationsService.refreshForCurrentSeeker();

    expect(rows, hasLength(1));
    expect(rows.single['listing_id'], 'listing-1');
  });

  test('failed seeker refresh does not return the local application', () async {
    await applicationService.applyToListing(
      'listing-1',
      testUserId,
      space: MarketplaceSpace.sharedSpace,
    );
    ListingApplicationsSupabaseService.debugIsReadyOverride = true;
    ListingApplicationsSupabaseService.debugFetchForCurrentApplicant =
        () async => throw StateError('offline');

    await expectLater(
      ListingApplicationsService.refreshForCurrentSeeker(),
      throwsA(isA<StateError>()),
    );
    expect(applicationService.getUserApplications(testUserId), hasLength(1));
  });

  test('signed-out host listing read keeps local applicants', () async {
    await applicationService.applyToListing(
      'listing-1',
      testUserId,
      space: MarketplaceSpace.fullRental,
    );

    final rows = await ListingApplicationsService.forListing('listing-1');

    expect(rows, hasLength(1));
  });

  test('failed host listing read does not return local applicants', () async {
    await applicationService.applyToListing(
      'listing-1',
      testUserId,
      space: MarketplaceSpace.fullRental,
    );
    ListingApplicationsSupabaseService.debugIsReadyOverride = true;
    ListingApplicationsSupabaseService.debugFetchForListing =
        (_) async => throw StateError('offline');

    await expectLater(
      ListingApplicationsService.forListing('listing-1'),
      throwsA(isA<StateError>()),
    );
    expect(applicationService.rowsForListing('listing-1'), hasLength(1));
  });

  test('failed listing-detail read does not return the local row', () async {
    await applicationService.applyToListing(
      'listing-1',
      testUserId,
      space: MarketplaceSpace.sharedSpace,
    );
    ListingApplicationsSupabaseService.debugIsReadyOverride = true;
    ListingApplicationsSupabaseService.debugFetchForListingUser =
        ({required String listingId, required String applicantUserId}) async {
      throw StateError('offline');
    };

    await expectLater(
      ListingApplicationsService.forListingUser(
        listingId: 'listing-1',
        applicantUserId: testUserId,
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      applicationService.rowForListingUser(
        listingId: 'listing-1',
        userId: testUserId,
      ),
      isNotNull,
    );
  });

  test('confirmed missing remote application drops the stale local row', () async {
    await applicationService.applyToListing(
      'listing-1',
      testUserId,
      space: MarketplaceSpace.sharedSpace,
    );
    ListingApplicationsSupabaseService.debugIsReadyOverride = true;
    ListingApplicationsSupabaseService.debugFetchForListingUser =
        ({required String listingId, required String applicantUserId}) async =>
            null;

    final row = await ListingApplicationsService.forListingUser(
      listingId: 'listing-1',
      applicantUserId: testUserId,
    );

    expect(row, isNull);
    expect(
      applicationService.rowForListingUser(
        listingId: 'listing-1',
        userId: testUserId,
      ),
      isNull,
    );
  });
}
