import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/listing_search_intent.dart';
import 'package:true_circle/utils/weighted_listing_matcher.dart';

void main() {
  Map<String, dynamic> listing({
    required String price,
    bool wfh = false,
    String food = 'Non-veg',
    String roomType = 'Private room',
  }) =>
      {
        'type': 'Share',
        'price': price,
        'wfh_friendly': wfh,
        'hostFoodPreference': food,
        'room_type': roomType,
        'schedule_type': wfh ? 'Flexible' : 'Day shift',
      };

  test('hard cap excludes only above 125% of max budget', () {
    const filters = ListingSearchFilters(budgetMax: 800);
    const criteria = WeightedFilterCriteria(maxBudget: 800, isSharedLiving: true);

    expect(
      WeightedListingMatcher.passesHardExclusion(
        listing(price: 'EUR 900'),
        criteria,
        filters,
        towerPropertyType: 'Share',
      ),
      isTrue,
    );
    expect(
      WeightedListingMatcher.passesHardExclusion(
        listing(price: 'EUR 1050'),
        criteria,
        filters,
        towerPropertyType: 'Share',
      ),
      isFalse,
    );
  });

  test('move-in timing is soft and never hard-excludes inventory', () {
    const filters = ListingSearchFilters(moveInWindow: 'this_month');
    const criteria = WeightedFilterCriteria(
      preferredMoveInWindow: 'this_month',
    );
    final listing = {
      'type': 'Rent',
      'price': 'EUR 1200',
      'available_from': '2027-01-01',
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

  test('independent places ignore compatibility hard filters', () {
    const filters = ListingSearchFilters(
      occupantType: 'Students',
      genderPreference: 'girls',
      foodPreference: 'veg',
    );
    const criteria = WeightedFilterCriteria();
    final listing = {
      'type': 'Rent',
      'price': 'EUR 1200',
      'occupantType': 'Family',
      'bachelorPreference': 'Boys only',
      'hostFoodPreference': 'Non-veg',
    };

    expect(
      WeightedListingMatcher.passesHardExclusion(
        listing,
        criteria,
        filters.scopedForTower('Rent'),
        towerPropertyType: 'Rent',
      ),
      isTrue,
    );
  });

  test('shared living food preference is soft — never hard-excludes', () {
    const filters = ListingSearchFilters(foodPreference: 'veg');
    final criteria = WeightedFilterCriteria.fromSearchContext(
      filters: filters,
      userSession: null,
      towerPropertyType: 'Share',
    );
    final vegListing = {
      'type': 'Share',
      'price': 'EUR 700',
      'hostFoodPreference': 'Pure Veg',
    };
    final nonVegListing = {
      'type': 'Share',
      'price': 'EUR 700',
      'hostFoodPreference': 'Non-veg',
    };

    expect(
      WeightedListingMatcher.passesHardExclusion(
        vegListing,
        criteria,
        filters,
        towerPropertyType: 'Share',
      ),
      isTrue,
    );
    expect(
      WeightedListingMatcher.passesHardExclusion(
        nonVegListing,
        criteria,
        filters,
        towerPropertyType: 'Share',
      ),
      isTrue,
    );
    expect(
      WeightedListingMatcher.computePreferenceScore(vegListing, criteria),
      greaterThan(
        WeightedListingMatcher.computePreferenceScore(nonVegListing, criteria),
      ),
    );
  });

  test('shared living household type preference boosts matching listings', () {
    const filters = ListingSearchFilters(occupantType: 'Students');
    final criteria = WeightedFilterCriteria.fromSearchContext(
      filters: filters,
      userSession: null,
      towerPropertyType: 'Share',
    );
    final studentListing = {
      'type': 'Share',
      'price': 'EUR 700',
      'occupantType': 'Students',
    };
    final profListing = {
      'type': 'Share',
      'price': 'EUR 700',
      'occupantType': 'Working Professionals',
    };

    expect(
      WeightedListingMatcher.computePreferenceScore(studentListing, criteria),
      greaterThan(
        WeightedListingMatcher.computePreferenceScore(profListing, criteria),
      ),
    );
  });

  test('combined soft lifestyle filters never zero the baseline pool', () {
    final inventory = [
      listing(price: 'EUR 750', wfh: false, food: 'Non-veg', roomType: 'Ensuite'),
      listing(price: 'EUR 780', wfh: true, food: 'Veg', roomType: 'Private room'),
      listing(price: 'EUR 790', wfh: false, food: 'Veg', roomType: 'Bed in shared room'),
    ];
    const filters = ListingSearchFilters(
      budgetMax: 800,
      moveInWindow: 'this_month',
    );
    const criteria = WeightedFilterCriteria(
      maxBudget: 800,
      isSharedLiving: true,
      preferredMoveInWindow: 'this_month',
      preferredRoomType: 'ensuite',
    );

    final scored = WeightedListingMatcher.fetchScoredListings(
      listings: inventory,
      criteria: criteria,
      filters: filters,
      towerPropertyType: 'Share',
    );

    expect(scored, isNotEmpty);
    expect(scored.length, inventory.length);
    expect(
      WeightedListingMatcher.computePreferenceScore(scored.first, criteria),
      greaterThanOrEqualTo(
        WeightedListingMatcher.computePreferenceScore(scored.last, criteria),
      ),
    );
  });

  test('stretch zone penalty lowers preference score above 110%', () {
    const criteria = WeightedFilterCriteria(maxBudget: 800);
    final withinBudget = WeightedListingMatcher.computePreferenceScore(
      listing(price: 'EUR 750'),
      criteria,
    );
    final stretchZone = WeightedListingMatcher.computePreferenceScore(
      listing(price: 'EUR 900'),
      criteria,
    );
    expect(stretchZone, lessThan(withinBudget));
    expect(stretchZone, closeTo(85, 0.01));
  });
}
