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

    test('returns true when five essentials are present — no mother tongue', () {
      expect(
        ProfileData.isMatchingReady({
          'preferred_property_type': 'Share',
          'occupant_type': 'Students',
          'budget_min': 1000,
          'budget_max': 1800,
          'move_in_window': 'flexible',
          'commute_method': 'public_transport_walking',
          'commute_destination_hub_id': 'st_stephens_green',
          'commute_destination': "St. Stephen's Green",
          'destination_latitude': 53.3382,
          'destination_longitude': -6.2591,
          'commute_profiles': [
            {
              'id': 'primary',
              'commute_method': 'public_transport_walking',
              'commute_destination_hub_id': 'st_stephens_green',
              'max_commute_minutes': 45,
            },
          ],
        }),
        isTrue,
      );
    });

    test('mother tongue is never required', () {
      final session = {
        'preferred_property_type': 'Rent',
        'seeker_persona': 'professional',
        'budget_min': 1200,
        'budget_max': 2000,
        'move_in_window': 'next_month',
        'commute_profiles': [
          {
            'id': 'primary',
            'commute_method': 'public_transport_walking',
            'commute_destination_hub_id': 'tcd',
            'max_commute_minutes': 45,
          },
        ],
      };
      expect(ProfileData.isMatchingReady(session), isTrue);
      expect(
        ProfileData.missingFieldsForCompletion(session),
        isNot(contains('Mother tongue')),
      );
      expect(
        ProfileData.missingFieldsForCompletion(session),
        isNot(contains('Languages spoken')),
      );
    });

    test('missingMatchingFields lists only the five essentials', () {
      expect(
        ProfileData.missingMatchingFields({'email': 'x@y.com'}),
        containsAll([
          'Listing type',
          'Persona',
          'Budget',
          'Destination',
          'Move-in window',
        ]),
      );
      expect(
        ProfileData.missingMatchingFields({'email': 'x@y.com'}),
        isNot(contains('Mother tongue')),
      );
    });
  });

  group('ProfileData.calculateProfileCompletionPercentage', () {
    test('counts only the five essentials', () {
      final session = {
        'preferred_property_type': 'Share',
        'occupant_type': 'Students',
        'budget_min': 1000,
        'budget_max': 1500,
        // destination + move-in missing → 3/5
      };

      expect(ProfileData.calculateProfileCompletionPercentage(session), 60);
    });

    test('full essentials reach 100% without mother tongue', () {
      final session = {
        'preferred_arrangement': 'shared_room',
        'preferred_property_type': 'Share',
        'seeker_persona': 'professional',
        'budget_min': 1200,
        'budget_max': 1800,
        'move_in_window': 'flexible',
        'commute_method': 'public_transport_walking',
        'commute_destination_hub_id': 'st_stephens_green',
        'commute_destination': "St. Stephen's Green",
        'destination_latitude': 53.3382,
        'destination_longitude': -6.2591,
        'commute_profiles': [
          {
            'id': 'primary',
            'commute_method': 'public_transport_walking',
            'commute_destination_hub_id': 'st_stephens_green',
            'max_commute_minutes': 45,
          },
        ],
      };

      expect(ProfileData.calculateProfileCompletionPercentage(session), 100);
      expect(ProfileData.profileCompletenessPercent(session), 100);
      expect(ProfileData.missingFieldsForCompletion(session), isEmpty);
    });

    test('hasRenderableProfileContent is true with partial data', () {
      expect(
        ProfileData.hasRenderableProfileContent({
          'full_name': 'Ana',
          'email': 'ana@example.com',
        }),
        isTrue,
      );
      expect(ProfileData.hasRenderableProfileContent(null), isFalse);
      expect(ProfileData.hasRenderableProfileContent({}), isFalse);
    });
  });
}
