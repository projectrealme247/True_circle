import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/neighborhood_amenity_tag.dart';
import 'package:true_circle/models/proximity_display_chip.dart';
import 'package:true_circle/services/overpass_amenities_service.dart';
import 'package:true_circle/utils/proximity_display_builder.dart';

void main() {
  group('ProximityDisplayBuilder', () {
    test('Clontarf-like snapshot shows transport, groceries, education sections', () {
      const input = ProximityDisplayInput(
        transportLine: 'Luas · The Point',
        transportWalkMin: 22,
        groceryBrand: 'Centra',
        groceryWalkMin: 5,
        groceries: [
          NearbyGroceryOption(brand: 'Centra', walkMin: 5),
          NearbyGroceryOption(brand: 'Spar', walkMin: 8),
        ],
        primarySchool: 'The Larkin Early Education Service',
        secondarySchool: 'Rosmini Community School',
        extraTransit: [
          NearbyExtraTransit(line: 'DART · Clontarf Road', walkMin: 2),
          NearbyExtraTransit(line: 'Dublin Bus · Clontarf Station', walkMin: 1),
        ],
        lifestyleTags: [
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.pubs,
            name: 'Barcode',
            distanceKm: 0.123,
            emoji: '🍺',
          ),
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.cafe,
            name: 'Green Land Café',
            distanceKm: 0.316,
            emoji: '☕',
          ),
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.pharmacy,
            name: "Corrigan's Pharmacy",
            distanceKm: 0.45,
            emoji: '💊',
          ),
        ],
      );

      final profile = ProximityDisplayBuilder.buildProfile(input);
      final transport = profile.firstWhere((s) => s.title == 'Transport');
      final groceries = profile.firstWhere((s) => s.title == 'Groceries');
      final education = profile.firstWhere((s) => s.title == 'Education');
      final lifestyle = profile.firstWhere((s) => s.title == 'Lifestyle');
      final healthcare = profile.firstWhere((s) => s.title == 'Healthcare');

      expect(
        transport.chips.map((c) => c.label),
        containsAll([
          contains('Dublin Bus'),
          contains('DART'),
          contains('Luas'),
        ]),
      );
      expect(groceries.chips, hasLength(2));
      expect(education.chips, hasLength(2));
      expect(lifestyle.chips.length, greaterThanOrEqualTo(2));
      expect(
        healthcare.chips.any((c) => c.label.contains("Corrigan's Pharmacy")),
        isTrue,
      );
    });

    test('transport section shows nearest DART, Luas, and Bus separately', () {
      const input = ProximityDisplayInput(
        transportLine: 'Luas · The Point',
        transportWalkMin: 22,
        extraTransit: [
          NearbyExtraTransit(line: 'DART · Clontarf Road', walkMin: 2),
          NearbyExtraTransit(line: 'Dublin Bus · Clontarf Station', walkMin: 1),
        ],
      );

      final transport = ProximityDisplayBuilder.buildProfile(input)
          .firstWhere((s) => s.title == 'Transport');

      expect(transport.chips.any((c) => c.label.contains('Dublin Bus')), isTrue);
      expect(transport.chips.any((c) => c.label.contains('DART')), isTrue);
      expect(transport.chips.any((c) => c.label.contains('Luas')), isTrue);
    });

    test('major grocery brands are tier 1; Spar is tier 2', () {
      const tesco = ProximityDisplayInput(
        groceries: [NearbyGroceryOption(brand: 'Tesco', walkMin: 8)],
      );
      const spar = ProximityDisplayInput(
        groceries: [NearbyGroceryOption(brand: 'Spar', walkMin: 6)],
      );

      final tescoChip =
          ProximityDisplayBuilder.buildProfile(tesco).first.chips.single;
      final sparChip =
          ProximityDisplayBuilder.buildProfile(spar).first.chips.single;

      expect(tescoChip.tier, ProximityDisplayTier.tier1);
      expect(sparChip.tier, ProximityDisplayTier.tier2);
    });

    test('healthcare section includes pharmacy and hospital', () {
      const input = ProximityDisplayInput(
        gpClinic: 'Main Street Clinic',
        gpWalkMin: 9,
        extraTransit: [
          NearbyExtraTransit(line: 'Hospital · Mater', walkMin: 18),
        ],
        lifestyleTags: [
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.pharmacy,
            name: 'Local Pharmacy',
            distanceKm: 0.4,
            emoji: '💊',
          ),
        ],
      );

      final healthcare = ProximityDisplayBuilder.buildProfile(input)
          .firstWhere((s) => s.title == 'Healthcare');

      expect(
        healthcare.chips.any((c) => c.label.contains('Local Pharmacy')),
        isTrue,
      );
      expect(healthcare.chips.any((c) => c.label.contains('GP')), isTrue);
      expect(healthcare.chips.any((c) => c.label.contains('Mater')), isTrue);
    });

    test('lifestyle section surfaces ATM, pizza, cafe, pub, and gym tags', () {
      const input = ProximityDisplayInput(
        lifestyleTags: [
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.atms,
            name: 'Bank ATM',
            distanceKm: 0.2,
            emoji: '🏧',
          ),
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.pizzaShops,
            name: 'Pizza Point',
            distanceKm: 0.5,
            emoji: '🍕',
          ),
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.cafe,
            name: 'Corner Cafe',
            distanceKm: 0.3,
            emoji: '☕',
          ),
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.pubs,
            name: 'Local Pub',
            distanceKm: 0.4,
            emoji: '🍺',
          ),
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.gym,
            name: 'Fit Gym',
            distanceKm: 0.8,
            emoji: '🏋️',
          ),
        ],
      );

      final lifestyle = ProximityDisplayBuilder.buildProfile(input)
          .firstWhere((s) => s.title == 'Lifestyle');

      expect(lifestyle.chips, hasLength(5));
    });

    test('groceries section caps at three options sorted by walk time', () {
      const input = ProximityDisplayInput(
        groceries: [
          NearbyGroceryOption(brand: 'Tesco', walkMin: 12),
          NearbyGroceryOption(brand: 'Spar', walkMin: 4),
          NearbyGroceryOption(brand: 'Lidl', walkMin: 8),
          NearbyGroceryOption(brand: 'Centra', walkMin: 6),
        ],
      );

      final groceries = ProximityDisplayBuilder.buildProfile(input)
          .firstWhere((s) => s.title == 'Groceries');

      expect(groceries.chips, hasLength(3));
      expect(groceries.chips.first.label, contains('Spar'));
    });

    test('Asian grocery is shown separately outside the mainstream top-3 cap', () {
      const input = ProximityDisplayInput(
        groceries: [
          NearbyGroceryOption(brand: 'Spar', walkMin: 4),
          NearbyGroceryOption(brand: 'Centra', walkMin: 6),
          NearbyGroceryOption(brand: 'Lidl', walkMin: 8),
          NearbyGroceryOption(brand: 'Asia Market', walkMin: 28),
        ],
        lifestyleTags: [
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.asianStores,
            name: 'Asia Market',
            distanceKm: 2.2,
            emoji: '🛍️',
          ),
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.asianStores,
            name: 'Second Asia Market',
            distanceKm: 2.8,
            emoji: '🛍️',
          ),
        ],
      );

      final profile = ProximityDisplayBuilder.buildProfile(input);
      final groceries =
          profile.firstWhere((s) => s.title == 'Groceries');

      expect(groceries.chips, hasLength(4));
      expect(
        groceries.chips.take(3).map((c) => c.label),
        [
          contains('Spar'),
          contains('Centra'),
          contains('Lidl'),
        ],
      );
      expect(groceries.chips.last.label, contains('Asian Grocery'));
      expect(groceries.chips.last.label, contains('min'));
      expect(
        groceries.chips.where((c) => c.label.contains('Asian Grocery')),
        hasLength(1),
      );
      expect(
        profile.any((s) => s.title == 'Lifestyle'),
        isFalse,
      );
    });
  });
}
