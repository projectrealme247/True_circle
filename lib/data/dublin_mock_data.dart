import 'package:flutter/foundation.dart';

import '../models/high_signal_match.dart';
import '../models/listing_creation_field_keys.dart';
import '../models/shared_living_applicant_stream.dart';
import '../services/applicant_stream_payload_builder.dart';

/// Dublin 6 Ranelagh shared-flat demo harness for landlord dashboard visual QA.
abstract final class DublinMockData {
  DublinMockData._();

  static const listingId = 'mock-listing-dublin-ranelagh-shared';

  /// Injects the Ranelagh harness when the host has no owned listings (debug by default).
  static bool get useMockHarness => kDebugMode;

  static bool isHarnessListing(String id) => id == listingId;

  static Map<String, dynamic> sharedFlatListing() => {
        'id': listingId,
        'title': 'Room in Shared Flat · 3 Bed Apartment, Ranelagh',
        ListingCreationFieldKeys.marketplaceCategory: 'shared_living',
        'property_type': 'Share',
        'listing_type': 'Share',
        'location': 'Dublin 6, Ranelagh (near Luas Green Line)',
        'price': '€1,100 / month',
        ListingCreationFieldKeys.bedsCount: 3,
        ListingCreationFieldKeys.roomType: 'shared',
        ListingCreationFieldKeys.householdDynamic: 'open',
        ListingCreationFieldKeys.kitchenCulture: 'open',
        ListingCreationFieldKeys.languagesSpoken: ['English', 'Spanish'],
        'cohort_type': 'open_mixed',
        'schedule_type': 'office_hours',
        'status': 'active',
        'metadata': {
          'setup_label': '3 Bed Apartment, Ranelagh',
          'transit_note': 'Luas Green Line · Ranelagh stop',
          'available_from': '2026-09-01',
        },
      };

  static SharedLivingApplicantStream applicantStream() {
    return _buildStreamFromRows(_applicationRows);
  }

  /// Hardcoded 9-applicant harness when runtime stream resolution returns empty.
  static SharedLivingApplicantStream fallbackApplicantStream() {
    return _buildStreamFromRows(List<Map<String, dynamic>>.from(_applicationRows));
  }

  static SharedLivingApplicantStream resolveApplicantStream() {
    final primary = applicantStream();
    if (primary.totalCount > 0) return primary;
    return fallbackApplicantStream();
  }

  static const demoApplicantTargetCount = 9;

  static SharedLivingApplicantStream _buildStreamFromRows(
    List<Map<String, dynamic>> rows,
  ) {
    return ApplicantStreamPayloadBuilder.buildSharedLivingStream(
      listing: sharedFlatListing(),
      applicationRows: rows,
      trustProfilesByUserId: _trustProfiles,
      highSignalMatchesByApplicationId: highSignalMatchesByApplicationId(),
    );
  }

  static Map<String, HighSignalMatch> highSignalMatchesByApplicationId() {
    final matches = highSignalMatches();
    return HighSignalMatch.indexByApplicationId(matches);
  }

  static List<HighSignalMatch> highSignalMatches() => [
        const HighSignalMatch(
          applicationId: 'dublin-mock-app-mark',
          applicantUserId: 'dublin-mock-user-mark',
          overallMatchScore: 91,
          verifiedTransitDurationSeconds: 1680,
        ),
        const HighSignalMatch(
          applicationId: 'dublin-mock-app-niamh',
          applicantUserId: 'dublin-mock-user-niamh',
          overallMatchScore: 88,
          verifiedTransitDurationSeconds: 1740,
        ),
        const HighSignalMatch(
          applicationId: 'dublin-mock-app-luke',
          applicantUserId: 'dublin-mock-user-luke',
          overallMatchScore: 86,
          verifiedTransitDurationSeconds: 1860,
        ),
        const HighSignalMatch(
          applicationId: 'dublin-mock-app-chloe',
          applicantUserId: 'dublin-mock-user-chloe',
          overallMatchScore: 82,
          verifiedTransitDurationSeconds: 2100,
        ),
        const HighSignalMatch(
          applicationId: 'dublin-mock-app-sofia',
          applicantUserId: 'dublin-mock-user-sofia',
          overallMatchScore: 80,
          verifiedTransitDurationSeconds: 2220,
        ),
        const HighSignalMatch(
          applicationId: 'dublin-mock-app-tomasz',
          applicantUserId: 'dublin-mock-user-tomasz',
          overallMatchScore: 78,
          verifiedTransitDurationSeconds: 2280,
        ),
        const HighSignalMatch(
          applicationId: 'dublin-mock-app-aarav',
          applicantUserId: 'dublin-mock-user-aarav',
          overallMatchScore: 76,
          verifiedTransitDurationSeconds: 2400,
        ),
        const HighSignalMatch(
          applicationId: 'dublin-mock-app-linh',
          applicantUserId: 'dublin-mock-user-linh',
          overallMatchScore: 73,
          verifiedTransitDurationSeconds: 2520,
        ),
        const HighSignalMatch(
          applicationId: 'dublin-mock-app-samir',
          applicantUserId: 'dublin-mock-user-samir',
          overallMatchScore: 70,
          verifiedTransitDurationSeconds: 2700,
        ),
      ];

