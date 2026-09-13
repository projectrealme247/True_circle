import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/listing_creation_form_models.dart';
import 'package:true_circle/models/neighborhood_amenity_tag.dart';
import 'package:true_circle/services/overpass_amenities_service.dart';
import 'package:true_circle/utils/listing_data.dart';

void main() {
  group('Proximity persistence Phase A', () {
    NeighborhoodProximityDraft richDraft() {
      return NeighborhoodProximityDraft(
        transportLine: 'Dublin Bus · The Oaks',
        transportWalkMin: 3,
        groceryBrand: 'Spar',
        groceryWalkMin: 6,
        groceries: const [
          NearbyGroceryOption(brand: 'Spar', walkMin: 6),
          NearbyGroceryOption(brand: 'Tesco', walkMin: 10),
          NearbyGroceryOption(brand: 'SuperValu', walkMin: 11),
        ],
        extraTransit: const [
          NearbyExtraTransit(line: 'Luas · Broombridge', walkMin: 18),
        ],
        primarySchool: 'Tyrrelstown Educate Together National School',
        primarySchoolWalkMin: 9,
        secondarySchool: 'Le Chéile Secondary School',
        secondarySchoolWalkMin: 14,
        collegeSchool: 'TU Dublin Blanchardstown',
        collegeWalkMin: 16,
        gpClinic: 'Limitless Health',
        gpWalkMin: 7,
        lifestyleTags: const [
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.atms,
            name: 'ATM',
            distanceKm: 0.2,
            emoji: '🏧',
          ),
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.cafe,
            name: '5 To Go',
            distanceKm: 0.4,
            emoji: '☕',
          ),
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.pizzaShops,
            name: "Domino's",
            distanceKm: 0.5,
            emoji: '🍕',
          ),
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.gym,
            name: 'McCrudden Fitness',
            distanceKm: 0.8,
            emoji: '🏋️',
          ),
        ],
        customPoints: [
          CustomProximityPoint(
            category: ProximityPointCategory.amenity,
            name: 'Corduff Primary Care Centre',
            walkMin: 11,
          ),
        ],
      );
    }

    test('draft round-trip keeps full proximity snapshot', () {
      final restored = NeighborhoodProximityDraft.fromJson(richDraft().toJson());

      expect(restored.transportLine, 'Dublin Bus · The Oaks');
      expect(restored.groceries.map((g) => g.brand).toList(), [
        'Spar',
        'Tesco',
        'SuperValu',
      ]);
      expect(restored.extraTransit.single.line, 'Luas · Broombridge');
      expect(
        restored.primarySchool,
        'Tyrrelstown Educate Together National School',
      );
      expect(restored.primarySchoolWalkMin, 9);
      expect(restored.secondarySchool, 'Le Chéile Secondary School');
      expect(restored.secondarySchoolWalkMin, 14);
      expect(restored.collegeSchool, 'TU Dublin Blanchardstown');
      expect(restored.collegeWalkMin, 16);
      expect(restored.gpClinic, 'Limitless Health');
      expect(restored.gpWalkMin, 7);
      expect(restored.lifestyleTags.map((t) => t.name).toList(), [
        'ATM',
        '5 To Go',
        "Domino's",
        'McCrudden Fitness',
      ]);
      expect(restored.customPoints.single.name, 'Corduff Primary Care Centre');
    });

    test('normalizeItem keeps neighborhood_proximity snapshot and lifestyle tags',
        () {
      final proximity = richDraft().toJson();
      final listing = {
        'id': 'persist-a-1',
        'title': 'Tyrrelstown Flat',
        'price': '1800',
        'location': 'Dublin 15',
        'type': 'Rent',
        'description': 'Test',
        'neighborhood_proximity': proximity,
        'neighborhood_lifestyle_tags': [
          '🏧 ATM (200m)',
          '☕ 5 To Go (400m)',
        ],
        'proximity_data': {
          'nearest_stop_name': 'The Oaks',
          'walk_minutes': 3,
          'transit_type': 'Dublin Bus',
        },
      };

      final normalized = ListingData.normalizeItem(listing);
      expect(normalized['neighborhood_proximity'], isA<Map>());
      final saved = Map<String, dynamic>.from(
        normalized['neighborhood_proximity'] as Map,
      );
      expect(saved['groceries'], hasLength(3));
      expect(saved['extra_transit'], hasLength(1));
      expect(saved['lifestyle_tags'], hasLength(4));
      expect(saved['college_school'], 'TU Dublin Blanchardstown');
      expect(saved['gp_clinic'], 'Limitless Health');
      expect(saved['primary_school_walk_min'], 9);
      expect(normalized['neighborhood_lifestyle_tags'], hasLength(2));
      expect(normalized['proximity_data'], isA<Map>());

      final afterReload = NeighborhoodProximityDraft.fromJson(saved);
      expect(afterReload.groceries, hasLength(3));
      expect(afterReload.lifestyleTags, hasLength(4));
      expect(afterReload.gpClinic, 'Limitless Health');
    });
  });
}
