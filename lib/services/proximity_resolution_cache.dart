import 'package:flutter/foundation.dart';



import '../models/irish_address_suggestion.dart';

import '../models/neighborhood_amenity_tag.dart';

import 'overpass_amenities_service.dart';



/// In-memory session cache for listing-location proximity resolution.

///

/// Keys use lat/lon rounded to 4 decimal places (~11 m) so minor pin nudges

/// reuse prior Overpass / transit / catalog results.

abstract final class ProximityResolutionCache {

  static final _proximityByCell = <String, ProximityResolutionSnapshot>{};

  static final _geocodeByCell = <String, IrishAddressSuggestion>{};

  static final _amenitiesByCell = <String, NearbyAmenities>{};



  /// ~11 m grid — four decimal places.

  static String keyFor(double latitude, double longitude) {

    return '${latitude.toStringAsFixed(4)}:${longitude.toStringAsFixed(4)}';

  }



  static ProximityResolutionSnapshot? getProximity(String cellKey) {

    final snapshot = _proximityByCell[cellKey];

    if (kDebugMode) {

      if (snapshot == null) {

        debugPrint(

          'ProximityResolutionCache read: cell=$cellKey '

          'snapshot=miss cache=miss',

        );

      } else {

        debugPrint(

          'ProximityResolutionCache read: cell=$cellKey '

          'snapshot=${snapshot.cacheTypeLabel} cache=hit',

        );

      }

    }

    return snapshot;

  }



  /// Stores [snapshot] only when Phase 2 enrichment produced usable data.

  ///

  /// Returns `true` when cached, `false` when skipped (failed enrichment).

  static bool putProximity(

    String cellKey,

    ProximityResolutionSnapshot snapshot,

  ) {

    final hasAmenities =

        snapshot.amenities != null && !snapshot.amenities!.isEmpty;

    final hasTransit = snapshot.transitPayload != null;

    final shouldCache = hasAmenities || hasTransit;



    if (kDebugMode) {

      debugPrint(

        'ProximityResolutionCache write: cell=$cellKey '

        'amenities=${hasAmenities ? 'yes' : 'no'} '

        'transit=${hasTransit ? 'yes' : 'no'} '

        'cached=${shouldCache ? 'yes' : 'no'}',

      );

    }



    if (!shouldCache) return false;



    _proximityByCell[cellKey] = snapshot;

    return true;

  }



  static IrishAddressSuggestion? getGeocode(String cellKey) =>

      _geocodeByCell[cellKey];



  static void putGeocode(String cellKey, IrishAddressSuggestion suggestion) {

    _geocodeByCell[cellKey] = suggestion;

  }



  static NearbyAmenities? getAmenities(String cellKey) =>

      _amenitiesByCell[cellKey];



  static void putAmenities(String cellKey, NearbyAmenities amenities) {

    _amenitiesByCell[cellKey] = amenities;

  }



  /// Test-only reset.

  static void clear() {

    _proximityByCell.clear();

    _geocodeByCell.clear();

    _amenitiesByCell.clear();

  }

}



/// Cached proximity UI payload for a coordinate cell.

class ProximityResolutionSnapshot {

  const ProximityResolutionSnapshot({

    required this.lifestyleTags,

    this.amenities,

    this.transitPayload,

  });



  final List<NeighborhoodAmenityTag> lifestyleTags;

  final NearbyAmenities? amenities;

  final Map<String, dynamic>? transitPayload;



  bool get hasEnrichedAmenities =>

      amenities != null && !amenities!.isEmpty;



  bool get hasTransitPayload => transitPayload != null;



  /// Whether this snapshot should be stored for session replay.

  bool get isCacheable => hasEnrichedAmenities || hasTransitPayload;



  String get cacheTypeLabel {

    if (hasEnrichedAmenities && hasTransitPayload) return 'amenities+transit';

    if (hasEnrichedAmenities) return 'amenities-only';

    if (hasTransitPayload) return 'transit-only';

    return 'empty-enrichment';

  }

}


