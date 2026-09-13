import '../controllers/applicant_management_controller.dart';
import '../models/independent_places_applicant_stream.dart';
import '../models/listing_creation_field_keys.dart';
import '../models/shared_living_applicant_stream.dart';

/// High-fidelity synthetic applicants for Phase C Step 3 stream visual testing.
abstract final class MockApplicantSeeder {
  MockApplicantSeeder._();

  static const sharedListingId = 'mock-listing-shared-dublin';
  static const independentListingId = 'mock-listing-independent-dublin';

  static IndependentPlacesApplicantStream independentPlacesStream({
    String listingId = independentListingId,
    bool dense = false,
  }) {
    final rows = dense
        ? _denseIndependentRows(listingId)
        : [
            _soundTechWorkerIndependent(),
            _grandConstructionIndependent(),
            _justLandedStudentIndependent(),
          ];
    return ApplicantManagementController.buildIndependentPlacesStream(
      listing: {
        'id': listingId,
        ListingCreationFieldKeys.marketplaceCategory: 'independent_places',
        'price': '€2,150 / month',
        'bedrooms': '2 bed',
        'available_from': '2026-08-01',
        'availability_flexibility': 'plus_1_month',
        'metadata': {
          'target_move_in_date': '2026-08-01',
          'lease_term_months': 12,
        },
        'lease_term_months': 12,
        'pets_allowed': false,
      },
      applicationRows: rows,
      trustProfilesByUserId: _trustProfiles,
    );
  }

  static SharedLivingApplicantStream sharedLivingStream({
    String listingId = sharedListingId,
    bool dense = false,
  }) {
    final rows = dense
        ? _denseSharedRows(listingId)
        : [
            _soundTechWorkerShared(),
            _grandConstructionShared(),
            _justLandedStudentShared(),
          ];
    return ApplicantManagementController.buildSharedLivingStream(
      listing: {
        'id': listingId,
        ListingCreationFieldKeys.marketplaceCategory: 'shared_living',
        'price': '€950 / month',
        ListingCreationFieldKeys.languagesSpoken: ['English', 'Spanish', 'Polish'],
        ListingCreationFieldKeys.kitchenCulture: 'veg_friendly',
        ListingCreationFieldKeys.householdDynamic: 'professionals',
        'smoking_allowed': false,
        'pets_allowed': false,
        'available_from': '2026-08-01',
        'availability_flexibility': 'plus_1_month',
      },
      applicationRows: rows,
      trustProfilesByUserId: _trustProfiles,
    );
  }

  /// Synthetic host listings for landlord dashboard visual testing.
  static List<Map<String, dynamic>> demoHostListings() => [
        {
          'id': sharedListingId,
          'title': 'Smithfield Shared Flat · Room 2',
          ListingCreationFieldKeys.marketplaceCategory: 'shared_living',
          'property_type': 'Share',
          'location': 'Smithfield, Dublin 7',
          'price': '€950 / month',
          ListingCreationFieldKeys.languagesSpoken: [
            'English',
            'Spanish',
            'Polish',
          ],
          ListingCreationFieldKeys.kitchenCulture: 'veg_friendly',
          'smoking_allowed': false,
          'pets_allowed': false,
          'available_from': '2026-08-01',
          'availability_flexibility': 'plus_1_month',
        },
        {
          'id': independentListingId,
          'title': 'Portobello Entire Home',
          ListingCreationFieldKeys.marketplaceCategory: 'independent_places',
          'property_type': 'Rent',
          'location': 'Portobello, Dublin 8',
          'price': '€2,150 / month',
          'bedrooms': '2 bed',
          'available_from': '2026-08-01',
          'availability_flexibility': 'plus_1_month',
          'lease_term_months': 12,
          'pets_allowed': false,
        },
      ];

