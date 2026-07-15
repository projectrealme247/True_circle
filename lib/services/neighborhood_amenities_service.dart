import '../models/neighborhood_amenity_tag.dart';

import '../data/poi_catalog_kind.dart';

import '../data/poi_catalog_repository.dart';

import '../utils/geo_math.dart';



/// Curated Dublin POI + haversine lookup for lifestyle amenity tags.

abstract final class NeighborhoodAmenitiesService {

  static const _radiusKm = 3.0;



  static Future<List<NeighborhoodAmenityTag>> resolve({

    required double latitude,

    required double longitude,

  }) async {

    final origin = LatLng(latitude, longitude);

    final results = <NeighborhoodAmenityTag>[];



    for (final category in NeighborhoodAmenityCategory.values) {

      final nearest = _nearestInCategory(origin, category);

      if (nearest != null) results.add(nearest);

    }



    return results;

  }



  static NeighborhoodAmenityTag? _nearestInCategory(

    LatLng origin,

    NeighborhoodAmenityCategory category,

  ) {

    ({String name, double km})? best;



    for (final poi in _activeCatalog) {

      if (poi.category != category) continue;

      final km = GeoMath.haversineKm(origin, LatLng(poi.lat, poi.lon));

      if (km > _radiusKm) continue;

      if (best == null || km < best.km) {

        best = (name: poi.name, km: km);

      }

    }



    if (best == null) return null;

    return NeighborhoodAmenityTag(

      category: category,

      name: best.name,

      distanceKm: best.km,

      emoji: _emojiFor(category),

    );

  }



  static List<_Poi> get _activeCatalog {

    if (!PoiCatalogRepository.hasSeededDublinCatalog) {

      return _legacyCatalog;

    }

    return [

      for (final entry in PoiCatalogRepository.lifestyleEntries())

        if (lifestyleCategoryForKind(entry.kind) != null)

          _Poi(

            entry.name,

            entry.lat,

            entry.lon,

            lifestyleCategoryForKind(entry.kind)!,

          ),

    ];

  }



  static String _emojiFor(NeighborhoodAmenityCategory category) =>

      switch (category) {

        NeighborhoodAmenityCategory.asianStores => '🛍️',

        NeighborhoodAmenityCategory.pubs => '🍺',

        NeighborhoodAmenityCategory.pizzaShops => '🍕',

        NeighborhoodAmenityCategory.atms => '🏧',

        NeighborhoodAmenityCategory.foodJoints => '☕',

        NeighborhoodAmenityCategory.gym => '🏋️',

        NeighborhoodAmenityCategory.park => '🌳',

        NeighborhoodAmenityCategory.pharmacy => '💊',

        NeighborhoodAmenityCategory.cafe => '☕',

        NeighborhoodAmenityCategory.restaurant => '🍽️',

        NeighborhoodAmenityCategory.businessPark => '🏢',

        NeighborhoodAmenityCategory.attraction => '🎭',

      };



