import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/services/commute_scoring_service.dart';
import 'package:true_circle/utils/listing_commute_display.dart';

void main() {
  const listingNearCity = {
    'id': 'test-1',
    'latitude': 53.3380,
    'longitude': -6.2600,
    'hostName': 'Host A',
    'parking_type': 'no_parking',
    'proximity_data': {
      'transit_type': 'Luas Green Line',
      'walk_minutes': 6,
    },
  };

  final seekerWithCommute = {
    'full_name': 'Seeker Test',
    'commute_method': CommuteMethod.backendPublicTransportWalking,
    'commute_destination': 'Grand Canal Dock',
    'commute_destination_hub_id': 'grand_canal_dock',
    'destination_latitude': 53.3419,
    'destination_longitude': -6.2373,
  };

  group('ListingCommuteDisplay', () {
    test('personalized badge when seeker has commute prefs', () {
      final display = ListingCommuteDisplay.resolve(
        listing: listingNearCity,
        viewerSession: seekerWithCommute,
      );

      expect(display, isNotNull);
      expect(display!.isPersonalized, isTrue);
      expect(display.rows.first.minutes, greaterThan(0));
      expect(
        display.rows.first.headline.toLowerCase(),
        contains('grand canal dock'),
      );
      expect(display.rows.first.headline, matches(RegExp(r'^\d+ mins to ')));
      expect(display.rows.first.commuteMethod,
          CommuteMethod.publicTransportWalking);
    });

    test('landlord preview falls back to property transit macro-tag', () {
      final ownerSession = {
        'full_name': 'Host A',
        'commute_method': CommuteMethod.backendDriving,
        'commute_destination': 'UCD',
        'commute_destination_hub_id': 'ucd',
        'destination_latitude': 53.3080,
        'destination_longitude': -6.2267,
      };

      final display = ListingCommuteDisplay.resolve(
        listing: listingNearCity,
        viewerSession: ownerSession,
      );

      expect(display, isNotNull);
      expect(display!.isPersonalized, isFalse);
      expect(display.rows.first.headline, contains('Luas Green Line'));
      expect(display.rows.first.headline, contains('walk'));
    });

    test('unsigned browser gets absolute nearest transit fallback', () {
      final display = ListingCommuteDisplay.resolve(
        listing: listingNearCity,
        viewerSession: null,
      );

      expect(display, isNotNull);
      expect(display!.isPersonalized, isFalse);
      expect(display.rows.first.minutes, greaterThan(0));
      expect(display.rows.first.headline, contains('Luas Green Line'));
    });

    test('description walk copy falls back when proximity data absent', () {
      final listing = {
        'id': 'walk-fallback',
        'description':
            'Sandymount Strand 10 min walk. Professionals preferred.',
      };

      final display = ListingCommuteDisplay.resolve(
        listing: listing,
        viewerSession: null,
      );

      expect(display, isNotNull);
      expect(display!.rows.first.minutes, 10);
      expect(display.rows.first.headline, contains('Sandymount Strand'));
    });

    test('driving commute shows parking warning when host has no parking', () {
      final drivingSeeker = {
        ...seekerWithCommute,
        'commute_method': CommuteMethod.backendDriving,
        'commute_destination_hub_id': 'ucd',
        'commute_destination': 'University College Dublin (UCD)',
        'destination_latitude': 53.3080,
        'destination_longitude': -6.2267,
      };

      final display = ListingCommuteDisplay.resolve(
        listing: listingNearCity,
        viewerSession: drivingSeeker,
      );

      expect(display, isNotNull);
      expect(display!.rows.first.commuteMethod, CommuteMethod.driving);
      expect(display.rows.first.parkingWarning, isNotNull);
      expect(
        display.rows.first.parkingWarning,
        contains('Parking Permit Required'),
      );
    });

    test('over-budget commute uses verbatim amber warning copy', () {
      final tightBudgetSeeker = {
        ...seekerWithCommute,
        'maximum_commute_budget_minutes': 5,
      };

      final display = ListingCommuteDisplay.resolve(
        listing: listingNearCity,
        viewerSession: tightBudgetSeeker,
      );

      expect(display, isNotNull);
      expect(display!.rows.first.exceedsBudget, isTrue);
      expect(
        display.rows.first.headline,
        ListingCommuteDisplay.overBudgetLabel(
          display.rows.first.minutes,
          5,
        ),
      );
      expect(
        display.rows.first.headline,
        contains('Exceeds your 5m budget'),
      );
    });

    test('async multi-commute resolves parallel profile rows', () async {
      final coupleSession = {
        ...seekerWithCommute,
        'maximum_commute_budget_minutes': 45,
        'partner_commute_method': CommuteMethod.backendDriving,
        'partner_commute_destination_hub_id': 'ucd',
        'partner_commute_destination': 'University College Dublin (UCD)',
        'partner_destination_latitude': 53.3080,
        'partner_destination_longitude': -6.2267,
        'commute_profiles': [
          {
            'id': 'primary',
            'label': 'You',
            'commute_method': CommuteMethod.backendPublicTransportWalking,
            'commute_destination_hub_id': 'grand_canal_dock',
          },
          {
            'id': 'partner',
            'label': 'Partner',
            'commute_method': CommuteMethod.backendDriving,
            'commute_destination_hub_id': 'ucd',
          },
        ],
      };

      final display = await ListingCommuteDisplay.resolveAsync(
        listing: listingNearCity,
        viewerSession: coupleSession,
      );

      expect(display, isNotNull);
      expect(display!.rows.length, 2);
      expect(display.metadata?.results.length, 2);
      expect(display.rows.any((row) => row.commuterLabel == 'Partner'), isTrue);
    });
  });
}
