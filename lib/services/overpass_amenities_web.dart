import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../models/neighborhood_amenity_tag.dart';
import 'overpass_amenities_service.dart';

Future<NearbyAmenities?> fetchNearbyAmenities(double lat, double lon) async {
  try {
    final latStr = lat.toStringAsFixed(6);
    final lonStr = lon.toStringAsFixed(6);
    final query = '''
[out:json][timeout:14];
(
  node["shop"~"supermarket|convenience"](around:900,$latStr,$lonStr);
  way["shop"~"supermarket|convenience"](around:900,$latStr,$lonStr);
  node["amenity"="school"](around:1400,$latStr,$lonStr);
  way["amenity"="school"](around:1400,$latStr,$lonStr);
  node["amenity"~"childcare|kindergarten"](around:1400,$latStr,$lonStr);
  way["amenity"~"childcare|kindergarten"](around:1400,$latStr,$lonStr);
  node["railway"~"tram_stop|station|halt"](around:2500,$latStr,$lonStr);
  node["highway"="bus_stop"](around:1200,$latStr,$lonStr);
  node["addr:postcode"](around:350,$latStr,$lonStr);
  way["addr:postcode"](around:350,$latStr,$lonStr);
  node["amenity"~"pub|bar|biergarten"](around:1200,$latStr,$lonStr);
  node["amenity"="atm"](around:1000,$latStr,$lonStr);
  node["amenity"="bank"](around:1000,$latStr,$lonStr);
  node["shop"~"pizza"](around:1500,$latStr,$lonStr);
  node["amenity"~"fast_food"](around:1500,$latStr,$lonStr);
  node["shop"~"supermarket"](around:1500,$latStr,$lonStr);
  node["shop"~"asian|asian_supermarket|oriental"](around:2000,$latStr,$lonStr);
  node["leisure"~"fitness_centre|sports_centre"](around:1500,$latStr,$lonStr);
  way["leisure"~"fitness_centre|sports_centre"](around:1500,$latStr,$lonStr);
  node["leisure"="park"](around:1200,$latStr,$lonStr);
  way["leisure"="park"](around:1200,$latStr,$lonStr);
  node["amenity"="pharmacy"](around:1000,$latStr,$lonStr);
  node["amenity"="cafe"](around:800,$latStr,$lonStr);
  node["amenity"~"restaurant"](around:1000,$latStr,$lonStr);
  node["landuse"~"commercial|industrial"](around:2000,$latStr,$lonStr);
  way["landuse"~"commercial|industrial"](around:2000,$latStr,$lonStr);
  node["office"](around:1500,$latStr,$lonStr);
  way["office"](around:1500,$latStr,$lonStr);
  node["tourism"~"attraction|museum|gallery"](around:2000,$latStr,$lonStr);
  way["tourism"~"attraction|museum|gallery"](around:2000,$latStr,$lonStr);
);
out center;
''';

    final completer = Completer<NearbyAmenities?>();
    final xhr = web.XMLHttpRequest();
    xhr.open('POST', 'https://overpass-api.de/api/interpreter');
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr.onload = ((web.Event _) {
      try {
        if (xhr.status < 200 || xhr.status >= 300) {
          completer.complete(null);
          return;
        }
        final decoded = jsonDecode(xhr.responseText);
        if (decoded is! Map) {
          completer.complete(null);
          return;
        }
        final elements = decoded['elements'];
        if (elements is! List) {
          completer.complete(null);
          return;
        }
        completer.complete(_parseElements(elements, lat, lon));
      } catch (_) {
        completer.complete(null);
      }
    }).toJS;
    xhr.onerror = ((web.Event _) => completer.complete(null)).toJS;
    xhr.send('data=${Uri.encodeComponent(query)}'.toJS);
    return completer.future.timeout(
      const Duration(seconds: 14),
      onTimeout: () => null,
    );
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

NearbyAmenities? _parseElements(List elements, double originLat, double originLon) {
  String? supermarketName;
  double supermarketDist = double.infinity;
  String? primarySchool;
  double primaryDist = double.infinity;
  String? secondarySchool;
  double secondaryDist = double.infinity;
  String? crecheName;
  double crecheDist = double.infinity;
  String? transitLine;
  double transitDist = double.infinity;
  int transitPriority = -1;

  // Lifestyle POI tracking.
  String? nearestPub;
  double pubDist = double.infinity;
  String? nearestPizza;
  double pizzaDist = double.infinity;
  String? nearestAtm;
  double atmDist = double.infinity;
  String? nearestAsian;
  double asianDist = double.infinity;
  String? nearestGym;
  double gymDist = double.infinity;
  String? nearestPark;
  double parkDist = double.infinity;
  String? nearestPharmacy;
  double pharmacyDist = double.infinity;
  String? nearestCafe;
  double cafeDist = double.infinity;
  String? nearestRestaurant;
  double restaurantDist = double.infinity;
  String? nearestBusinessPark;
  double businessParkDist = double.infinity;
  String? nearestAttraction;
  double attractionDist = double.infinity;

  for (final el in elements) {
    if (el is! Map) continue;
    final tags = el['tags'];
    if (tags is! Map) continue;

    final double? elLat = _elLat(el);
    final double? elLon = _elLon(el);
    if (elLat == null || elLon == null) continue;

    final dist = _haversineMeters(originLat, originLon, elLat, elLon);
    final name = _bestName(tags);

    final shop = tags['shop']?.toString() ?? '';
    final amenity = tags['amenity']?.toString() ?? '';
    final railway = tags['railway']?.toString() ?? '';
    final highway = tags['highway']?.toString() ?? '';
    final cuisine = tags['cuisine']?.toString().toLowerCase() ?? '';
    final leisure = tags['leisure']?.toString() ?? '';
    final tourism = tags['tourism']?.toString() ?? '';
    final landuse = tags['landuse']?.toString() ?? '';
    final office = tags['office']?.toString() ?? '';

    if (shop == 'supermarket' || shop == 'convenience') {
      if (name.isEmpty) continue;
      if (dist < supermarketDist) {
        supermarketDist = dist;
        supermarketName = _normalisedGroceryBrand(name);
      }
    } else if (shop == 'asian' || shop == 'asian_supermarket' || shop == 'oriental') {
      if (name.isEmpty) continue;
      if (dist < asianDist) {
        asianDist = dist;
        nearestAsian = name;
      }
    } else if (shop == 'pizza' ||
        (amenity == 'fast_food' && cuisine.contains('pizza'))) {
      if (name.isEmpty) continue;
      if (dist < pizzaDist) {
        pizzaDist = dist;
        nearestPizza = name;
      }
    } else if (amenity == 'pub' || amenity == 'bar' || amenity == 'biergarten') {
      if (name.isEmpty) continue;
      if (dist < pubDist) {
        pubDist = dist;
        nearestPub = name;
      }
    } else if (amenity == 'cafe') {
      if (name.isEmpty) continue;
      if (dist < cafeDist) {
        cafeDist = dist;
        nearestCafe = name;
      }
    } else if (amenity == 'restaurant') {
      if (name.isEmpty) continue;
      if (dist < restaurantDist) {
        restaurantDist = dist;
        nearestRestaurant = name;
      }
    } else if (amenity == 'pharmacy') {
      if (name.isEmpty) continue;
      if (dist < pharmacyDist) {
        pharmacyDist = dist;
        nearestPharmacy = name;
      }
    } else if (amenity == 'atm') {
      final atm = name.isNotEmpty ? name : 'ATM';
      if (dist < atmDist) {
        atmDist = dist;
        nearestAtm = atm;
      }
    } else if (amenity == 'bank') {
      if (name.isEmpty) continue;
      final label = '$name ATM';
      if (dist < atmDist) {
        atmDist = dist;
        nearestAtm = label;
      }
    } else if (leisure == 'fitness_centre' || leisure == 'sports_centre') {
      if (name.isEmpty) continue;
      if (dist < gymDist) {
        gymDist = dist;
        nearestGym = name;
      }
    } else if (leisure == 'park') {
      if (name.isEmpty) continue;
      if (dist < parkDist) {
        parkDist = dist;
        nearestPark = name;
      }
    } else if (tourism == 'attraction' || tourism == 'museum' || tourism == 'gallery') {
      if (name.isEmpty) continue;
      if (dist < attractionDist) {
        attractionDist = dist;
        nearestAttraction = name;
      }
    } else if (landuse == 'commercial' || landuse == 'industrial' || office.isNotEmpty) {
      if (name.isEmpty) continue;
      if (dist < businessParkDist) {
        businessParkDist = dist;
        nearestBusinessPark = name;
      }
    } else if (amenity == 'school') {
      if (name.isEmpty) continue;
      final isPrimary = _isPrimarySchool(name, tags);
      final isSecondary = _isSecondarySchool(name, tags);

      if (isPrimary && dist < primaryDist) {
        primaryDist = dist;
        primarySchool = name;
      } else if (isSecondary && dist < secondaryDist) {
        secondaryDist = dist;
        secondarySchool = name;
      } else if (!isPrimary && !isSecondary) {
        if (primarySchool == null && dist < primaryDist) {
          primaryDist = dist;
          primarySchool = name;
        } else if (secondarySchool == null && dist < secondaryDist) {
          secondaryDist = dist;
          secondarySchool = name;
        }
      }
    } else if (amenity == 'childcare' || amenity == 'kindergarten') {
      if (name.isEmpty) continue;
      if (dist < crecheDist) {
        crecheDist = dist;
        crecheName = name;
      }
    } else {
      final transit = _transitCandidate(tags, railway: railway, highway: highway);
      if (transit != null) {
        final shouldReplace = transit.priority > transitPriority ||
            (transit.priority == transitPriority && dist < transitDist);
        if (shouldReplace) {
          transitPriority = transit.priority;
          transitDist = dist;
          transitLine = transit.line;
        }
      }
    }
  }

  final lifestyleTags = <NeighborhoodAmenityTag>[
    if (nearestPub != null)
      NeighborhoodAmenityTag(
        category: NeighborhoodAmenityCategory.pubs,
        name: nearestPub,
        distanceKm: pubDist / 1000,
        emoji: '🍺',
      ),
    if (nearestCafe != null)
      NeighborhoodAmenityTag(
        category: NeighborhoodAmenityCategory.cafe,
        name: nearestCafe,
        distanceKm: cafeDist / 1000,
        emoji: '☕',
      ),
    if (nearestRestaurant != null)
      NeighborhoodAmenityTag(
        category: NeighborhoodAmenityCategory.restaurant,
        name: nearestRestaurant,
        distanceKm: restaurantDist / 1000,
        emoji: '🍽️',
      ),
    if (nearestPizza != null)
      NeighborhoodAmenityTag(
        category: NeighborhoodAmenityCategory.pizzaShops,
        name: nearestPizza,
        distanceKm: pizzaDist / 1000,
        emoji: '🍕',
      ),
    if (nearestGym != null)
      NeighborhoodAmenityTag(
        category: NeighborhoodAmenityCategory.gym,
        name: nearestGym,
        distanceKm: gymDist / 1000,
        emoji: '🏋️',
      ),
    if (nearestPark != null)
      NeighborhoodAmenityTag(
        category: NeighborhoodAmenityCategory.park,
        name: nearestPark,
        distanceKm: parkDist / 1000,
        emoji: '🌳',
      ),
    if (nearestPharmacy != null)
      NeighborhoodAmenityTag(
        category: NeighborhoodAmenityCategory.pharmacy,
        name: nearestPharmacy,
        distanceKm: pharmacyDist / 1000,
        emoji: '💊',
      ),
    if (nearestAtm != null)
      NeighborhoodAmenityTag(
        category: NeighborhoodAmenityCategory.atms,
        name: nearestAtm,
        distanceKm: atmDist / 1000,
        emoji: '🏧',
      ),
    if (nearestAsian != null)
      NeighborhoodAmenityTag(
        category: NeighborhoodAmenityCategory.asianStores,
        name: nearestAsian,
        distanceKm: asianDist / 1000,
        emoji: '🛍️',
      ),
    if (nearestBusinessPark != null)
      NeighborhoodAmenityTag(
        category: NeighborhoodAmenityCategory.businessPark,
        name: nearestBusinessPark,
        distanceKm: businessParkDist / 1000,
        emoji: '🏢',
      ),
    if (nearestAttraction != null)
      NeighborhoodAmenityTag(
        category: NeighborhoodAmenityCategory.attraction,
        name: nearestAttraction,
        distanceKm: attractionDist / 1000,
        emoji: '🎭',
      ),
  ];

  if (supermarketName == null &&
      primarySchool == null &&
      secondarySchool == null &&
      crecheName == null &&
      transitLine == null &&
      lifestyleTags.isEmpty) {
    return null;
  }

  return NearbyAmenities(
    transitLine: transitLine,
    transitWalkMin: transitLine != null ? _walkMin(transitDist) : null,
    supermarketName: supermarketName,
    supermarketWalkMin:
        supermarketName != null ? _walkMin(supermarketDist) : null,
    primarySchool: primarySchool,
    secondarySchool: secondarySchool,
    crecheName: crecheName,
    crecheWalkMin: crecheName != null ? _walkMin(crecheDist) : null,
    lifestyleTags: lifestyleTags,
  );
}

class _TransitCandidate {
  const _TransitCandidate({required this.line, required this.priority});
  final String line;
  final int priority;
}

_TransitCandidate? _transitCandidate(
  Map tags, {
  required String railway,
  required String highway,
}) {
  var name = _bestName(tags);
  if (name.isEmpty) {
    final ref = tags['ref']?.toString().trim() ?? '';
    if (ref.isNotEmpty) name = 'Stop $ref';
  }
  if (name.isEmpty) return null;

  if (railway == 'tram_stop') {
    return _TransitCandidate(line: 'Luas · $name', priority: 3);
  }
  if (railway == 'station' || railway == 'halt') {
    final train = tags['train']?.toString() ?? '';
    if (train == 'yes' || name.toLowerCase().contains('dart')) {
      return _TransitCandidate(line: 'DART · $name', priority: 2);
    }
    return _TransitCandidate(line: 'Rail · $name', priority: 1);
  }
  if (highway == 'bus_stop') {
    return _TransitCandidate(line: 'Dublin Bus · $name', priority: 0);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

double? _elLat(Map el) {
  final center = el['center'];
  if (center is Map && center['lat'] is num) {
    return (center['lat'] as num).toDouble();
  }
  if (el['lat'] is num) return (el['lat'] as num).toDouble();
  return null;
}

double? _elLon(Map el) {
  final center = el['center'];
  if (center is Map && center['lon'] is num) {
    return (center['lon'] as num).toDouble();
  }
  if (el['lon'] is num) return (el['lon'] as num).toDouble();
  return null;
}

String _bestName(Map tags) {
  final brand = tags['brand']?.toString().trim() ?? '';
  final operator = tags['operator']?.toString().trim() ?? '';
  final name = tags['name']?.toString().trim() ?? '';
  if (brand.isNotEmpty) return brand;
  if (name.isNotEmpty) return name;
  return operator;
}

/// Maps raw OSM name/brand to a canonical Irish grocery brand.
String _normalisedGroceryBrand(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('tesco')) return 'Tesco';
  if (lower.contains('dunnes')) return 'Dunnes';
  if (lower.contains('supervalu') || lower.contains('super valu')) {
    return 'SuperValu';
  }
  if (lower.contains('lidl')) return 'Lidl';
  if (lower.contains('aldi')) return 'Aldi';
  if (lower.contains('spar')) return 'Spar';
  if (lower.contains('centra')) return 'Centra';
  // Return the raw name (may not be in the dropdown list, but better than nothing).
  return raw;
}

bool _isPrimarySchool(String name, Map tags) {
  final iscedLevel = tags['isced:level']?.toString() ?? '';
  final schoolType = tags['school:type']?.toString().toLowerCase() ?? '';
  final lower = name.toLowerCase();
  if (iscedLevel.contains('1')) return true;
  if (schoolType.contains('primary')) return true;
  if (lower.contains('national school') ||
      lower.contains(' n.s.') ||
      lower.contains(' ns ') ||
      lower.contains('primary')) {
    return true;
  }
  return false;
}

bool _isSecondarySchool(String name, Map tags) {
  final iscedLevel = tags['isced:level']?.toString() ?? '';
  final schoolType = tags['school:type']?.toString().toLowerCase() ?? '';
  final lower = name.toLowerCase();
  if (iscedLevel.contains('2') || iscedLevel.contains('3')) return true;
  if (schoolType.contains('secondary')) return true;
  if (lower.contains('secondary') ||
      lower.contains('community school') ||
      lower.contains('community college') ||
      lower.contains('vocational') ||
      lower.contains(' etss') ||
      lower.contains(' cbs ') ||
      lower.contains(' css ') ||
      lower.contains('college') && !lower.contains('national school')) {
    return true;
  }
  return false;
}

int _walkMin(double meters) =>
    (meters / 80).ceil().clamp(1, 30);

double _haversineMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const r = 6371000.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dPhi = (lat2 - lat1) * math.pi / 180;
  final dLambda = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) *
          math.cos(phi2) *
          math.sin(dLambda / 2) *
          math.sin(dLambda / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
