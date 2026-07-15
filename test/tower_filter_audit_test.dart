import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/utils/listing_search_intent.dart';
import 'package:true_circle/utils/marketplace_listing_pipeline.dart';
import 'package:true_circle/utils/weighted_listing_matcher.dart';

void main() {
  test('audit: Students + 2 Bed + Apartment on Rent tower', () {
    final listings = SampleListingsDublin.items;
    final rentTower = [
      for (final item in listings)
        if (item['type']?.toString() == 'Rent') item,
    ];

    // Before architecture: occupant strong filter + layout keywords.
    const legacyIntent = SearchIntent(
      occupant: 'Students',
      remainingKeywords: ['2bed', 'apartment'],
    );
    final legacyStrong = ListingSearchIntent.applyStrongFilters(
      rentTower,
      legacyIntent,
    );
    final legacyPipeline = MarketplaceListingPipeline.runWithFilters(
      allListings: listings,
      towerPropertyType: 'Rent',
      filters: ListingSearchFilters.fromIntent(legacyIntent),
      userSession: null,
      searchQuery: 'students 2bed apartment',
    );

    final modernFilters = const ListingSearchFilters(
      keywords: ['2bed', 'apartment'],
    ).scopedForTower('Rent');

    final after = MarketplaceListingPipeline.runWithFilters(
      allListings: listings,
      towerPropertyType: 'Rent',
      filters: modernFilters,
      userSession: null,
      searchQuery: '',
    );

    // ignore: avoid_print
    print(
      'AUDIT Students+2bed+apartment Rent: '
      'rentTower=${rentTower.length} '
      'legacyStrong=${legacyStrong.length} '
      'legacyPipelineAfterFilters=${legacyPipeline.afterFilters.length} '
      'modernAfterFilters=${after.afterFilters.length} '
      'modernRanked=${after.ranked.length}',
    );

    expect(legacyStrong, isEmpty);
    expect(after.afterFilters.length, greaterThan(0));
    expect(after.afterFilters.length, greaterThan(legacyStrong.length));
  });

  test('move-in and WFH never hard-exclude in passesHardExclusion', () {
    const filters = ListingSearchFilters(
      moveInWindow: 'this_month',
      wfhFriendly: true,
    );
    const criteria = WeightedFilterCriteria(
      preferredMoveInWindow: 'immediately',
      requiresWfh: true,
    );
    final listing = {
      'type': 'Rent',
      'price': 'EUR 1500',
      'available_from': '2028-06-01',
      'wfh_friendly': false,
      'schedule_type': 'Day shift',
    };

    expect(
      WeightedListingMatcher.passesHardExclusion(
        listing,
        criteria,
        filters,
        towerPropertyType: 'Rent',
      ),
      isTrue,
    );
  });
}
