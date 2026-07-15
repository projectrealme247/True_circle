import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/services/neighborhood_amenities_service.dart';
import 'package:true_circle/services/structured_amenities_fallback_service.dart';
import 'package:true_circle/services/transit_extraction_service.dart';
import 'package:true_circle/utils/geo_math.dart';
import 'package:true_circle/utils/proximity_display_builder.dart';
import 'package:true_circle/utils/proximity_phase1_policy.dart';

const hollywoodrathLat = 53.42489;
const hollywoodrathLon = -6.37296;
const tallaghtLat = 53.2885;
const tallaghtLon = -6.3575;

void main() {
  group('Hollywoodrath proximity pipeline (Phase 1, no Overpass)', () {
    test('structured fallback is outside 2.5 km radius for all curated POIs', () {
      final structured = StructuredAmenitiesFallbackService.resolve(
        latitude: hollywoodrathLat,
        longitude: hollywoodrathLon,
      );
      expect(structured, isNull);
    });

    test('Tallaght structured fallback is populated', () {
      final structured = StructuredAmenitiesFallbackService.resolve(
        latitude: tallaghtLat,
        longitude: tallaghtLon,
      );
      expect(structured, isNotNull);
      expect(structured!.isEmpty, isFalse);
      expect(structured.supermarketName, isNotNull);
      expect(structured.transitLine, isNotNull);
    });

    test('Hollywoodrath nearest curated POIs exceed fallback radius', () {
      const pois = [
        ('Tesco Blanchardstown', 53.3915, -6.3938),
        ('Sacred Heart Hollystown', 53.3948, -6.4012),
        ('Blanchardstown Bus', 53.3920, -6.3915),
        ('Hartstown CS', 53.3965, -6.4185),
      ];
      for (final poi in pois) {
        final km = GeoMath.haversineKm(
          LatLng(hollywoodrathLat, hollywoodrathLon),
          LatLng(poi.$2, poi.$3),
        );
        expect(km, greaterThan(2.5), reason: '${poi.$1} at ${km.toStringAsFixed(2)} km');
      }
    });

    test('Tallaght nearest curated POIs within fallback radius', () {
      const pois = [
        ('Tesco Tallaght', 53.2885, -6.3575),
        ('Luas The Square', 53.2857, -6.3732),
      ];
      for (final poi in pois) {
        final km = GeoMath.haversineKm(
          LatLng(tallaghtLat, tallaghtLon),
          LatLng(poi.$2, poi.$3),
        );
        expect(km, lessThanOrEqualTo(2.5), reason: '${poi.$1} at ${km.toStringAsFixed(2)} km');
      }
    });

    test('catalog lifestyle tags are empty beyond 3 km catalog radius', () async {
      final catalog = await NeighborhoodAmenitiesService.resolve(
        latitude: hollywoodrathLat,
        longitude: hollywoodrathLon,
      );
      expect(catalog, isEmpty);
    });

    test('Path B transit is null locally; nearest exceeds 20 min Phase 1 gate', () {
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

    test('display builder empty when only Phase 1 controllers are blank', () {
      const input = ProximityDisplayInput();
      final chips = ProximityDisplayBuilder.build(input);
      expect(chips, isEmpty);
    });

    test('display builder produces zero visible chips when all sources empty', () async {
      final catalog = await NeighborhoodAmenitiesService.resolve(
        latitude: hollywoodrathLat,
        longitude: hollywoodrathLon,
      );
      final merged = mergeAmenityTags(catalog, const []);
      expect(merged, isEmpty);

      final input = ProximityDisplayInput(lifestyleTags: merged);
      final chips = ProximityDisplayBuilder.build(input);
      expect(chips, isEmpty);
    });
  });
}