  static const _legacyCatalog = <_Poi>[

    _Poi('Asia Market', 53.3498, -6.2603, NeighborhoodAmenityCategory.asianStores),

    _Poi('Asia Market Drimnagh', 53.3289, -6.3194, NeighborhoodAmenityCategory.asianStores),

    _Poi('Lidl Asia Aisle Hub', 53.3412, -6.2671, NeighborhoodAmenityCategory.asianStores),

    _Poi('Dunnes Stores Asian Foods', 53.3551, -6.2654, NeighborhoodAmenityCategory.asianStores),

    _Poi('Oriental Pantry', 53.3682, -6.2518, NeighborhoodAmenityCategory.asianStores),

    _Poi('Sunflower Asian Market', 53.3912, -6.2456, NeighborhoodAmenityCategory.asianStores),

    _Poi('Asia Market Blanchardstown', 53.3918, -6.3924, NeighborhoodAmenityCategory.asianStores),

    _Poi('Tesco Blanchardstown', 53.3915, -6.3938, NeighborhoodAmenityCategory.asianStores),

    _Poi('Dunnes Stores Blanchardstown', 53.3926, -6.3908, NeighborhoodAmenityCategory.asianStores),

    _Poi('The Brazen Head', 53.3458, -6.2769, NeighborhoodAmenityCategory.pubs),

    _Poi('The Stag\'s Head', 53.3451, -6.2598, NeighborhoodAmenityCategory.pubs),

    _Poi('O\'Donoghues', 53.3356, -6.2543, NeighborhoodAmenityCategory.pubs),

    _Poi('The Bernard Shaw', 53.3602, -6.2651, NeighborhoodAmenityCategory.pubs),

    _Poi('The Long Hall', 53.3436, -6.2591, NeighborhoodAmenityCategory.pubs),

    _Poi('The Camden', 53.3348, -6.2655, NeighborhoodAmenityCategory.pubs),

    _Poi('The Dubliner Blanchardstown', 53.3931, -6.3889, NeighborhoodAmenityCategory.pubs),

    _Poi('The Hole in the Wall', 53.3678, -6.3633, NeighborhoodAmenityCategory.pubs),

    _Poi('Porterhouse Square', 53.3920, -6.3912, NeighborhoodAmenityCategory.pubs),

    _Poi('Brother Hubbard', 53.3454, -6.2678, NeighborhoodAmenityCategory.foodJoints),

    _Poi('Kaph', 53.3419, -6.2612, NeighborhoodAmenityCategory.foodJoints),

    _Poi('Honey Truffle', 53.3331, -6.2549, NeighborhoodAmenityCategory.foodJoints),

    _Poi('Dash Container Cafe', 53.3491, -6.2608, NeighborhoodAmenityCategory.foodJoints),

    _Poi('Leo Burdock', 53.3432, -6.2675, NeighborhoodAmenityCategory.foodJoints),

    _Poi('Bewley\'s Grafton Street', 53.3421, -6.2595, NeighborhoodAmenityCategory.foodJoints),

    _Poi('Blanchardstown Centre Food Court', 53.3922, -6.3915, NeighborhoodAmenityCategory.foodJoints),

    _Poi('Costa Coffee Blanchardstown', 53.3924, -6.3902, NeighborhoodAmenityCategory.foodJoints),

    _Poi('Insomnia Coffee Castleknock', 53.3684, -6.3648, NeighborhoodAmenityCategory.foodJoints),

    _Poi('Four Star Pizza Blanchardstown', 53.3928, -6.3895, NeighborhoodAmenityCategory.pizzaShops),

    _Poi('Domino\'s Blanchardstown', 53.3910, -6.3942, NeighborhoodAmenityCategory.pizzaShops),

    _Poi('Apache Pizza Tyrrelstown', 53.4012, -6.4128, NeighborhoodAmenityCategory.pizzaShops),

    _Poi('Milano Temple Bar', 53.3455, -6.2648, NeighborhoodAmenityCategory.pizzaShops),

    _Poi('La Dolce Vita Ranelagh', 53.3251, -6.2548, NeighborhoodAmenityCategory.pizzaShops),

    _Poi('Fire & Stone Camden St', 53.3342, -6.2658, NeighborhoodAmenityCategory.pizzaShops),

    _Poi('AIB ATM Blanchardstown Centre', 53.3920, -6.3918, NeighborhoodAmenityCategory.atms),

    _Poi('Bank of Ireland ATM Castleknock', 53.3686, -6.3652, NeighborhoodAmenityCategory.atms),

    _Poi('Ulster Bank ATM O\'Connell St', 53.3496, -6.2595, NeighborhoodAmenityCategory.atms),

    _Poi('PTSB ATM Grafton Street', 53.3418, -6.2592, NeighborhoodAmenityCategory.atms),

    _Poi('AIB ATM Tyrrelstown', 53.4008, -6.4135, NeighborhoodAmenityCategory.atms),

    _Poi('Asia Market Tallaght', 53.2875, -6.3765, NeighborhoodAmenityCategory.asianStores),

    _Poi('Costa Coffee The Square', 53.2860, -6.3735, NeighborhoodAmenityCategory.cafe),

    _Poi('Domino\'s Tallaght', 53.2855, -6.3710, NeighborhoodAmenityCategory.pizzaShops),

  ];

}



class _Poi {

  const _Poi(this.name, this.lat, this.lon, this.category);



  final String name;

  final double lat;

  final double lon;

  final NeighborhoodAmenityCategory category;

}

