import '../../utils/geo_math.dart';

enum DublinTransitMode { luasGreen, luasRed, dart, busHighFrequency }

/// A Luas platform or high-frequency bus corridor stop used for walk + line math.
class DublinTransitNode {
  const DublinTransitNode({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.mode,
    this.greenLineIndex,
    this.redLineIndex,
    this.dartLineIndex,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final DublinTransitMode mode;
  final int? greenLineIndex;
  final int? redLineIndex;
  final int? dartLineIndex;

  LatLng get position => LatLng(latitude, longitude);
}

/// Nearest rapid-transit stop within the strict walking envelope.
class TransitProximityMatch {
  const TransitProximityMatch({
    required this.node,
    required this.walkMinutes,
    required this.distanceKm,
  });

  final DublinTransitNode node;
  final int walkMinutes;
  final double distanceKm;
}

/// Simplified Dublin transit graph for door-to-door minute estimates.
abstract final class DublinTransitNetwork {
  /// Strict Path B macro-tagging envelope (~12 min at 5 km/h).
  static const strictWalkingThresholdKm = 1.0;

  static const _boardingMinutes = 3;
  static const _busWaitMinutes = 5;
  static const _transferPenaltyMinutes = 8;
  static const _greenSegmentMinutes = 2;
  static const _redSegmentMinutes = 2;
  static const _dartSegmentMinutes = 3;

  static const nodes = <DublinTransitNode>[
    DublinTransitNode(
      id: 'luas_green_cherrywood',
      name: 'Cherrywood',
      latitude: 53.2445,
      longitude: -6.1458,
      mode: DublinTransitMode.luasGreen,
      greenLineIndex: 0,
    ),
    DublinTransitNode(
      id: 'luas_green_carrickmines',
      name: 'Carrickmines',
      latitude: 53.2660,
      longitude: -6.1680,
      mode: DublinTransitMode.luasGreen,
      greenLineIndex: 3,
    ),
    DublinTransitNode(
      id: 'luas_green_sandyford',
      name: 'Sandyford',
      latitude: 53.2775,
      longitude: -6.2040,
      mode: DublinTransitMode.luasGreen,
      greenLineIndex: 7,
    ),
    DublinTransitNode(
      id: 'luas_green_dundrum',
      name: 'Dundrum',
      latitude: 53.2890,
      longitude: -6.2430,
      mode: DublinTransitMode.luasGreen,
      greenLineIndex: 11,
    ),
    DublinTransitNode(
      id: 'luas_green_beechwood',
      name: 'Beechwood',
      latitude: 53.3015,
      longitude: -6.2520,
      mode: DublinTransitMode.luasGreen,
      greenLineIndex: 15,
    ),
    DublinTransitNode(
      id: 'luas_green_ranelagh',
      name: 'Ranelagh',
      latitude: 53.3260,
      longitude: -6.2550,
      mode: DublinTransitMode.luasGreen,
      greenLineIndex: 17,
    ),
    DublinTransitNode(
      id: 'luas_green_charlemont',
      name: 'Charlemont',
      latitude: 53.3305,
      longitude: -6.2585,
      mode: DublinTransitMode.luasGreen,
      greenLineIndex: 18,
    ),
    DublinTransitNode(
      id: 'luas_green_st_stephens_green',
      name: "St. Stephen's Green",
      latitude: 53.3382,
      longitude: -6.2591,
      mode: DublinTransitMode.luasGreen,
      greenLineIndex: 19,
    ),
    DublinTransitNode(
      id: 'luas_green_westmoreland',
      name: 'Westmoreland',
      latitude: 53.3425,
      longitude: -6.2575,
      mode: DublinTransitMode.luasGreen,
      greenLineIndex: 21,
    ),
    DublinTransitNode(
      id: 'luas_green_grand_canal_dock',
      name: 'Grand Canal Dock',
      latitude: 53.3419,
      longitude: -6.2373,
      mode: DublinTransitMode.luasGreen,
      greenLineIndex: 24,
    ),
    DublinTransitNode(
      id: 'luas_green_mayor_square',
      name: 'Mayor Square — NCI',
      latitude: 53.3480,
      longitude: -6.2395,
      mode: DublinTransitMode.luasGreen,
      greenLineIndex: 25,
    ),
    DublinTransitNode(
      id: 'luas_red_heuston',
      name: 'Heuston',
      latitude: 53.3465,
      longitude: -6.2925,
      mode: DublinTransitMode.luasRed,
      redLineIndex: 8,
    ),
    DublinTransitNode(
      id: 'luas_red_red_cow',
      name: 'Red Cow',
      latitude: 53.2960,
      longitude: -6.3705,
      mode: DublinTransitMode.luasRed,
      redLineIndex: 7,
    ),
    DublinTransitNode(
      id: 'luas_red_belgard',
      name: 'Belgard',
      latitude: 53.2985,
      longitude: -6.3885,
      mode: DublinTransitMode.luasRed,
      redLineIndex: 6,
    ),
    DublinTransitNode(
      id: 'luas_red_cookstown',
      name: 'Cookstown',
      latitude: 53.2910,
      longitude: -6.3830,
      mode: DublinTransitMode.luasRed,
      redLineIndex: 5,
    ),
    DublinTransitNode(
      id: 'luas_red_the_square',
      name: 'The Square',
      latitude: 53.2857,
      longitude: -6.3732,
      mode: DublinTransitMode.luasRed,
      redLineIndex: 4,
    ),
    DublinTransitNode(
      id: 'luas_red_tallaght_hospital',
      name: 'Tallaght Hospital',
      latitude: 53.2895,
      longitude: -6.3745,
      mode: DublinTransitMode.luasRed,
      redLineIndex: 3,
    ),
    DublinTransitNode(
      id: 'luas_red_fettercairn',
      name: 'Fettercairn',
      latitude: 53.2870,
      longitude: -6.3930,
      mode: DublinTransitMode.luasRed,
      redLineIndex: 2,
    ),
    DublinTransitNode(
      id: 'luas_red_cheeverstown',
      name: 'Cheeverstown',
      latitude: 53.2875,
      longitude: -6.4080,
      mode: DublinTransitMode.luasRed,
      redLineIndex: 1,
    ),
    DublinTransitNode(
      id: 'luas_red_saggart',
      name: 'Saggart',
      latitude: 53.2850,
      longitude: -6.4560,
      mode: DublinTransitMode.luasRed,
      redLineIndex: 0,
    ),
    DublinTransitNode(
      id: 'luas_red_abbey_street',
      name: 'Abbey Street',
      latitude: 53.3485,
      longitude: -6.2580,
      mode: DublinTransitMode.luasRed,
      redLineIndex: 13,
    ),
    DublinTransitNode(
      id: 'luas_red_connolly',
      name: 'Connolly',
      latitude: 53.3510,
      longitude: -6.2495,
      mode: DublinTransitMode.luasRed,
      redLineIndex: 15,
    ),
    DublinTransitNode(
      id: 'dart_dun_laoghaire',
      name: 'Dun Laoghaire',
      latitude: 53.2944,
      longitude: -6.1330,
      mode: DublinTransitMode.dart,
      dartLineIndex: 0,
    ),
    DublinTransitNode(
      id: 'dart_blackrock',
      name: 'Blackrock',
      latitude: 53.3015,
      longitude: -6.1785,
      mode: DublinTransitMode.dart,
      dartLineIndex: 3,
    ),
    DublinTransitNode(
      id: 'dart_grand_canal_dock',
      name: 'Grand Canal Dock (DART)',
      latitude: 53.3386,
      longitude: -6.2386,
      mode: DublinTransitMode.dart,
      dartLineIndex: 9,
    ),
    DublinTransitNode(
      id: 'dart_pearse',
      name: 'Pearse',
      latitude: 53.3433,
      longitude: -6.2483,
      mode: DublinTransitMode.dart,
      dartLineIndex: 10,
    ),
    DublinTransitNode(
      id: 'dart_tara_street',
      name: 'Tara Street',
      latitude: 53.3471,
      longitude: -6.2561,
      mode: DublinTransitMode.dart,
      dartLineIndex: 11,
    ),
    DublinTransitNode(
      id: 'dart_connolly',
      name: 'Connolly (DART)',
      latitude: 53.3510,
      longitude: -6.2495,
      mode: DublinTransitMode.dart,
      dartLineIndex: 12,
    ),
    DublinTransitNode(
      id: 'bus_hf_rathmines',
      name: 'Rathmines (46A corridor)',
      latitude: 53.3205,
      longitude: -6.2660,
      mode: DublinTransitMode.busHighFrequency,
    ),
    DublinTransitNode(
      id: 'bus_hf_drumcondra',
      name: 'Drumcondra (H3 corridor)',
      latitude: 53.3630,
      longitude: -6.2580,
      mode: DublinTransitMode.busHighFrequency,
    ),
    DublinTransitNode(
      id: 'bus_hf_blanchardstown',
      name: 'Blanchardstown Centre',
      latitude: 53.3935,
      longitude: -6.3765,
      mode: DublinTransitMode.busHighFrequency,
    ),
    DublinTransitNode(
      id: 'bus_hf_clondalkin',
      name: 'Clondalkin Village',
      latitude: 53.3215,
      longitude: -6.3965,
      mode: DublinTransitMode.busHighFrequency,
    ),
    DublinTransitNode(
      id: 'bus_hf_newcastle',
      name: 'Newcastle (Dublin Bus)',
      latitude: 53.3010,
      longitude: -6.5120,
      mode: DublinTransitMode.busHighFrequency,
    ),
    DublinTransitNode(
      id: 'bus_hf_lucan',
      name: 'Lucan Village',
      latitude: 53.3575,
      longitude: -6.4485,
      mode: DublinTransitMode.busHighFrequency,
    ),
  ];

  static DublinTransitNode? byId(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  static String transitTypeLabel(DublinTransitMode mode) => switch (mode) {
        DublinTransitMode.luasGreen => 'Luas Green Line',
        DublinTransitMode.luasRed => 'Luas Red Line',
        DublinTransitMode.dart => 'DART',
        DublinTransitMode.busHighFrequency => 'Dublin Bus High-Frequency',
      };

  static DublinTransitNode nearestTo(LatLng location) {
    var best = nodes.first;
    var bestKm = double.infinity;
    for (final node in nodes) {
      final km = GeoMath.haversineKm(location, node.position);
      if (km < bestKm) {
        bestKm = km;
        best = node;
      }
    }
    return best;
  }

  /// Returns a match only when [location] is within [strictWalkingThresholdKm].
  static TransitProximityMatch? matchWithinWalkingThreshold(LatLng location) {
    final nearest = nearestTo(location);
    final km = GeoMath.haversineKm(location, nearest.position);
    if (km > strictWalkingThresholdKm) return null;
    return TransitProximityMatch(
      node: nearest,
      walkMinutes: GeoMath.walkingMinutes(km),
      distanceKm: km,
    );
  }

  static int walkMinutesFromProperty(LatLng property, DublinTransitNode node) {
    final km = GeoMath.haversineKm(property, node.position);
    return GeoMath.walkingMinutes(km);
  }

  static int lineTravelMinutes(
    DublinTransitNode origin,
    DublinTransitNode destination,
  ) {
    if (origin.mode == DublinTransitMode.luasGreen &&
        destination.mode == DublinTransitMode.luasGreen &&
        origin.greenLineIndex != null &&
        destination.greenLineIndex != null) {
      final segments =
          (origin.greenLineIndex! - destination.greenLineIndex!).abs();
      return _boardingMinutes + segments * _greenSegmentMinutes;
    }

    if (origin.mode == DublinTransitMode.luasRed &&
        destination.mode == DublinTransitMode.luasRed &&
        origin.redLineIndex != null &&
        destination.redLineIndex != null) {
      final segments = (origin.redLineIndex! - destination.redLineIndex!).abs();
      return _boardingMinutes + segments * _redSegmentMinutes;
    }

    if (origin.mode == DublinTransitMode.dart &&
        destination.mode == DublinTransitMode.dart &&
        origin.dartLineIndex != null &&
        destination.dartLineIndex != null) {
      final segments =
          (origin.dartLineIndex! - destination.dartLineIndex!).abs();
      return _boardingMinutes + segments * _dartSegmentMinutes;
    }

    if (origin.mode == DublinTransitMode.busHighFrequency) {
      final busKm = GeoMath.haversineKm(origin.position, destination.position);
      final busLeg = GeoMath.busMinutes(busKm) + _busWaitMinutes;
      if (destination.mode == DublinTransitMode.luasGreen ||
          destination.mode == DublinTransitMode.luasRed) {
        return busLeg + _transferPenaltyMinutes;
      }
      return busLeg;
    }

    final km = GeoMath.haversineKm(origin.position, destination.position);
    return _boardingMinutes + GeoMath.luasMinutes(km) + _transferPenaltyMinutes;
  }
}