  static List<Map<String, dynamic>> ownedListingsForHost() => [
        sharedFlatListing(),
      ];

  static final Map<String, Map<String, dynamic>> _trustProfiles = {
    'dublin-mock-user-aarav': {
      'full_name': 'Aarav Mehta',
      'trust_tier': 'Just Landed',
      'trust_stage': 1,
      'employment_verified': false,
      'financial_verified': false,
    },
    'dublin-mock-user-chloe': {
      'full_name': 'Chloe Dubois',
      'trust_tier': 'Grand',
      'trust_stage': 2,
      'employment_verified': false,
      'financial_verified': false,
      'verified_university_email': 'chloe.dubois@ucd.ie',
      'university_domain': 'ucd.ie',
    },
    'dublin-mock-user-mark': {
      'full_name': "Mark O'Connor",
      'trust_tier': 'Sound',
      'trust_stage': 3,
      'employment_verified': true,
      'financial_verified': true,
      'verification_track': 'Corporate Track',
      'corporate_verification_seal': 'sealed-stripe-dublin',
      'annual_salary': 72000,
    },
    'dublin-mock-user-niamh': {
      'full_name': 'Niamh Byrne',
      'trust_tier': 'Sound',
      'trust_stage': 3,
      'employment_verified': true,
      'financial_verified': true,
      'verification_track': 'Corporate Track',
      'annual_salary': 69000,
    },
    'dublin-mock-user-luke': {
      'full_name': 'Luke Gallagher',
      'trust_tier': 'Sound',
      'trust_stage': 3,
      'employment_verified': true,
      'financial_verified': true,
      'verification_track': 'Corporate Track',
      'annual_salary': 66000,
    },
    'dublin-mock-user-sofia': {
      'full_name': 'Sofia Rossi',
      'trust_tier': 'Grand',
      'trust_stage': 2,
      'employment_verified': false,
      'financial_verified': true,
      'verified_university_email': 'sofia.rossi@tcd.ie',
      'university_domain': 'tcd.ie',
    },
    'dublin-mock-user-tomasz': {
      'full_name': 'Tomasz Kowalski',
      'trust_tier': 'Grand',
      'trust_stage': 2,
      'employment_verified': false,
      'financial_verified': false,
      'verified_university_email': 'tomasz.kowalski@ucd.ie',
      'university_domain': 'ucd.ie',
    },
    'dublin-mock-user-linh': {
      'full_name': 'Linh Nguyen',
      'trust_tier': 'Just Landed',
      'trust_stage': 1,
      'employment_verified': false,
      'financial_verified': false,
    },
    'dublin-mock-user-samir': {
      'full_name': 'Samir Khan',
      'trust_tier': 'Just Landed',
      'trust_stage': 1,
      'employment_verified': false,
      'financial_verified': false,
    },
  };

  static final List<Map<String, dynamic>> _applicationRows = [
    _markOConnorRow(),
    _niamhByrneRow(),
    _lukeGallagherRow(),
    _chloeDuboisRow(),
    _sofiaRossiRow(),
    _tomaszKowalskiRow(),
    _aaravMehtaRow(),
    _linhNguyenRow(),
    _samirKhanRow(),
  ];

  static Map<String, dynamic> _markOConnorRow() => {
        'id': 'dublin-mock-app-mark',
        'listing_id': listingId,
        'applicant_user_id': 'dublin-mock-user-mark',
        'status': 'pending',
        'compatibility_score': 91,
        'created_at': '2026-06-23T08:30:00.000Z',
        'payload': {
          'full_name': "Mark O'Connor",
          'pitch_narrative': 'Software engineer joining Stripe Dublin in August. '
              'Quiet, tidy housemate — Luas Green Line from Ranelagh to '
              'city centre fits my commute perfectly. Corporate offer letter '
              'on file; gross salary €72k (>3.5× rent).',
          'food_preference': 'flexitarian',
          'spoken_language_entries': [
            {'language': 'English', 'is_native': true},
          ],
          'spoken_languages': ['English'],
          'mother_tongue': 'English',
          'schedule_type': 'office_hours',
          'commute_mode': 'luas',
          'commute_summary': 'Luas Green Line · Ranelagh → city centre',
          'employer': 'Stripe',
          'annual_salary': 72000,
          'affordability_multiplier': 3.5,
        },
      };

