import 'package:flutter_test/flutter_test.dart';

import 'package:true_circle/utils/filter_inventory_stats.dart';
import 'package:true_circle/utils/listing_data.dart';
import 'package:true_circle/utils/listing_search_intent.dart';

void main() {
  group('FilterOptionInventoryStats', () {
    test('caption formats containing and filtered counts', () {
      const stats = FilterOptionInventoryStats(
        containingCount: 12,
        filteredOutCount: 8,
        referencePoolCount: 20,
      );
      expect(
        stats.caption,
        '12 spaces with this · 8 spaces filtered out',
      );
    });

    test('removesMajority is true above 50%', () {
      const stats = FilterOptionInventoryStats(
        containingCount: 4,
        filteredOutCount: 11,
        referencePoolCount: 20,
      );
      expect(stats.removesMajority, isTrue);
    });

    test('removesMajority is false at exactly half', () {
      const stats = FilterOptionInventoryStats(
        containingCount: 10,
        filteredOutCount: 10,
        referencePoolCount: 20,
      );
      expect(stats.removesMajority, isFalse);
    });
  });

  group('FilterInventoryAnalyzer', () {
    final listings = [
      {
        'type': 'Rent',
        'title': 'Veg flat Dublin 4',
        'location': 'Dublin 4',
        'rent': 2000,
        'hostFoodPreference': 'veg',
        'preferred_tenant_type': 'Students',
      },
      {
        'type': 'Rent',
        'title': 'Non-veg house Dublin 12',
        'location': 'Dublin 12',
        'rent': 1800,
        'hostFoodPreference': 'non-veg',
        'preferred_tenant_type': 'Working Professionals',
      },
      {
        'type': 'Rent',
        'title': 'Any diet Dublin 6',
        'location': 'Dublin 6',
        'rent': 2200,
      },
    ];

    test('containingCount reflects listings with attribute', () {
      final analyzer = FilterInventoryAnalyzer(
        allListings: listings,
        towerPropertyType: 'Rent',
        userSession: null,
      );

      final vegStats = analyzer.statsFor(
        const ListingSearchFilters(),
        FilterInventoryDimension.food,
        'veg',
      );

      expect(vegStats.containingCount, 1);
      expect(
        listings
            .where((l) => ListingSearchIntent.matchesFood(l, 'veg'))
            .length,
        1,
      );
    });

    test('area filter filteredOutCount reduces visible pool', () {
      final analyzer = FilterInventoryAnalyzer(
        allListings: listings,
        towerPropertyType: 'Rent',
        userSession: null,
      );

      final stats = analyzer.statsFor(
        const ListingSearchFilters(),
        FilterInventoryDimension.area,
        'dublin4',
      );

      expect(stats.referencePoolCount, 3);
      expect(stats.filteredOutCount, greaterThan(0));
      expect(stats.containingCount, lessThan(3));
    });

    test('highImpactActiveFilters flags majority-removing active filters', () {
      final analyzer = FilterInventoryAnalyzer(
        allListings: listings,
        towerPropertyType: 'Rent',
        userSession: null,
      );

      final filters = const ListingSearchFilters(
        targetSearchAreas: ['dublin4'],
      );

      final impacts = analyzer.highImpactActiveFilters(filters);
      expect(impacts, isNotEmpty);
      expect(
        impacts.any((impact) => impact.label.contains('Dublin')),
        isTrue,
      );
      for (final impact in impacts) {
        expect(impact.stats.removesMajority, isTrue);
      }
    });

    test('inventoryTotal counts tower listings only', () {
      final mixed = [
        ...listings,
        {'type': 'Share', 'title': 'Shared room'},
      ];
      final analyzer = FilterInventoryAnalyzer(
        allListings: mixed,
        towerPropertyType: 'Rent',
        userSession: null,
      );
      expect(analyzer.inventoryTotal, 3);
      expect(
        mixed.where((l) => ListingData.propertyType(l) == 'Rent').length,
        3,
      );
    });
  });
}
