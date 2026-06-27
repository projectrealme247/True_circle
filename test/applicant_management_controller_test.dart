import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/controllers/applicant_management_controller.dart';
import 'package:true_circle/models/applicant_application_status.dart';
import 'package:true_circle/models/applicant_trust_tier.dart';
import 'package:true_circle/models/independent_places_applicant_stream.dart';
import 'package:true_circle/models/listing_creation_category.dart';
import 'package:true_circle/models/listing_creation_field_keys.dart';
import 'package:true_circle/models/shared_living_applicant_stream.dart';
import 'package:true_circle/services/applicant_management_supabase_service.dart';
import 'package:true_circle/services/applicant_stream_payload_builder.dart';

void main() {
  group('ApplicantApplicationStatus', () {
    test('maps legacy SQL tokens to Phase C matrix', () {
      expect(
        ApplicantApplicationStatus.parse('submitted'),
        ApplicantApplicationStatus.pending,
      );
      expect(
        ApplicantApplicationStatus.parse('viewed'),
        ApplicantApplicationStatus.viewingScheduled,
      );
      expect(
        ApplicantApplicationStatus.parse('shortlisted'),
        ApplicantApplicationStatus.accepted,
      );
    });
  });

  group('ApplicantStatusTransitionService', () {
    test('allows pending to viewing, accept, or decline', () {
      expect(
        ApplicantManagementController.validateStatusTransition(
          from: ApplicantApplicationStatus.pending,
          to: ApplicantApplicationStatus.viewingScheduled,
        ),
        isNull,
      );
      expect(
        ApplicantManagementController.validateStatusTransition(
          from: ApplicantApplicationStatus.pending,
          to: ApplicantApplicationStatus.accepted,
        ),
        isNull,
      );
    });

    test('blocks terminal transitions', () {
      expect(
        ApplicantManagementController.validateStatusTransition(
          from: ApplicantApplicationStatus.accepted,
          to: ApplicantApplicationStatus.pending,
        ),
        isNotNull,
      );
      expect(
        ApplicantManagementController.validateStatusTransition(
          from: ApplicantApplicationStatus.declined,
          to: ApplicantApplicationStatus.viewingScheduled,
        ),
        isNotNull,
      );
    });
  });

  group('SharedLivingApplicantStream', () {
    test('groups by trust tier and sorts by lifestyle score within block', () {
      final listing = {
        'id': 'listing-1',
        ListingCreationFieldKeys.marketplaceCategory: 'shared_living',
        ListingCreationFieldKeys.languagesSpoken: ['English', 'Polish'],
        ListingCreationFieldKeys.kitchenCulture: 'veg_friendly',
      };

      final stream = ApplicantManagementController.buildSharedLivingStream(
        listing: listing,
        applicationRows: [
          {
            'id': 'app-low',
            'listing_id': 'listing-1',
            'applicant_user_id': 'user-a',
            'status': 'pending',
            'compatibility_score': 40,
            'created_at': '2026-06-20T10:00:00.000Z',
            'payload': {
              'full_name': 'Alex',
              'pitch_narrative': 'Quiet professional.',
              'spoken_languages': ['French'],
              'food_preference': 'non-veg',
            },
          },
          {
            'id': 'app-high',
            'listing_id': 'listing-1',
            'applicant_user_id': 'user-b',
            'status': 'pending',
            'compatibility_score': 55,
            'created_at': '2026-06-21T10:00:00.000Z',
            'payload': {
              'full_name': 'Blake',
              'bio': 'Vegetarian, Polish speaker.',
              'spoken_languages': ['english', ' Polish '],
              'food_preference': 'vegetarian',
            },
          },
          {
            'id': 'app-sound',
            'listing_id': 'listing-1',
            'applicant_user_id': 'user-c',
            'status': 'pending',
            'compatibility_score': 80,
            'created_at': '2026-06-22T10:00:00.000Z',
            'payload': {
              'full_name': 'Casey',
              'pitch_narrative': 'Sound tier lead.',
              'spoken_languages': ['English'],
              'food_preference': 'vegetarian',
            },
          },
        ],
        trustProfilesByUserId: {
          'user-a': {
            'full_name': 'Alex',
            'trust_tier': 'Just Landed',
            'trust_stage': 1,
          },
          'user-b': {
            'full_name': 'Blake',
            'trust_tier': 'Grand',
            'trust_stage': 2,
          },
          'user-c': {
            'full_name': 'Casey',
            'trust_tier': 'Sound',
            'trust_stage': 3,
          },
        },
      );

      expect(stream.displayLabel, SharedLivingApplicantStream.categoryDisplayLabel);
      expect(stream.marketplaceCategory, 'shared_living');
      expect(stream.blocks.first.trustTier, ApplicantTrustTier.sound);
      expect(stream.blocks.first.applicants.first.seekerName, 'Casey');

      final grandBlock = stream.blocks
          .firstWhere((b) => b.trustTier == ApplicantTrustTier.grand);
      expect(grandBlock.applicants.first.seekerName, 'Blake');
      expect(grandBlock.applicants.first.customBioPitch, contains('Vegetarian'));
      expect(grandBlock.applicants.first.kitchenCultureAligned, isTrue);
      expect(
        grandBlock.applicants.first.languageAlignmentOverlap,
        contains('Polish'),
      );
      expect(grandBlock.applicants.first.seekerLanguages, ['English', 'Polish']);
    });

    test('rejects wrong marketplace_category', () {
      expect(
        () => ApplicantStreamPayloadBuilder.buildSharedLivingStream(
          listing: {
            'id': 'x',
            ListingCreationFieldKeys.marketplaceCategory: 'independent_places',
          },
          applicationRows: const [],
          trustProfilesByUserId: const {},
        ),
        throwsA(
          predicate(
            (e) =>
                e is ApplicantManagementException &&
                e.code == ApplicantManagementErrorCode.categoryMismatch,
          ),
        ),
      );
    });

    test('strips deprecated kitchen utility keys from payload', () {
      final stream = ApplicantManagementController.buildSharedLivingStream(
        listing: {
          'id': 'listing-utility',
          ListingCreationFieldKeys.marketplaceCategory: 'shared_living',
          ListingCreationFieldKeys.languagesSpoken: ['English'],
          ListingCreationFieldKeys.kitchenCulture: 'open',
        },
        applicationRows: [
          {
            'id': 'app-1',
            'listing_id': 'listing-utility',
            'applicant_user_id': 'user-1',
            'status': 'pending',
            'compatibility_score': 10,
            'created_at': '2026-06-20T10:00:00.000Z',
            'payload': {
              'full_name': 'Sam',
              'spoken_languages': ['English'],
              ListingCreationFieldKeys.forbiddenKeys.first: 'deprecated',
            },
          },
        ],
        trustProfilesByUserId: const {},
      );

      expect(stream.totalCount, 1);
      expect(
        stream.flattenedApplicants.first.seekerLanguages,
        ['English'],
      );
    });
  });

  group('IndependentPlacesApplicantStream', () {
    test('groups by trust tier and sorts by timeline variance then lease', () {
      final listing = {
        'id': 'listing-2',
        ListingCreationFieldKeys.marketplaceCategory: 'independent_places',
        'price': '€2,000 / month',
        'metadata': {
          'target_move_in_date': '2026-07-01',
          'lease_term_months': 12,
        },
      };

      final stream = ApplicantManagementController.buildIndependentPlacesStream(
        listing: listing,
        applicationRows: [
          {
            'id': 'app-weak',
            'listing_id': 'listing-2',
            'applicant_user_id': 'user-c',
            'status': 'pending',
            'compatibility_score': 30,
            'created_at': '2026-06-19T10:00:00.000Z',
            'payload': {
              'full_name': 'Casey',
              'preferred_lease_months': 3,
              'earliest_move_in_date': '2026-09-01',
            },
          },
          {
            'id': 'app-strong',
            'listing_id': 'listing-2',
            'applicant_user_id': 'user-d',
            'status': 'pending',
            'compatibility_score': 70,
            'created_at': '2026-06-18T10:00:00.000Z',
            'payload': {
              'full_name': 'Dana',
              'pitch_narrative': '12-month lease, ready in July.',
              'preferred_lease_months': 12,
              'earliest_move_in_date': '2026-07-05',
            },
          },
        ],
        trustProfilesByUserId: {
          'user-d': {
            'full_name': 'Dana',
            'trust_tier': 'Sound',
            'trust_stage': 3,
            'employment_verified': true,
            'verification_track': 'Corporate Track',
            'corporate_verification_seal': 'sealed',
          },
        },
      );

      expect(
        stream.displayLabel,
        IndependentPlacesApplicantStream.categoryDisplayLabel,
      );
      expect(stream.marketplaceCategory, 'independent_places');
      expect(stream.blocks.first.trustTier, ApplicantTrustTier.sound);
      final dana = stream.blocks.first.applicants.first;
      expect(dana.seekerName, 'Dana');
      expect(dana.moveInTimelineMatch, isTrue);
      expect(dana.leaseTermMatch, isTrue);
      expect(dana.employmentVerified, isTrue);
      expect(dana.corporateDocumentVerified, isTrue);
      expect(dana.preferredLeaseMonths, 12);
    });

    test('rejects shared_living category', () {
      expect(
        () => ApplicantStreamPayloadBuilder.buildIndependentPlacesStream(
          listing: {
            'id': 'x',
            ListingCreationFieldKeys.marketplaceCategory: 'shared_living',
          },
          applicationRows: const [],
          trustProfilesByUserId: const {},
        ),
        throwsA(
          predicate(
            (e) =>
                e is ApplicantManagementException &&
                e.code == ApplicantManagementErrorCode.categoryMismatch,
          ),
        ),
      );
    });
  });

  group('ApplicantDashboardPayloadBuilder via controller', () {
    test('legacy dashboard build still works with explicit category', () {
      final dashboard = ApplicantManagementController.buildDashboard(
        listing: {
          'id': 'listing-2',
          ListingCreationFieldKeys.marketplaceCategory: 'independent_places',
          'price': '€2,000 / month',
          'listing_type': 'Rent',
        },
        applicationRows: const [],
        trustProfilesByUserId: const {},
      );

      expect(dashboard.category, ListingCreationCategory.independentPlaces);
    });
  });

  group('ApplicantManagementController mutations', () {
    test('scheduleViewing delegates to update override', () async {
      ApplicantApplicationStatus? capturedStatus;

      await ApplicantManagementController.scheduleViewing(
        applicationId: 'app-1',
        currentStatus: ApplicantApplicationStatus.pending,
        updateOverride: ({
          required String applicationId,
          required ApplicantApplicationStatus nextStatus,
          ApplicantApplicationStatus? currentStatus,
        }) async {
          capturedStatus = nextStatus;
          return {'id': applicationId, 'status': nextStatus.storageToken};
        },
      );

      expect(capturedStatus, ApplicantApplicationStatus.viewingScheduled);
    });
  });
}
