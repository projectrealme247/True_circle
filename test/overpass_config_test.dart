import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/neighborhood_amenity_tag.dart';
import 'package:true_circle/services/overpass_amenities_service.dart';
import 'package:true_circle/services/overpass_config.dart';
import 'package:true_circle/services/overpass_full_query.dart';

void main() {
  test('request timeout exceeds query timeout by safety buffer', () {
    for (final type in OverpassQueryType.values) {
      final querySeconds = OverpassConfig.queryTimeoutSeconds(type);
      final requestSeconds = OverpassConfig.requestTimeoutFor(type).inSeconds;
      expect(
        requestSeconds,
        querySeconds + OverpassConfig.safetyBuffer.inSeconds,
      );
      expect(
        OverpassConfig.requestTimeoutFor(type),
        greaterThan(Duration(seconds: querySeconds)),
      );
    }
  });

  test('query headers use centralized timeout seconds', () {
    expect(
      buildFullOverpassQuery('53.424890', '-6.372960'),
      startsWith(
        '[out:json][timeout:${OverpassConfig.fullQueryTimeoutSeconds}]',
      ),
    );
    expect(
      buildEssentialsOverpassQuery('53.424890', '-6.372960'),
      startsWith(
        '[out:json][timeout:${OverpassConfig.essentialsQueryTimeoutSeconds}]',
      ),
    );
  });

  test('Hollywoodrath full request allows 23s before client abort', () {
    expect(OverpassConfig.queryTimeoutSeconds(OverpassQueryType.full), 18);
    expect(
      OverpassConfig.requestTimeoutFor(OverpassQueryType.full).inSeconds,
      23,
    );
  });

  test('essentials query includes lifestyle selectors from full query', () {
    final essentials = buildEssentialsOverpassQuery('53.424890', '-6.372960');
    final full = buildFullOverpassQuery('53.424890', '-6.372960');
    const lifestyleSelectors = [
      'node["amenity"~"pub|bar|biergarten"](around:1200,',
      'node["amenity"="atm"](around:1000,',
      'node["amenity"="bank"](around:1000,',
      'node["shop"~"pizza"](around:1500,',
      'node["amenity"~"fast_food"](around:1500,',
      'node["leisure"~"fitness_centre|sports_centre"](around:1500,',
      'way["leisure"~"fitness_centre|sports_centre"](around:1500,',
      'node["leisure"="park"](around:1200,',
      'way["leisure"="park"](around:1200,',
      'node["amenity"="pharmacy"](around:1000,',
      'node["amenity"="cafe"](around:800,',
      'node["amenity"~"restaurant"](around:1000,',
    ];
    for (final selector in lifestyleSelectors) {
      expect(essentials, contains(selector), reason: selector);
      expect(full, contains(selector), reason: 'full missing $selector');
    }
  });

  test('hasEnrichmentCoverage rejects transport+grocery-only snapshots', () {
    const thin = NearbyAmenities(
      supermarketName: 'Spar',
      transitLine: 'Dublin Bus · The Oaks',
    );
    expect(thin.isEmpty, isFalse);
    expect(thin.hasEnrichmentCoverage, isFalse);

    const withSchool = NearbyAmenities(primarySchool: 'Local NS');
    expect(withSchool.hasEnrichmentCoverage, isTrue);

    const withLifestyle = NearbyAmenities(
      lifestyleTags: [
        NeighborhoodAmenityTag(
          category: NeighborhoodAmenityCategory.park,
          name: 'Local Park',
          distanceKm: 0.5,
          emoji: '🌳',
        ),
      ],
    );
    expect(withLifestyle.hasEnrichmentCoverage, isTrue);
  });
}
