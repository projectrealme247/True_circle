import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/utils/listing_match_engine.dart';

void main() {
  test('Dundrum profile ranks Dundrum listings above Cherrywood', () {
    const session = {
      'full_name': 'Test User',
      'detected_city': 'Dundrum D14',
      'mother_tongue': 'Telugu',
      'spoken_languages': ['Telugu', 'English'],
      'food_preference': 'Pure Veg',
      'occupant_type': 'Family',
    };

    final rentListings = SampleListingsDublin.items
        .where((l) => l['type'] == 'Rent')
        .toList();

    final outcome = ListingMatchEngine.rank(rentListings, session);
    final ranked = outcome.ranked;

    final scoreById = {
      for (final s in ranked) s.listing['id'] as String: s.match.score,
    };

    expect(
      scoreById['dub-rent-16']!,
      greaterThan(scoreById['dub-rent-09']!),
    );
    expect(
      scoreById['dub-rent-03']!,
      greaterThan(scoreById['dub-rent-09']!),
    );
  });
}
