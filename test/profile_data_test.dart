import 'package:flutter_test/flutter_test.dart';

import 'package:true_circle/utils/profile_data.dart';

void main() {
  group('ProfileData.isMatchingReady', () {
    test('returns false for empty or email-only session', () {
      expect(ProfileData.isMatchingReady(null), isFalse);
      expect(
        ProfileData.isMatchingReady({'email': 'a@b.com'}),
        isFalse,
      );
    });

    test('returns true when core matching fields are present', () {
      expect(
        ProfileData.isMatchingReady({
          'full_name': 'Priya',
          'detected_city': 'Cherrywood',
          'mother_tongue': 'Telugu',
          'food_preference': 'Pure Veg',
          'spoken_languages': ['Telugu', 'English'],
          'target_search_areas': ['dublin14'],
        }),
        isTrue,
      );
    });

    test('missingMatchingFields lists modern gaps only', () {
      expect(
        ProfileData.missingMatchingFields({'email': 'x@y.com'}),
        containsAll([
          'Full name',
          'Mother tongue',
          'Languages spoken',
          'Commuter profiles',
        ]),
      );
      expect(
        ProfileData.missingMatchingFields({'email': 'x@y.com'}),
        isNot(contains('Current location')),
      );
      expect(
        ProfileData.missingMatchingFields({'email': 'x@y.com'}),
        isNot(contains('Target search areas')),
      );
    });
  });

  group('ProfileData.calculateProfileCompletionPercentage', () {
    test('counts only modern completion fields', () {
      final session = {
        'full_name': 'Ana',
        'email': 'ana@example.com',
        'mother_tongue': 'English',
        'spoken_languages': ['English', 'Hindi'],
        'maximum_commute_budget_minutes': 45,
      };

      expect(ProfileData.calculateProfileCompletionPercentage(session), 63);
    });

    test('full modern profile reaches 100%', () {
      final session = {
        'full_name': 'Ana',
        'email': 'ana@example.com',
        'mother_tongue': 'English',
        'spoken_languages': ['English'],
        'maximum_commute_budget_minutes': 45,
        'budget_min': 1200,
        'budget_max': 1800,
        'occupant_type': 'Students',
        'commute_method': 'public_transport_walking',
        'commute_destination_hub_id': 'st_stephens_green',
        'commute_destination': "St. Stephen's Green",
        'destination_latitude': 53.3382,
        'destination_longitude': -6.2591,
      };

      expect(ProfileData.calculateProfileCompletionPercentage(session), 100);
      expect(ProfileData.profileCompletenessPercent(session), 100);
    });
  });
}
