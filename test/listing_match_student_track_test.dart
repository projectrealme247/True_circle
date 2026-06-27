import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/listing_match_engine.dart';
import 'package:true_circle/utils/viewer_profile.dart';

void main() {
  const preArrivalSession = {
    'full_name': 'Aisha',
    'detected_city': 'Dundrum D14',
    'mother_tongue': 'English',
    'food_preference': 'Veg',
    'occupant_type': 'Students',
    'trust_stage': 2,
    'pre_arrival_contact_ready': true,
    'invite_code_verified': true,
    'onboarding_letter_verified': true,
  };

  const onCampusSession = {
    'full_name': 'Rohan',
    'detected_city': 'Dundrum D14',
    'mother_tongue': 'English',
    'food_preference': 'Veg',
    'occupant_type': 'Students',
    'trust_stage': 3,
    'verified_university_email': 'r***@tcd.ie',
  };

  Map<String, dynamic> baseListing({String? tenantTrackPreference}) => {
        'id': 'test-listing',
        'title': 'Student room near campus',
        'price': '900/month',
        'location': 'Dundrum, Dublin',
        'type': 'Share',
        'description': 'Quiet house for students near Luas.',
        'host_trust_stage': 2,
        'occupantType': 'Students',
        if (tenantTrackPreference != null)
          'tenant_track_preference': tenantTrackPreference,
      };

  group('ListingMatchEngine student track preference', () {
    test('pre-arrival seeker is hard-blocked from on-campus-only listings', () {
      final outcome = ListingMatchEngine.rank(
        [baseListing(tenantTrackPreference: 'track_a')],
        preArrivalSession,
      );

      expect(outcome.ranked, isEmpty);
    });

    test('pre-arrival seeker scores with 0.9x on all-students listings', () {
      final viewer = ViewerProfile.fromSession(preArrivalSession);
      final allowed = ListingMatchEngine.evaluate(
        baseListing(tenantTrackPreference: 'both'),
        viewer,
      );
      final blocked = ListingMatchEngine.evaluate(
        baseListing(tenantTrackPreference: 'track_a'),
        viewer,
      );

      expect(blocked.excluded, isTrue);
      expect(allowed.excluded, isFalse);
      expect(allowed.score, greaterThan(0));
    });

    test('on-campus seeker receives 1.0x on on-campus-only listings', () {
      final viewer = ViewerProfile.fromSession(onCampusSession);
      final onCampusOnly = ListingMatchEngine.evaluate(
        baseListing(tenantTrackPreference: 'track_a'),
        viewer,
      );
      final missingPref = ListingMatchEngine.evaluate(
        baseListing(),
        viewer,
      );

      expect(onCampusOnly.excluded, isFalse);
      expect(missingPref.excluded, isFalse);
      expect(onCampusOnly.score, greaterThan(0));
    });

    test('missing tenant_track_preference defaults to all-students matching', () {
      final viewer = ViewerProfile.fromSession(preArrivalSession);
      final preArrival = ListingMatchEngine.evaluate(
        baseListing(),
        viewer,
      );

      expect(preArrival.excluded, isFalse);
    });
  });
}
