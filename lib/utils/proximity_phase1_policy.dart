import '../models/neighborhood_amenity_tag.dart';
import '../services/overpass_amenities_service.dart';

/// Max walking minutes shown in Phase 1 local fallback (~1.5 km).
const int phase1MaxConfidentWalkMin = 20;

/// Returns true when [walkMin] is a positive walk time within the Phase 1 envelope.
bool isConfidentWalkMinutes(int? walkMin) {
  if (walkMin == null || walkMin <= 0) return false;
  return walkMin <= phase1MaxConfidentWalkMin;
}

/// Returns true when transit payload walk minutes are within Phase 1 confidence.
bool isConfidentProximityPayload(Map<String, dynamic> extracted) {
  final walk = (extracted['walk_minutes'] as num?)?.toInt();
  return isConfidentWalkMinutes(walk);
}

String _normalizedAmenityName(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Merges catalog and structured lifestyle tags, deduping by category + name.
List<NeighborhoodAmenityTag> mergeAmenityTags(
  List<NeighborhoodAmenityTag> catalog,
  List<NeighborhoodAmenityTag> structured, [
  List<NeighborhoodAmenityTag> additional = const [],
]) {
  final seen = <String>{};
  final merged = <NeighborhoodAmenityTag>[];
  for (final tag in [...catalog, ...structured, ...additional]) {
    final key = '${tag.category.name}|${_normalizedAmenityName(tag.name)}';
    if (seen.add(key)) {
      merged.add(tag);
    }
  }
  return merged;
}

/// Strips low-confidence proximity fields for Phase 1 local rendering.
NearbyAmenities filterNearbyAmenitiesForPhase1(NearbyAmenities amenities) {
  return NearbyAmenities(
    eircode: amenities.eircode,
    transitLine: isConfidentWalkMinutes(amenities.transitWalkMin)
        ? amenities.transitLine
        : null,
    transitWalkMin: isConfidentWalkMinutes(amenities.transitWalkMin)
        ? amenities.transitWalkMin
        : null,
    supermarketName: isConfidentWalkMinutes(amenities.supermarketWalkMin)
        ? amenities.supermarketName
        : null,
    supermarketWalkMin: isConfidentWalkMinutes(amenities.supermarketWalkMin)
        ? amenities.supermarketWalkMin
        : null,
    primarySchool: isConfidentWalkMinutes(amenities.primarySchoolWalkMin)
        ? amenities.primarySchool
        : null,
    primarySchoolWalkMin: isConfidentWalkMinutes(amenities.primarySchoolWalkMin)
        ? amenities.primarySchoolWalkMin
        : null,
    secondarySchool: isConfidentWalkMinutes(amenities.secondarySchoolWalkMin)
        ? amenities.secondarySchool
        : null,
    secondarySchoolWalkMin:
        isConfidentWalkMinutes(amenities.secondarySchoolWalkMin)
            ? amenities.secondarySchoolWalkMin
            : null,
    crecheName: isConfidentWalkMinutes(amenities.crecheWalkMin)
        ? amenities.crecheName
        : null,
    crecheWalkMin: isConfidentWalkMinutes(amenities.crecheWalkMin)
        ? amenities.crecheWalkMin
        : null,
    lifestyleTags: amenities.lifestyleTags,
    extraTransit: amenities.extraTransit
        .where((e) => isConfidentWalkMinutes(e.walkMin))
        .toList(),
    groceries: amenities.groceries
        .where((g) => isConfidentWalkMinutes(g.walkMin))
        .toList(),
    collegeSchool: isConfidentWalkMinutes(amenities.collegeWalkMin)
        ? amenities.collegeSchool
        : null,
    collegeWalkMin: isConfidentWalkMinutes(amenities.collegeWalkMin)
        ? amenities.collegeWalkMin
        : null,
    gpClinic: isConfidentWalkMinutes(amenities.gpWalkMin)
        ? amenities.gpClinic
        : null,
    gpWalkMin: isConfidentWalkMinutes(amenities.gpWalkMin)
        ? amenities.gpWalkMin
        : null,
  );
}