  static List<Map<String, dynamic>> _denseSharedRows(String listingId) {
    final templates = [
      _soundTechWorkerShared(),
      _grandConstructionShared(),
      _justLandedStudentShared(),
    ];
    final names = [
      'Sofia Reyes',
      'Marek Kowalski',
      'Ananya Reddy',
      'Liam O\'Brien',
      'Priya Nair',
      'Carlos Mendez',
    ];
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < 15; i++) {
      final template = Map<String, dynamic>.from(templates[i % templates.length]);
      final payload = Map<String, dynamic>.from(
        template['payload'] as Map<String, dynamic>,
      );
      payload['full_name'] = names[i % names.length];
      rows.add({
        ...template,
        'id': 'mock-app-shared-$i',
        'listing_id': listingId,
        'applicant_user_id': 'mock-user-${i % 3 == 0 ? 'sound' : i % 3 == 1 ? 'grand' : 'just-landed'}',
        'compatibility_score': 58 + (i * 3) % 40,
        'payload': payload,
      });
    }
    return rows;
  }

  static List<Map<String, dynamic>> _denseIndependentRows(String listingId) {
    final templates = [
      _soundTechWorkerIndependent(),
      _grandConstructionIndependent(),
      _justLandedStudentIndependent(),
    ];
    final names = [
      'Sofia Reyes',
      'Marek Kowalski',
      'Ananya Reddy',
      'Niamh Walsh',
      'Tomás Silva',
      'Elena Popescu',
    ];
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < 14; i++) {
      final template =
          Map<String, dynamic>.from(templates[i % templates.length]);
      final payload = Map<String, dynamic>.from(
        template['payload'] as Map<String, dynamic>,
      );
      payload['full_name'] = names[i % names.length];
      if (i == 0) {
        payload['earliest_move_in_date'] = '2026-08-01';
      }
      rows.add({
        ...template,
        'id': 'mock-app-independent-$i',
        'listing_id': listingId,
        'applicant_user_id':
            'mock-user-${i % 3 == 0 ? 'sound' : i % 3 == 1 ? 'grand' : 'just-landed'}',
        'compatibility_score': 55 + (i * 4) % 42,
        'payload': payload,
      });
    }
    return rows;
  }

  static final Map<String, Map<String, dynamic>> _trustProfiles = {
    'mock-user-sound': {
      'full_name': 'Sofia Reyes',
      'trust_tier': 'Sound',
      'trust_stage': 3,
      'employment_verified': true,
      'verification_track': 'Open Banking Track',
      'financial_verified': true,
    },
    'mock-user-grand': {
      'full_name': 'Marek Kowalski',
      'trust_tier': 'Grand',
      'trust_stage': 2,
      'employment_verified': true,
      'verification_track': 'Corporate Track',
      'corporate_verification_seal': 'sealed-mock',
    },
    'mock-user-just-landed': {
      'full_name': 'Ananya Reddy',
      'trust_tier': 'Just Landed',
      'trust_stage': 1,
      'employment_verified': false,
      'financial_verified': false,
    },
  };

  static Map<String, dynamic> _soundTechWorkerShared() => {
        'id': 'mock-app-sound-shared',
        'listing_id': sharedListingId,
        'applicant_user_id': 'mock-user-sound',
        'status': 'pending',
        'compatibility_score': 88,
        'created_at': '2026-06-22T09:15:00.000Z',
        'payload': {
          'full_name': 'Sofia Reyes',
          'pitch_narrative':
              'Returning to Dublin after five years in Barcelona. '
              'Quiet tech professional seeking a veg-friendly shared home.',
          'food_preference': 'vegetarian',
          'spoken_language_entries': [
            {'language': 'English', 'is_native': false},
            {'language': 'Spanish', 'is_native': true},
          ],
          'spoken_languages': ['English', 'Spanish'],
          'mother_tongue': 'Spanish',
          'schedule_type': 'office_hours',
          'smoking_ok': false,
          'household_has_pets': false,
          'move_in_window': 'next_month',
          'preferred_layout': 'Single / Private Room',
          'preferred_arrangement': 'shared',
          'preferred_property_type': 'Share',
          'seeker_persona': 'professional',
          'occupant_type': 'Working Professionals',
          'group_size': 1,
          'net_monthly_income': 4200,
          'affordability_multiplier': 4.4,
        },
      };

  static Map<String, dynamic> _grandConstructionShared() => {
        'id': 'mock-app-grand-shared',
        'listing_id': sharedListingId,
        'applicant_user_id': 'mock-user-grand',
        'status': 'viewing_scheduled',
        'compatibility_score': 72,
        'created_at': '2026-06-21T14:40:00.000Z',
        'payload': {
          'full_name': 'Marek Kowalski',
          'pitch_narrative':
              'Construction supervisor relocating within Dublin. '
              'Early riser, respectful housemate.',
          'food_preference': 'non-veg',
          'spoken_language_entries': [
            {'language': 'Polish', 'is_native': true},
            {'language': 'English', 'is_native': false},
          ],
          'spoken_languages': ['Polish', 'English'],
          'mother_tongue': 'Polish',
          'smoking_ok': false,
          'household_has_pets': false,
          'move_in_window': 'this_month',
          'preferred_layout': 'Ensuite Room',
          'preferred_arrangement': 'shared',
          'preferred_property_type': 'Share',
          'seeker_persona': 'professional',
          'occupant_type': 'Working Professionals',
          'group_size': 1,
          'net_monthly_income': 3800,
        },
      };

  static Map<String, dynamic> _justLandedStudentShared() => {
        'id': 'mock-app-just-shared',
        'listing_id': sharedListingId,
        'applicant_user_id': 'mock-user-just-landed',
        'status': 'pending',
        'compatibility_score': 61,
        'created_at': '2026-06-20T18:05:00.000Z',
        'payload': {
          'full_name': 'Ananya Reddy',
          'pitch_narrative':
              'Incoming MSc student at UCD. Friendly, tidy, and excited '
              'to join a multicultural household.',
          'food_preference': 'vegetarian',
          'spoken_language_entries': [
            {'language': 'Telugu', 'is_native': true},
            {'language': 'Hindi', 'is_native': false},
            {'language': 'English', 'is_native': false},
          ],
          'spoken_languages': ['Telugu', 'Hindi', 'English'],
          'mother_tongue': 'Telugu',
          'student_type': 'postgraduate',
          'smoking_ok': false,
          'household_has_pets': false,
          'move_in_window': 'within_3_months',
          'preferred_layout': 'Single / Private Room',
          'preferred_arrangement': 'shared',
          'preferred_property_type': 'Share',
          'seeker_persona': 'student',
          'occupant_type': 'Students',
          'group_size': 1,
          'guarantor_status': 'yes',
          'has_guarantor': true,
          'net_monthly_income': 1400,
        },
      };

  static Map<String, dynamic> _soundTechWorkerIndependent() => {
        'id': 'mock-app-sound-independent',
        'listing_id': independentListingId,
        'applicant_user_id': 'mock-user-sound',
        'status': 'pending',
        'compatibility_score': 91,
        'created_at': '2026-06-22T09:20:00.000Z',
        'payload': {
          'full_name': 'Sofia Reyes',
          'pitch_narrative':
              'Product designer returning to Dublin. Seeking a 12-month '
              'lease with August move-in.',
          'preferred_lease_months': 12,
          'earliest_move_in_date': '2026-08-03',
          'move_in_window': 'next_month',
          'budget_min': 1900,
          'budget_max': 2400,
          'spoken_languages': ['English', 'Spanish'],
          'mother_tongue': 'Spanish',
          'preferred_layout': '2 Bed',
          'preferred_arrangement': 'full_rent',
          'preferred_property_type': 'Rent',
          'seeker_persona': 'professional',
          'occupant_type': 'Working Professionals',
          'group_size': 2,
          'family_adults': 2,
          'family_children': 0,
          'household_has_pets': false,
          'net_monthly_income': 4800,
          'partner_net_monthly_income': 3200,
          'affordability_multiplier': 3.7,
        },
      };

  static Map<String, dynamic> _grandConstructionIndependent() => {
        'id': 'mock-app-grand-independent',
        'listing_id': independentListingId,
        'applicant_user_id': 'mock-user-grand',
        'status': 'viewing_scheduled',
        'compatibility_score': 84,
        'created_at': '2026-06-21T15:00:00.000Z',
        'payload': {
          'full_name': 'Marek Kowalski',
          'pitch_narrative':
              'Verified construction supervisor with stable income. '
              'Looking for an entire place near city projects.',
          'preferred_lease_months': 12,
          'earliest_move_in_date': '2026-07-28',
          'move_in_window': 'this_month',
          'budget_min': 1800,
          'budget_max': 2300,
          'spoken_languages': ['Polish', 'English'],
          'mother_tongue': 'Polish',
          'preferred_layout': '1 Bed',
          'preferred_arrangement': 'full_rent',
          'preferred_property_type': 'Rent',
          'seeker_persona': 'professional',
          'occupant_type': 'Working Professionals',
          'group_size': 1,
          'household_has_pets': false,
          'net_monthly_income': 5100,
        },
      };

  static Map<String, dynamic> _justLandedStudentIndependent() => {
        'id': 'mock-app-just-independent',
        'listing_id': independentListingId,
        'applicant_user_id': 'mock-user-just-landed',
        'status': 'pending',
        'compatibility_score': 58,
        'created_at': '2026-06-20T18:10:00.000Z',
        'payload': {
          'full_name': 'Ananya Reddy',
          'pitch_narrative':
              'Postgraduate arrival in September. Budget-conscious but '
              'reliable tenant with university references.',
          'preferred_lease_months': 9,
          'earliest_move_in_date': '2026-09-01',
          'move_in_window': 'within_3_months',
          'budget_min': 1200,
          'budget_max': 1700,
          'spoken_languages': ['Telugu', 'Hindi', 'English'],
          'mother_tongue': 'Telugu',
          'preferred_layout': 'Studio',
          'preferred_arrangement': 'full_rent',
          'preferred_property_type': 'Rent',
          'seeker_persona': 'student',
          'occupant_type': 'Students',
          'group_size': 1,
          'guarantor_status': 'yes',
          'has_guarantor': true,
          'household_has_pets': false,
          'net_monthly_income': 1600,
        },
      };
}
