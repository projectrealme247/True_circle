import 'package:flutter_test/flutter_test.dart';

import 'package:true_circle/models/irish_address_suggestion.dart';

import 'package:true_circle/models/neighborhood_amenity_tag.dart';

import 'package:true_circle/services/overpass_amenities_service.dart';

import 'package:true_circle/services/proximity_resolution_cache.dart';



void main() {

  tearDown(ProximityResolutionCache.clear);



  test('keyFor rounds to four decimal places (~11m cell)', () {

    expect(

      ProximityResolutionCache.keyFor(53.349812, -6.260314),

      ProximityResolutionCache.keyFor(53.349819, -6.260319),

    );

    expect(

      ProximityResolutionCache.keyFor(53.349812, -6.260314),

      isNot(ProximityResolutionCache.keyFor(53.350812, -6.260314)),

    );

  });



  test('putProximity and getProximity round-trip transit-only snapshot', () {

    const key = '53.3498:-6.2603';

    const tags = [

      NeighborhoodAmenityTag(

        category: NeighborhoodAmenityCategory.pubs,

        name: 'Test Pub',

        distanceKm: 0.4,

        emoji: '🍺',

      ),

    ];

    const snapshot = ProximityResolutionSnapshot(

      lifestyleTags: tags,

      transitPayload: {'transit_type': 'Luas', 'walk_minutes': 5},

    );

    expect(ProximityResolutionCache.putProximity(key, snapshot), isTrue);

    expect(ProximityResolutionCache.getProximity(key), snapshot);

  });



  test('putProximity caches amenities-only snapshot', () {

    const key = '53.4249:-6.3730';

    const snapshot = ProximityResolutionSnapshot(

      lifestyleTags: [],

      amenities: NearbyAmenities(

        supermarketName: 'Spar',

        supermarketWalkMin: 6,

        transitLine: 'Dublin Bus · The Oaks',

        transitWalkMin: 3,

      ),

    );

    expect(ProximityResolutionCache.putProximity(key, snapshot), isTrue);

    expect(ProximityResolutionCache.getProximity(key), snapshot);

  });



  test('Hollywoodrath failed enrichment is not cached and allows retry', () {

    const hollywoodrathLat = 53.42489;

    const hollywoodrathLon = -6.37296;

    final cellKey = ProximityResolutionCache.keyFor(

      hollywoodrathLat,

      hollywoodrathLon,

    );

    expect(cellKey, '53.4249:-6.3730');



    const failedSnapshot = ProximityResolutionSnapshot(

      lifestyleTags: [],

      amenities: null,

      transitPayload: null,

    );

    expect(failedSnapshot.isCacheable, isFalse);

    expect(failedSnapshot.cacheTypeLabel, 'empty-enrichment');



    // First lookup: failed Phase 2 must not poison the cache.

    expect(

      ProximityResolutionCache.putProximity(cellKey, failedSnapshot),

      isFalse,

    );



    // Second lookup: cache miss — form will run Overpass again.

    expect(ProximityResolutionCache.getProximity(cellKey), isNull);

  });



  test('clear removes all session entries', () {

    ProximityResolutionCache.putGeocode(

      '53.3498:-6.2603',

      IrishAddressSuggestion(

        displayLabel: 'Test',

        streetLine: 'Test',

        area: 'Dublin 2',

        county: 'Dublin',

        latitude: 53.3498,

        longitude: -6.2603,

      ),

    );

    ProximityResolutionCache.clear();

    expect(ProximityResolutionCache.getGeocode('53.3498:-6.2603'), isNull);

  });

}


