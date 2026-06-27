import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/utils/listing_data.dart';
import 'package:true_circle/utils/listing_search_intent.dart';
import 'package:true_circle/utils/marketplace_listing_pipeline.dart';
import 'package:true_circle/utils/target_search_areas.dart';

void main() {
  group('ALL_DUBLIN area filter', () {
    test('does not parse all of dublin query text into a micro district', () {
      expect(
        ListingSearchIntent.parseQuery('all of dublin').city,
        isNull,
      );
      expect(
        ListingSearchFilters()
            .withAllDublinArea()
            .pipelineQueryText(),
        '',
      );
    });

    test('returns all Rent tower listings across Dublin districts', () {
      final rentListings = SampleListingsDublin.items
          .where((l) => ListingData.propertyType(l) == 'Rent')
          .toList();

      final result = MarketplaceListingPipeline.runWithFilters(
        allListings: SampleListingsDublin.items,
        towerPropertyType: 'Rent',
        filters: const ListingSearchFilters().withAllDublinArea(),
        userSession: null,
        searchQuery: '',
      );

      expect(result.afterFilters.length, rentListings.length);
      expect(result.ranked.length, rentListings.length);

      final locations = result.afterFilters
          .map((l) => ListingData.location(l).toLowerCase())
          .toSet();
      expect(locations.any((l) => l.contains('dublin 4')), isTrue);
      expect(locations.any((l) => l.contains('dublin 12')), isTrue);
      expect(locations.any((l) => l.contains('dublin 18')), isTrue);
    });

    test('wildcard token matches any listing', () {
      final listing = SampleListingsDublin.items.first;
      expect(
        TargetSearchAreas.listingMatchesTargets(
          TargetSearchAreas.allDublinFilterTokens,
          listing,
        ),
        isTrue,
      );
    });
  });
}
