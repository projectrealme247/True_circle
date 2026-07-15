import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/neighborhood_amenity_tag.dart';
import 'package:true_circle/models/proximity_display_chip.dart';
import 'package:true_circle/services/overpass_amenities_service.dart';
import 'package:true_circle/utils/proximity_display_builder.dart';
import 'package:true_circle/utils/proximity_phase1_policy.dart';
import 'package:true_circle/utils/transit_ranking.dart';

const originLat = 53.42489;
const originLon = -6.37296;

void main() {
  test('Hollywoodrath 38-element payload trace', () {
    final raw = jsonDecode(
      File('tool/overpass_hollywoodrath_38.json').readAsStringSync(),
    ) as Map;
    final elements = raw['elements'] as List;

    expect(elements.length, 38);

    var busNamed = 0, busUnnamed = 0, grocery = 0;
    for (final el in elements) {
      final tags = (el as Map)['tags'] as Map? ?? {};
      if (tags['highway'] == 'bus_stop') {
        final name = _bestName(tags);
        final ref = tags['ref']?.toString().trim() ?? '';
        if (name.isNotEmpty || ref.isNotEmpty) {
          busNamed++;
        } else {
          busUnnamed++;
        }
      } else if (tags['shop'] == 'supermarket' || tags['shop'] == 'convenience') {
        grocery++;
      }
    }

    expect(busNamed, 35);
    expect(busUnnamed, 0);
    expect(grocery, 3);

    final parsed = _parseLikeWeb(elements, originLat, originLon);
    expect(parsed, isNotNull);
    expect(parsed!.isEmpty, isFalse);

    // Nearest Spar convenience ~430m from pin
    expect(parsed.supermarketName, 'Spar');
    expect(parsed.supermarketWalkMin, 6);
    expect(parsed.transitLine, isNotNull);
    expect(parsed.transitLine!, contains('Dublin Bus'));
    expect(parsed.transitWalkMin, lessThanOrEqualTo(20));
    expect(parsed.primarySchool, isNull);
    expect(parsed.primarySchoolWalkMin, isNull);
    expect(parsed.lifestyleTags, isEmpty);

    final phase1 = filterNearbyAmenitiesForPhase1(parsed);
    expect(phase1.transitLine, isNotNull);
    expect(phase1.supermarketName, 'Spar');

    final displayInput = ProximityDisplayInput(
      transportLine: parsed.transitLine!,
      transportWalkMin: parsed.transitWalkMin,
      groceryBrand: parsed.supermarketName!,
      groceryWalkMin: parsed.supermarketWalkMin,
      extraTransit: parsed.extraTransit,
      lifestyleTags: parsed.lifestyleTags,
    );
    final chips = ProximityDisplayBuilder.build(displayInput);
    expect(chips, isNotEmpty);
    expect(
      chips.any((c) => c.tier != ProximityDisplayTier.tier4),
      isTrue,
    );
  });
}

NearbyAmenities? _parseLikeWeb(List elements, double originLat, double originLon) {
  String? supermarketName;
  double supermarketDist = double.infinity;
  String? primarySchool;
  String? secondarySchool;
  String? transitLine;
  double transitDist = double.infinity;
  final extraTransit = <NearbyExtraTransit>[];
  String? bestBusLine;
  double bestBusDist = double.infinity;

  for (final el in elements) {
    if (el is! Map) continue;
    final tags = el['tags'];
    if (tags is! Map) continue;
    final elLat = (el['lat'] as num?)?.toDouble();
    final elLon = (el['lon'] as num?)?.toDouble();
    if (elLat == null || elLon == null) continue;

    final dist = _haversine(originLat, originLon, elLat, elLon);
    final name = _bestName(tags);
    final shop = tags['shop']?.toString() ?? '';
    final highway = tags['highway']?.toString() ?? '';

    if (shop == 'supermarket' || shop == 'convenience') {
      if (name.isEmpty) continue;
      if (dist < supermarketDist) {
        supermarketDist = dist;
        supermarketName = name;
      }
    } else {
      final transit = _transitCandidate(tags, highway: highway);
      if (transit != null) {
        if (dist < bestBusDist) {
          bestBusDist = dist;
          bestBusLine = transit;
        }
        final shouldReplace = TransitRanking.shouldPreferPrimary(
          candidateWalkMin: _walkMin(dist),
          candidateDistanceM: dist,
          candidateLine: transit,
          currentWalkMin: transitLine != null ? _walkMin(transitDist) : null,
          currentDistanceM: transitLine != null ? transitDist : null,
          currentLine: transitLine,
        );
        if (shouldReplace) {
          transitDist = dist;
          transitLine = transit;
        }
      }
    }
  }

  if (bestBusLine != null &&
      bestBusLine != transitLine &&
      !bestBusDist.isInfinite) {
    extraTransit.add(
      NearbyExtraTransit(line: bestBusLine!, walkMin: _walkMin(bestBusDist)),
    );
  }

  if (supermarketName == null &&
      primarySchool == null &&
      secondarySchool == null &&
      transitLine == null &&
      extraTransit.isEmpty) {
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
    extraTransit: extraTransit,
  );
}

String? _transitCandidate(Map tags, {required String highway}) {
  var name = _bestName(tags);
  if (name.isEmpty) {
    final ref = tags['ref']?.toString().trim() ?? '';
    if (ref.isNotEmpty) name = 'Stop $ref';
  }
  if (name.isEmpty) return null;
  if (highway == 'bus_stop') return 'Dublin Bus · $name';
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

int _walkMin(double meters) => (meters / 80).ceil().clamp(1, 30);

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
  final dP = (lat2 - lat1) * math.pi / 180, dL = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dP / 2) * math.sin(dP / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dL / 2) * math.sin(dL / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