  static Map<String, dynamic> _chloeDuboisRow() => {
        'id': 'dublin-mock-app-chloe',
        'listing_id': listingId,
        'applicant_user_id': 'dublin-mock-user-chloe',
        'status': 'viewing_scheduled',
        'compatibility_score': 79,
        'created_at': '2026-06-22T11:15:00.000Z',
        'payload': {
          'full_name': 'Chloe Dubois',
          'pitch_narrative':
              'Final-year UCD student (BSc Economics). Cycle or 39a bus to '
                  'Belfield from Ranelagh — both under 35 minutes. Verified '
                  'chloe.dubois@ucd.ie on file. Respectful, early-riser household '
                  'member looking for a calm shared flat through graduation.',
          'food_preference': 'vegetarian',
          'spoken_language_entries': [
            {'language': 'French', 'is_native': true},
            {'language': 'English', 'is_native': false},
          ],
          'spoken_languages': ['French', 'English'],
          'mother_tongue': 'French',
          'student_type': 'undergraduate',
          'commute_mode': 'cycle_bus',
          'commute_summary': 'Cycle / 39a bus · Ranelagh → UCD Belfield',
          'verified_university_email': 'chloe.dubois@ucd.ie',
          'affordability_multiplier': 3.1,
        },
      };

  static Map<String, dynamic> _niamhByrneRow() => {
        'id': 'dublin-mock-app-niamh',
        'listing_id': listingId,
        'applicant_user_id': 'dublin-mock-user-niamh',
        'status': 'pending',
        'compatibility_score': 88,
        'created_at': '2026-06-23T07:40:00.000Z',
        'payload': {
          'full_name': 'Niamh Byrne',
          'pitch_narrative':
              'Product manager at HubSpot Docklands. Luas Green Line and a short '
                  'walk from Ranelagh keep my weekday commute steady. Salary slips and '
                  'employment letter uploaded; I value tidy shared kitchens and quiet evenings.',
          'food_preference': 'omnivore',
          'spoken_language_entries': [
            {'language': 'English', 'is_native': true},
            {'language': 'Irish', 'is_native': false},
          ],
          'spoken_languages': ['English', 'Irish'],
          'mother_tongue': 'English',
          'schedule_type': 'office_hours',
          'commute_mode': 'luas',
          'commute_summary':
              'Luas Green Line · Ranelagh → Charlemont/Docklands',
          'employer': 'HubSpot',
          'annual_salary': 69000,
          'affordability_multiplier': 4.2,
        },
      };

  static Map<String, dynamic> _lukeGallagherRow() => {
        'id': 'dublin-mock-app-luke',
        'listing_id': listingId,
        'applicant_user_id': 'dublin-mock-user-luke',
        'status': 'pending',
        'compatibility_score': 86,
        'created_at': '2026-06-22T14:20:00.000Z',
        'payload': {
          'full_name': 'Luke Gallagher',
          'pitch_narrative':
              'Cloud engineer working hybrid in Grand Canal Dock. Easy tram commute '
                  'from Ranelagh and references from previous shared flats available. '
                  'Corporate verification complete and rent affordability well above threshold.',
          'food_preference': 'omnivore',
          'spoken_language_entries': [
            {'language': 'English', 'is_native': true},
          ],
          'spoken_languages': ['English'],
          'mother_tongue': 'English',
          'schedule_type': 'hybrid',
          'commute_mode': 'luas',
          'commute_summary': 'Luas Green Line · Ranelagh → Grand Canal Dock',
          'employer': 'Workday',
          'annual_salary': 66000,
        },
      };

  static Map<String, dynamic> _sofiaRossiRow() => {
        'id': 'dublin-mock-app-sofia',
        'listing_id': listingId,
        'applicant_user_id': 'dublin-mock-user-sofia',
        'status': 'viewing_scheduled',
        'compatibility_score': 80,
        'created_at': '2026-06-22T10:10:00.000Z',
        'payload': {
          'full_name': 'Sofia Rossi',
          'pitch_narrative':
              'TCD postgraduate in business analytics. Commute is a straightforward '
                  'Luas plus short walk to campus. Verified university email and guarantor '
                  'paperwork are ready; looking for a respectful, study-friendly home.',
          'food_preference': 'vegetarian',
          'spoken_language_entries': [
            {'language': 'Italian', 'is_native': true},
            {'language': 'English', 'is_native': false},
          ],
          'spoken_languages': ['Italian', 'English'],
          'mother_tongue': 'Italian',
          'student_type': 'postgraduate',
          'commute_mode': 'luas_walk',
          'commute_summary': 'Luas Green Line · Ranelagh → city centre/TCD',
          'verified_university_email': 'sofia.rossi@tcd.ie',
        },
      };

