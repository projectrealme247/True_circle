import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/listing_creation_category.dart';
import 'package:true_circle/services/auth_service.dart';
import 'package:true_circle/services/local_applicant_stream_service.dart';

void main() {
  test('identityUserId prefers session supabase_user_id over empty auth', () {
    expect(
      AuthService.identityUserId({'supabase_user_id': 'demo-seeker-uuid'}),
      'demo-seeker-uuid',
    );
    expect(AuthService.identityUserId({}), '');
  });

  test('useSeededFallback only for mock listings without real applications', () {
    expect(
      LocalApplicantStreamService.useSeededFallback(
        listingId: 'mock-listing-dublin-ranelagh-shared',
        hasRealApplications: false,
      ),
      isTrue,
    );
    expect(
      LocalApplicantStreamService.useSeededFallback(
        listingId: 'mock-listing-dublin-ranelagh-shared',
        hasRealApplications: true,
      ),
      isFalse,
    );
    expect(
      LocalApplicantStreamService.useSeededFallback(
        listingId: 'owned-listing-123',
        hasRealApplications: false,
      ),
      isFalse,
    );
  });

  test('sharedStream maps local application rows to seeker name and ids', () {
    final stream = LocalApplicantStreamService.sharedStream(
      listing: {
        'id': 'owned-listing-123',
        'price': '€950 / month',
      },
      applicationRows: [
        {
          'id': 'app-1',
          'listing_id': 'owned-listing-123',
          'applicant_user_id': 'demo-seeker-uuid',
          'status': 'pending',
          'compatibility_score': 80,
          'payload': {
            'full_name': 'Demo Seeker',
            'supabase_user_id': 'demo-seeker-uuid',
          },
        },
      ],
    );

    expect(stream.totalCount, 1);
    final row = stream.flattenedApplicants.single;
    expect(row.applicationId, 'app-1');
    expect(row.applicantUserId, 'demo-seeker-uuid');
    expect(row.seekerName, 'Demo Seeker');
    expect(row.listingId, 'owned-listing-123');
  });

  test('listingWithCategory stamps marketplace_category for stream builder', () {
    final stamped = LocalApplicantStreamService.listingWithCategory(
      {'id': 'x'},
      ListingCreationCategory.sharedLiving,
    );
    expect(stamped['marketplace_category'], 'shared_living');
  });
}
