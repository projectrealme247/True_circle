import '../models/neighborhood_amenity_tag.dart';
import 'overpass_amenities_stub.dart'
    if (dart.library.js_interop) 'overpass_amenities_web.dart' as impl;

/// Snapshot of nearby amenities resolved from OpenStreetMap Overpass API.
class NearbyAmenities {
  const NearbyAmenities({
    this.eircode,
    this.transitLine,
    this.transitWalkMin,
    this.supermarketName,
    this.supermarketWalkMin,
    this.primarySchool,
    this.secondarySchool,
    this.crecheName,
    this.crecheWalkMin,
    this.lifestyleTags = const [],
  });

  final String? eircode;
  final String? transitLine;
  final int? transitWalkMin;
  final String? supermarketName;
  final int? supermarketWalkMin;
  final String? primarySchool;
  final String? secondarySchool;
  final String? crecheName;
  final int? crecheWalkMin;

  /// Lifestyle POI tags resolved from Overpass (pubs, ATMs, pizza, etc.).
  final List<NeighborhoodAmenityTag> lifestyleTags;

  bool get isEmpty =>
      eircode == null &&
      transitLine == null &&
      supermarketName == null &&
      primarySchool == null &&
      secondarySchool == null &&
      crecheName == null &&
      lifestyleTags.isEmpty;
}

/// Queries OpenStreetMap Overpass API for amenities within walking distance.
/// Includes a single retry with 1-second delay on failure.
abstract final class OverpassAmenitiesService {
  static Future<NearbyAmenities?> fetchNearby({
    required double latitude,
    required double longitude,
  }) async {
    final result = await impl.fetchNearbyAmenities(latitude, longitude);
    if (result != null) return result;
    await Future<void>.delayed(const Duration(seconds: 1));
    return impl.fetchNearbyAmenities(latitude, longitude);
  }
}
