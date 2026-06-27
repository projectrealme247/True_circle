import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/services/commute_scoring_service.dart';
import 'package:true_circle/utils/listing_match_engine.dart';

void main() {
  test('flags is_commute_divergent when opposite hubs exceed max budget', () {
    final rentListings = SampleListingsDublin.items
        .where((l) => l['type'] == 'Rent')
        .map((l) => {
              ...l,
              if (l['latitude'] == null) 'latitude': 53.3380,
              if (l['longitude'] == null) 'longitude': -6.2600,
            })
        .toList();

    final divergentCoupleSession = {
      'full_name': 'Couple Test',
      'detected_city': 'Dublin',
      'mother_tongue': 'English',
      'spoken_languages': ['English'],
      'occupant_type': 'Family',
      'family_adults': 2,
      'maximum_commute_budget_minutes': 20,
      'commute_method': CommuteMethod.backendPublicTransportWalking,
      'commute_destination_hub_id': 'cherrywood_business_park',
      'destination_latitude': 53.2440,
      'destination_longitude': -6.1465,
      'partner_commute_method': CommuteMethod.backendDriving,
      'partner_commute_destination_hub_id': 'tcd',
      'partner_destination_latitude': 53.3438,
      'partner_destination_longitude': -6.2546,
      'commute_profiles': [
        {
          'id': 'primary',
          'label': 'You',
          'commute_method': CommuteMethod.backendPublicTransportWalking,
          'commute_destination_hub_id': 'cherrywood_business_park',
        },
        {
          'id': 'partner',
          'label': 'Partner',
          'commute_method': CommuteMethod.backendDriving,
          'commute_destination_hub_id': 'tcd',
        },
      ],
    };

    final withoutBudget = ListingMatchEngine.rank(
      rentListings,
      divergentCoupleSession,
    );

    expect(withoutBudget.isCommuteDivergent, isTrue);
    expect(withoutBudget.ranked, isNotEmpty);
  });
}
