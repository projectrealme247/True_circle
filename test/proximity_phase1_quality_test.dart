import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/neighborhood_amenity_tag.dart';
import 'package:true_circle/services/neighborhood_amenities_service.dart';
import 'package:true_circle/services/overpass_amenities_service.dart';
import 'package:true_circle/services/structured_amenities_fallback_service.dart';
import 'package:true_circle/services/transit_extraction_service.dart';
import 'package:true_circle/utils/proximity_phase1_policy.dart';

/// Hollywoodrath / Hollystown — suburban pin used for Phase 1 quality checks.
const hollywoodrathLat = 53.412;
const hollywoodrathLon = -6.418;

void main() {
  group('ProximityPhase1Policy', () {
    test('mergeAmenityTags dedupes by category and normalized name', () {
      final deduped = mergeAmenityTags(
        const [
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.asianStores,
            name: 'Asia Market Blanchardstown',
            distanceKm: 2.1,
            emoji: '🛍️',
          ),
        ],
        const [
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.asianStores,
            name: 'asia market blanchardstown',
            distanceKm: 2.0,
            emoji: '🛍️',
          ),
          NeighborhoodAmenityTag(
            category: NeighborhoodAmenityCategory.cafe,
            name: 'Corner Cafe',
            distanceKm: 0.8,
            emoji: '☕',
          ),
        ],
      );
      expect(deduped, hasLength(2));
      expect(deduped.any((t) => t.name == 'Corner Cafe'), isTrue);
    });

    test('filterNearbyAmenitiesForPhase1 keeps confident fields only', () {
      const amenities = NearbyAmenities(
        transitLine: 'Dublin Bus · Far Stop',
        transitWalkMin: 41,
        supermarketName: 'Tesco',
        supermarketWalkMin: 18,
        primarySchool: 'Near School',
        primarySchoolWalkMin: 19,
        secondarySchool: 'Far School',
        secondarySchoolWalkMin: 28,
        extraTransit: [
          NearbyExtraTransit(line: 'Hospital · Far', walkMin: 35),
          NearbyExtraTransit(line: 'Luas · Close', walkMin: 12),
        ],
      );

      final filtered = filterNearbyAmenitiesForPhase1(amenities);

      expect(filtered.transitLine, isNull);
      expect(filtered.supermarketName, 'Tesco');
      expect(filtered.primarySchool, 'Near School');
      expect(filtered.secondarySchool, isNull);
      expect(filtered.extraTransit, hasLength(1));
      expect(filtered.extraTransit.first.line, contains('Luas'));
    });

    test('filterNearbyAmenitiesForPhase1 skips schools without walk minutes', () {
      const noWalkSchool = NearbyAmenities(primarySchool: 'Unknown School');
      expect(
        filterNearbyAmenitiesForPhase1(noWalkSchool).primarySchool,
        isNull,
      );
    });
  });

  group('Hollywoodrath Phase 1 (53.412, -6.418)', () {
    test('catalog is sparse; merge preserves structured lifestyle when present', () async {
      final catalog = await NeighborhoodAmenitiesService.resolve(
        latitude: hollywoodrathLat,
        longitude: hollywoodrathLon,
      );
      final structured = StructuredAmenitiesFallbackService.resolve(
        latitude: hollywoodrathLat,
        longitude: hollywoodrathLon,
      );

      expect(catalog, isNotEmpty);

      final merged = mergeAmenityTags(
        catalog,
        structured?.lifestyleTags ?? const [],
      );
      expect(
        merged.length,
        greaterThanOrEqualTo(catalog.length),
      );
      if ((structured?.lifestyleTags ?? const []).isNotEmpty) {
        expect(merged.length, greaterThan(catalog.length));
      }
    });

    test('extractNearest transit is beyond Phase 1 confidence (not shown in Phase 1)', () {
      final local = TransitExtractionService.extractLocally(
        latitude: hollywoodrathLat,
        longitude: hollywoodrathLon,
      );
      final nearest = TransitExtractionService.extractNearest(
        latitude: hollywoodrathLat,
        longitude: hollywoodrathLon,
      );

      expect(local, isNull);
      expect(nearest, isNotNull);

      final walk = (nearest!['walk_minutes'] as num).toInt();
      expect(walk, greaterThan(phase1MaxConfidentWalkMin));
      expect(isConfidentProximityPayload(nearest), isFalse);
    });

    test('structured fallback proximity fields gated at 20 min walk', () {
      final structured = StructuredAmenitiesFallbackService.resolve(
        latitude: hollywoodrathLat,
        longitude: hollywoodrathLon,
      );
      if (structured == null) return;

      final filtered = filterNearbyAmenitiesForPhase1(structured);

      if (structured.transitWalkMin != null &&
          structured.transitWalkMin! > phase1MaxConfidentWalkMin) {
        expect(filtered.transitLine, isNull);
      }

      if (structured.primarySchoolWalkMin != null &&
          structured.primarySchoolWalkMin! > phase1MaxConfidentWalkMin) {
        expect(filtered.primarySchool, isNull);
      }

      if (structured.secondarySchoolWalkMin != null &&
          structured.secondarySchoolWalkMin! > phase1MaxConfidentWalkMin) {
        expect(filtered.secondarySchool, isNull);
      }

      for (final extra in filtered.extraTransit) {
        expect(extra.walkMin, lessThanOrEqualTo(phase1MaxConfidentWalkMin));
      }
    });
  });
}
