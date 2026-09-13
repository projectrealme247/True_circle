import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../models/neighborhood_amenity_tag.dart';
import '../utils/transit_ranking.dart';
import 'overpass_amenities_service.dart';
import 'overpass_config.dart';
import 'overpass_full_query.dart';

Future<NearbyAmenities?> fetchNearbyAmenities(double lat, double lon) async {
  const endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  final fullResults = await Future.wait([
    for (final endpoint in endpoints)
      _fetchFromEndpoint(endpoint, lat, lon, full: true),
  ]);

  NearbyAmenities? merged;
  for (final result in fullResults) {
    merged = NearbyAmenities.merge(merged, result);
  }
  // Thin full results (e.g. bus + grocery only) must not skip lifestyle fallback.
  if (merged != null && merged.hasEnrichmentCoverage) return merged;

  final essentialResults = await Future.wait([
    for (final endpoint in endpoints)
      _fetchFromEndpoint(endpoint, lat, lon, full: false),
  ]);
  for (final result in essentialResults) {
    merged = NearbyAmenities.merge(merged, result);
  }
  return merged;
}

Future<NearbyAmenities?> _fetchFromEndpoint(
  String endpoint,
  double lat,
  double lon, {
  required bool full,
}) async {
  final queryType =
      full ? OverpassQueryType.full : OverpassQueryType.essentials;
  final startedAt = DateTime.now();

  try {
    final latStr = lat.toStringAsFixed(6);
    final lonStr = lon.toStringAsFixed(6);
    final query = full
        ? buildFullOverpassQuery(latStr, lonStr)
        : buildEssentialsOverpassQuery(latStr, lonStr);
    final requestTimeout = OverpassConfig.requestTimeoutFor(queryType);

    final completer = Completer<_OverpassFetchResult>();
    final xhr = web.XMLHttpRequest();
    xhr.open('POST', endpoint);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr.onload = ((web.Event _) {
      try {
        if (xhr.status < 200 || xhr.status >= 300) {
          completer.complete(
            _OverpassFetchResult.failure(
              outcome: 'http_error',
              statusCode: xhr.status,
            ),
          );
          return;
        }
        final decoded = jsonDecode(xhr.responseText);
        if (decoded is! Map) {
          completer.complete(
            _OverpassFetchResult.failure(outcome: 'parse_error'),
          );
          return;
        }
        final elements = decoded['elements'];
        if (elements is! List) {
          completer.complete(
            _OverpassFetchResult.failure(outcome: 'parse_error'),
          );
          return;
        }
        completer.complete(
          _OverpassFetchResult.success(
            amenities: _parseElements(elements, lat, lon),
            elementCount: elements.length,
          ),
        );
      } catch (_) {
        completer.complete(
          _OverpassFetchResult.failure(outcome: 'parse_error'),
        );
      }
    }).toJS;
    xhr.onerror = ((web.Event _) {
      completer.complete(_OverpassFetchResult.failure(outcome: 'xhr_error'));
    }).toJS;
    xhr.send('data=${Uri.encodeComponent(query)}'.toJS);

    final result = await completer.future.timeout(
      requestTimeout,
      onTimeout: () => _OverpassFetchResult.failure(
        outcome: 'client_timeout',
        timedOut: true,
      ),
    );

    OverpassConfig.logFetch(
      queryType: queryType,
      endpoint: endpoint,
      duration: DateTime.now().difference(startedAt),
      elementCount: result.elementCount,
      outcome: result.outcome,
    );
    return result.amenities;
  } catch (_) {
    OverpassConfig.logFetch(
      queryType: queryType,
      endpoint: endpoint,
      duration: DateTime.now().difference(startedAt),
      outcome: 'unexpected_error',
    );
    return null;
  }
}

class _OverpassFetchResult {
  const _OverpassFetchResult({
    this.amenities,
    this.elementCount,
    required this.outcome,
  });

  final NearbyAmenities? amenities;
  final int? elementCount;
  final String outcome;

  factory _OverpassFetchResult.success({
    required NearbyAmenities? amenities,
    required int elementCount,
  }) {
    if (elementCount == 0) {
      return const _OverpassFetchResult(
        elementCount: 0,
        outcome: 'empty_elements',
      );
    }
    if (amenities == null || amenities.isEmpty) {
      return _OverpassFetchResult(
        elementCount: elementCount,
        outcome: 'no_usable_amenities',
      );
    }
    return _OverpassFetchResult(
      amenities: amenities,
      elementCount: elementCount,
      outcome: 'success',
    );
  }

  factory _OverpassFetchResult.failure({
    required String outcome,
    int? statusCode,
    bool timedOut = false,
  }) {
    if (statusCode != null) {
      return _OverpassFetchResult(outcome: '${outcome}_$statusCode');
    }
    if (timedOut) {
      return _OverpassFetchResult(outcome: outcome);
    }
    return _OverpassFetchResult(outcome: outcome);
  }
}

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