  static Map<String, dynamic> _tomaszKowalskiRow() => {
        'id': 'dublin-mock-app-tomasz',
        'listing_id': listingId,
        'applicant_user_id': 'dublin-mock-user-tomasz',
        'status': 'pending',
        'compatibility_score': 78,
        'created_at': '2026-06-21T13:05:00.000Z',
        'payload': {
          'full_name': 'Tomasz Kowalski',
          'pitch_narrative':
              'UCD engineering student in final semester. Uses bus + Luas mix and is '
                  'comfortable with shared routines. Verified student credentials uploaded; '
                  'looking for a long-term room through internship season.',
          'food_preference': 'omnivore',
          'spoken_language_entries': [
            {'language': 'Polish', 'is_native': true},
            {'language': 'English', 'is_native': false},
          ],
          'spoken_languages': ['Polish', 'English'],
          'mother_tongue': 'Polish',
          'student_type': 'undergraduate',
          'commute_mode': 'bus_luas',
          'commute_summary': 'Dublin Bus + Luas · Ranelagh → UCD',
          'verified_university_email': 'tomasz.kowalski@ucd.ie',
        },
      };

  static Map<String, dynamic> _aaravMehtaRow() => {
        'id': 'dublin-mock-app-aarav',
        'listing_id': listingId,
        'applicant_user_id': 'dublin-mock-user-aarav',
        'status': 'pending',
        'compatibility_score': 84,
        'created_at': '2026-06-21T16:45:00.000Z',
        'payload': {
          'full_name': 'Aarav Mehta',
          'pitch_narrative':
              'Postgraduate offer at Trinity College Dublin (MSc Data Science). '
                  'Just landed from Mumbai — happy to walk or hop the Luas from '
                  'Ranelagh to campus. Education loan disbursal letter uploaded; '
                  'funds confirmed for 12 months. Tidy, friendly, and excited to '
                  'join an English–Spanish speaking household.',
          'food_preference': 'vegetarian',
          'spoken_language_entries': [
            {'language': 'English', 'is_native': false},
            {'language': 'Hindi', 'is_native': true},
          ],
          'spoken_languages': ['English', 'Hindi'],
          'mother_tongue': 'Hindi',
          'student_type': 'postgraduate',
          'commute_mode': 'walk_luas',
          'commute_summary': 'Walk / Luas · Ranelagh → Trinity College Dublin',
          'funding_source': 'education_loan',
          'funding_document': 'bank_loan_disbursal_letter',
          'affordability_multiplier': 2.6,
        },
      };

  static Map<String, dynamic> _linhNguyenRow() => {
        'id': 'dublin-mock-app-linh',
        'listing_id': listingId,
        'applicant_user_id': 'dublin-mock-user-linh',
        'status': 'pending',
        'compatibility_score': 73,
        'created_at': '2026-06-21T12:15:00.000Z',
        'payload': {
          'full_name': 'Linh Nguyen',
          'pitch_narrative':
              'Recently relocated for an internship near Pearse Street. Just landed '
                  'in Dublin with proof of stipend and savings. Friendly, tidy, and keen '
                  'to live with international housemates near reliable transit.',
          'food_preference': 'vegetarian',
          'spoken_language_entries': [
            {'language': 'Vietnamese', 'is_native': true},
            {'language': 'English', 'is_native': false},
          ],
          'spoken_languages': ['Vietnamese', 'English'],
          'mother_tongue': 'Vietnamese',
          'student_type': 'postgraduate',
          'commute_mode': 'walk_transit',
          'commute_summary': 'Bus/Luas · Ranelagh → Pearse Street',
          'funding_source': 'family_support',
        },
      };

  static Map<String, dynamic> _samirKhanRow() => {
        'id': 'dublin-mock-app-samir',
        'listing_id': listingId,
        'applicant_user_id': 'dublin-mock-user-samir',
        'status': 'pending',
        'compatibility_score': 70,
        'created_at': '2026-06-20T18:35:00.000Z',
        'payload': {
          'full_name': 'Samir Khan',
          'pitch_narrative':
              'New arrival starting language classes and part-time retail work. '
                  'Prefers shared homes close to transport while settling in Dublin. '
                  'Can provide references from current employer and deposit upfront.',
          'food_preference': 'halal',
          'spoken_language_entries': [
            {'language': 'Urdu', 'is_native': true},
            {'language': 'English', 'is_native': false},
          ],
          'spoken_languages': ['Urdu', 'English'],
          'mother_tongue': 'Urdu',
          'commute_mode': 'bus_walk',
          'commute_summary': 'Dublin Bus corridor · Ranelagh → city centre',
          'funding_source': 'employment_income',
        },
      };
}
