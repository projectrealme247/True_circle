import 'package:flutter_test/flutter_test.dart';

import 'package:true_circle/utils/listing_data.dart';
import 'package:true_circle/utils/listing_search_intent.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';

void main() {
  group('ListingSearchIntent Dublin — order independent', () {
    final permutations = [
      '1 bed in dublin 4',
      'dublin 4 1 bed',
      'in dublin 4 1 bed',
      '1bed dublin 4',
    ];

    for (final query in permutations) {
      test('parses city + bedroom: $query', () {
        final intent = ListingSearchIntent.parseQuery(query);
        expect(intent.city, 'dublin4', reason: query);
        expect(intent.remainingKeywords, contains('1bed'), reason: query);
        expect(intent.remainingKeywords, isNot(contains('bed')), reason: query);
      });
    }

    test('1 bed in dublin 4 excludes dublin 12 on Rent tower', () {
      final intent = ListingSearchIntent.parseQuery('1 bed in dublin 4');
      final rent = SampleListingsDublin.items
          .where((l) => ListingData.propertyType(l) == 'Rent')
          .toList();
      final filtered = ListingSearchIntent.applyFiltersStrict(rent, intent);
      expect(filtered, isNotEmpty);
      for (final item in filtered) {
        expect(
          ListingData.location(item).toLowerCase(),
          isNot(contains('dublin 12')),
          reason: item['title'] as String?,
        );
      }
      expect(
        filtered.every(
          (l) => ListingSearchIntent.parseQuery('1 bed').remainingKeywords
              .every((k) => ListingSearchIntent.applyFiltersStrict(
                    [l],
                    ListingSearchIntent.parseQuery('1 bed'),
                  ).isNotEmpty),
        ),
        isTrue,
      );
    });

    test('non veg in dublin 4 parses food and city', () {
      final intent = ListingSearchIntent.parseQuery('non veg in dublin 4');
      expect(intent.food, 'non-veg');
      expect(intent.city, 'dublin4');
    });

    test('3 bed in dundrum parses bedroom and city', () {
      final intent = ListingSearchIntent.parseQuery('3 bed in dundrum');
      expect(intent.city, 'dublin14');
      expect(intent.remainingKeywords, contains('3bed'));
    });

    test('dublin 4 does not match dublin 12 listings', () {
      final d12 = SampleListingsDublin.items.firstWhere(
        (l) => ListingData.location(l).contains('Dublin 12'),
      );
      expect(ListingData.matchesCityFilter(d12, 'dublin4'), isFalse);
      expect(ListingData.matchesCityFilter(d12, 'dublin12'), isTrue);
    });

    test('dublin 4 matches sandymount listing location', () {
      final d4 = SampleListingsDublin.items.firstWhere(
        (l) => ListingData.location(l) == 'Dublin 4',
      );
      expect(ListingData.matchesCityFilter(d4, 'dublin4'), isTrue);
    });
  });
}
