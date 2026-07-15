import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin_v2.dart';
import 'package:true_circle/utils/listing_data.dart';
import 'package:true_circle/utils/listing_search_intent.dart';
import 'package:true_circle/utils/tower_filter_policy.dart';
import 'package:true_circle/utils/weighted_listing_matcher.dart';

void main() {
  group('TowerFilterPolicy — Independent Places (unchanged)', () {
    test('scopes independent place filters', () {
      const filters = ListingSearchFilters(
        foodPreference: 'veg',
        occupantType: 'Students',
        genderPreference: 'girls',
        householdLanguages: ['English'],
      );

      final scoped = filters.scopedForTower('Rent');

      expect(scoped.foodPreference, isNull);
      expect(scoped.occupantType, isNull);
      expect(scoped.genderPreference, isNull);
      expect(scoped.householdLanguages, isEmpty);
    });

    test('scopes search intent for independent places', () {
      const intent = SearchIntent(
        food: 'veg',
        occupant: 'Students',
        gender: 'girls',
        remainingKeywords: const ['2bed', 'apartment'],
      );

      final scoped = TowerFilterPolicy.scopeSearchIntent(intent, 'Rent');

      expect(scoped.food, isNull);
      expect(scoped.occupant, isNull);
      expect(scoped.gender, isNull);
      expect(scoped.remainingKeywords, contains('2bed'));
    });

    test('Rent hard exclusion ignores compatibility dimensions', () {
      const filters = ListingSearchFilters(
        occupantType: 'Students',
        genderPreference: 'girls',
        foodPreference: 'veg',
        budgetMax: 3000,
      );
      const criteria = WeightedFilterCriteria(maxBudget: 3000);
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
  });

  group('TowerFilterPolicy — Shared Living (final architecture)', () {
    test('household language uses overlap not exact match', () {
      final listing = {
        'spoken_languages': ['English', 'Hindi'],
      };

      expect(
        TowerFilterPolicy.matchesHouseholdLanguageOverlap(
          listing,
          const ['Tamil', 'English'],
        ),
        isTrue,
      );
      expect(
        TowerFilterPolicy.matchesHouseholdLanguageOverlap(
          listing,
          const ['Tamil', 'Malayalam'],
        ),
        isFalse,
      );
    });

    test('scopes Share search intent to gender + keywords only', () {
      const intent = SearchIntent(
        food: 'veg',
        occupant: 'Students',
        gender: 'girls',
        remainingKeywords: ['ensuite'],
      );

      final scoped = TowerFilterPolicy.scopeSearchIntent(intent, 'Share');

      expect(scoped.food, isNull);
      expect(scoped.occupant, isNull);
      expect(scoped.gender, 'girls');
      expect(scoped.remainingKeywords, contains('ensuite'));
    });

    test('Share hard filters only enforce gender restriction', () {
      const filters = ListingSearchFilters(
        foodPreference: 'veg',
        occupantType: 'Students',
        householdLanguages: ['Tamil'],
        genderPreference: 'girls',
      );

      final vegNonStudent = {
        'type': 'Share',
        'price': 'EUR 700',
        'hostFoodPreference': 'Non-veg',
        'occupantType': 'Working Professionals',
        'spoken_languages': ['English'],
        'bachelorPreference': 'Girls only',
      };

      expect(
        TowerFilterPolicy.passesSharedLivingHardFilters(vegNonStudent, filters),
        isTrue,
      );

      final boysOnly = {
        'type': 'Share',
        'price': 'EUR 700',
        'hostFoodPreference': 'Pure Veg',
        'occupantType': 'Students',
        'bachelorPreference': 'Boys only',
      };

      expect(
        TowerFilterPolicy.passesSharedLivingHardFilters(boysOnly, filters),
        isFalse,
      );
    });

    test('Share food and household prefs are soft — pool never zeroed', () {
      final shareListings = [
        for (final l in SampleListingsDublinV2.items)
          if (ListingData.propertyType(l) == 'Share') l,
      ];

      const filters = ListingSearchFilters(
        budgetMax: 900,
        foodPreference: 'veg',
        occupantType: 'Working Professionals',
        householdLanguages: ['Tamil'],
      );
      final criteria = WeightedFilterCriteria.fromSearchContext(
        filters: filters,
        userSession: null,
        towerPropertyType: 'Share',
      );

      final pool = WeightedListingMatcher.fetchScoredListings(
        listings: shareListings,
        criteria: criteria,
        filters: filters,
        towerPropertyType: 'Share',
      );

      expect(pool.length, greaterThan(0));

      const vegOnlyFilters = ListingSearchFilters(
        budgetMax: 900,
        foodPreference: 'veg',
      );
      final vegCriteria = WeightedFilterCriteria.fromSearchContext(
        filters: vegOnlyFilters,
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
          vegCriteria,
          vegOnlyFilters,
          towerPropertyType: 'Share',
        ),
        isTrue,
      );
      expect(
        WeightedListingMatcher.passesHardExclusion(
          nonVegListing,
          vegCriteria,
          vegOnlyFilters,
          towerPropertyType: 'Share',
        ),
        isTrue,
      );

      final vegScore = WeightedListingMatcher.computePreferenceScore(
        vegListing,
        vegCriteria,
      );
      final nonVegScore = WeightedListingMatcher.computePreferenceScore(
        nonVegListing,
        vegCriteria,
      );
      expect(vegScore, greaterThan(nonVegScore));
    });

    test('Share pipeline query omits food and occupant tokens', () {
      const filters = ListingSearchFilters(
        foodPreference: 'veg',
        occupantType: 'Students',
        genderPreference: 'girls',
        keywords: ['ensuite'],
      );

      final query = filters.toPipelineQuery(towerPropertyType: 'Share');

      expect(query, isNot(contains('veg')));
      expect(query, isNot(contains('student')));
      expect(query, contains('girls'));
      expect(query, contains('ensuite'));
    });
  });
}
