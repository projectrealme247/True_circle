import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/services/commute_scoring_service.dart';
import 'package:true_circle/utils/listing_match_engine.dart';

void main() {
  test('over-budget commute applies gradual score penalty without exclusion', () {
    final rentListings = SampleListingsDublin.items
        .where((l) => l['type'] == 'Rent')
        .map((l) => {
              ...l,
              if (l['latitude'] == null) 'latitude': 53.3380,
              if (l['longitude'] == null) 'longitude': -6.2600,
            })
        .toList();

    final seekerSession = {
      'full_name': 'Seeker',
      'detected_city': 'Dublin',
      'mother_tongue': 'English',
      'spoken_languages': ['English'],
      'occupant_type': 'Working Professionals',
      'maximum_commute_budget_minutes': 10,
      'commute_method': CommuteMethod.backendPublicTransportWalking,
      'commute_destination_hub_id': 'grand_canal_dock',
      'destination_latitude': 53.3419,
      'destination_longitude': -6.2373,
    };

    final withTightBudget = ListingMatchEngine.rank(rentListings, seekerSession);
    final relaxedBudgetSession = Map<String, dynamic>.from(seekerSession)
      ..['maximum_commute_budget_minutes'] = 120;
    final withRelaxedBudget =
        ListingMatchEngine.rank(rentListings, relaxedBudgetSession);

    expect(withTightBudget.ranked, isNotEmpty);
    expect(
      withTightBudget.ranked.length,
      withRelaxedBudget.ranked.length,
      reason: 'Commute budget must not hard-exclude listings from the feed',
    );

    expect(
      CommuteScoringService.overBudgetScorePenalty(
        doorToDoorMinutes: 12,
        budgetMinutes: 10,
      ),
      4,
    );

    for (final scored in withTightBudget.ranked) {
      expect(scored.match.excluded, isFalse);
    }
  });
}