NearbyAmenities? _parseElements(List elements, double originLat, double originLon) {
  String? supermarketName;
  double supermarketDist = double.infinity;
  final groceryCandidates = <({String brand, double dist})>[];
  String? primarySchool;
  double primaryDist = double.infinity;
  String? secondarySchool;
  double secondaryDist = double.infinity;
  String? collegeSchool;
  double collegeDist = double.infinity;
  String? crecheName;
  double crecheDist = double.infinity;
  String? transitLine;
  double transitDist = double.infinity;
  final extraTransit = <NearbyExtraTransit>[];
  String? bestBusLine;
  double bestBusDist = double.infinity;
  String? bestDartLine;
  double bestDartDist = double.infinity;
  String? bestLuasLine;
  double bestLuasDist = double.infinity;
  String? nearestHospital;
  double hospitalDist = double.infinity;
  String? nearestGpClinic;
  double gpClinicDist = double.infinity;

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
      final brand = _normalisedGroceryBrand(name);
      groceryCandidates.add((brand: brand, dist: dist));
      if (dist < supermarketDist) {
        supermarketDist = dist;
        supermarketName = brand;
      }
    } else if (shop == 'asian' || shop == 'asian_supermarket' || shop == 'oriental') {
      if (name.isEmpty) continue;
      groceryCandidates.add((brand: name, dist: dist));
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
      if (_isCollegeSchool(name, tags)) {
        if (dist < collegeDist) {
          collegeDist = dist;
          collegeSchool = name;
        }
        continue;
      }
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
    } else if (amenity == 'hospital') {
      if (name.isEmpty) continue;
      if (dist < hospitalDist) {
        hospitalDist = dist;
        nearestHospital = name;
      }
    } else if (amenity == 'clinic' || amenity == 'doctors') {
      if (name.isEmpty) continue;
      final lower = name.toLowerCase();
      if (lower.contains('hospital')) {
        if (dist < hospitalDist) {
          hospitalDist = dist;
          nearestHospital = name;
        }
      } else if (dist < gpClinicDist) {
        gpClinicDist = dist;
        nearestGpClinic = name;
      }
    } else {
      final transit = _transitCandidate(tags, railway: railway, highway: highway);
      if (transit != null) {
        if (transit.line.startsWith('Dublin Bus')) {
          if (dist < bestBusDist) {
            bestBusDist = dist;
            bestBusLine = transit.line;
          }
        } else if (transit.line.startsWith('DART')) {
          if (dist < bestDartDist) {
            bestDartDist = dist;
            bestDartLine = transit.line;
          }
        } else if (transit.line.startsWith('Luas')) {
          if (dist < bestLuasDist) {
            bestLuasDist = dist;
            bestLuasLine = transit.line;
          }
        }
        final shouldReplace = TransitRanking.shouldPreferPrimary(
          candidateWalkMin: _walkMin(dist),
          candidateDistanceM: dist,
          candidateLine: transit.line,
          currentWalkMin:
              transitLine != null ? _walkMin(transitDist) : null,
          currentDistanceM: transitLine != null ? transitDist : null,
          currentLine: transitLine,
        );
        if (shouldReplace) {
          transitDist = dist;
          transitLine = transit.line;
        }
      }
    }
  }

  void addExtra(String? line, double dist) {
    if (line == null || line == transitLine || dist.isInfinite) return;
    final walk = _walkMin(dist);
    if (extraTransit.any((e) => e.line == line)) return;
    extraTransit.add(NearbyExtraTransit(line: line, walkMin: walk));
  }

  addExtra(bestBusLine, bestBusDist);
  addExtra(bestDartLine, bestDartDist);
  addExtra(bestLuasLine, bestLuasDist);
  if (nearestHospital != null) {
    extraTransit.add(
      NearbyExtraTransit(
        line: 'Hospital · $nearestHospital',
        walkMin: _walkMin(hospitalDist),
      ),
    );
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

  final groceries = _topGroceries(groceryCandidates);

  if (supermarketName == null &&
      primarySchool == null &&
      secondarySchool == null &&
      collegeSchool == null &&
      crecheName == null &&
      transitLine == null &&
      lifestyleTags.isEmpty &&
      extraTransit.isEmpty &&
      groceries.isEmpty &&
      nearestGpClinic == null) {
    return null;
  }

  return NearbyAmenities(
    transitLine: transitLine,
    transitWalkMin: transitLine != null ? _walkMin(transitDist) : null,
    supermarketName: supermarketName,
    supermarketWalkMin:
        supermarketName != null ? _walkMin(supermarketDist) : null,
    primarySchool: primarySchool,
    primarySchoolWalkMin:
        primarySchool != null ? _walkMin(primaryDist) : null,
    secondarySchool: secondarySchool,
    secondarySchoolWalkMin:
        secondarySchool != null ? _walkMin(secondaryDist) : null,
    crecheName: crecheName,
    crecheWalkMin: crecheName != null ? _walkMin(crecheDist) : null,
    lifestyleTags: lifestyleTags,
    extraTransit: extraTransit,
    groceries: groceries,
    collegeSchool: collegeSchool,
    collegeWalkMin: collegeSchool != null ? _walkMin(collegeDist) : null,
    gpClinic: nearestGpClinic,
    gpWalkMin: nearestGpClinic != null ? _walkMin(gpClinicDist) : null,
  );
}

List<NearbyGroceryOption> _topGroceries(
  List<({String brand, double dist})> candidates,
) {
  final byBrand = <String, ({String brand, double dist})>{};
  for (final item in candidates) {
    final key = item.brand.trim().toLowerCase();
    if (key.isEmpty) continue;
    final existing = byBrand[key];
    if (existing == null || item.dist < existing.dist) {
      byBrand[key] = item;
    }
  }
  final sorted = byBrand.values.toList()..sort((a, b) => a.dist.compareTo(b.dist));
  return sorted
      .take(3)
      .map(
        (item) => NearbyGroceryOption(
          brand: item.brand,
          walkMin: _walkMin(item.dist),
        ),
      )
      .toList();
}

bool _isCollegeSchool(String name, Map tags) {
  final lower = name.toLowerCase();
  final schoolType = tags['school:type']?.toString().toLowerCase() ?? '';
  return schoolType.contains('university') ||
      lower.contains('university') ||
      lower.contains('institute of technology') ||
      (lower.contains('college') && !lower.contains('community college')) ||
      lower.contains(' trinity') ||
      lower.contains(' ucd') ||
      lower.contains(' dcu');
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
