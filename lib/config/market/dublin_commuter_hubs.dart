import '../../utils/geo_math.dart';

/// Canonical Dublin commuter anchoring hubs for Path B seeker profiles.
class DublinCommuterHub {
  const DublinCommuterHub({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.anchorStationId,
  });

  final String id;
  final String label;
  final double latitude;
  final double longitude;

  /// Nearest Luas / high-frequency bus node used for line-travel estimates.
  final String anchorStationId;

  LatLng get location => LatLng(latitude, longitude);
}

/// Fixed hub registry — no free-text geocoding for commute destinations.
abstract final class DublinCommuterHubs {
  static const stStephensGreen = DublinCommuterHub(
    id: 'st_stephens_green',
    label: "St. Stephen's Green",
    latitude: 53.3382,
    longitude: -6.2591,
    anchorStationId: 'luas_green_st_stephens_green',
  );

  static const grandCanalDock = DublinCommuterHub(
    id: 'grand_canal_dock',
    label: 'Grand Canal Dock',
    latitude: 53.3419,
    longitude: -6.2373,
    anchorStationId: 'luas_green_grand_canal_dock',
  );

  static const tcd = DublinCommuterHub(
    id: 'tcd',
    label: 'Trinity College Dublin (TCD)',
    latitude: 53.3438,
    longitude: -6.2546,
    anchorStationId: 'luas_green_westmoreland',
  );

  static const ucd = DublinCommuterHub(
    id: 'ucd',
    label: 'University College Dublin (UCD)',
    latitude: 53.3080,
    longitude: -6.2267,
    anchorStationId: 'luas_green_beechwood',
  );

  static const siliconDocks = DublinCommuterHub(
    id: 'silicon_docks',
    label: 'Silicon Docks',
    latitude: 53.3402,
    longitude: -6.2315,
    anchorStationId: 'luas_green_mayor_square',
  );

  static const cherrywoodBusinessPark = DublinCommuterHub(
    id: 'cherrywood_business_park',
    label: 'Cherrywood Business Park',
    latitude: 53.2440,
    longitude: -6.1465,
    anchorStationId: 'luas_green_cherrywood',
  );

  static const all = <DublinCommuterHub>[
    stStephensGreen,
    grandCanalDock,
    tcd,
    ucd,
    siliconDocks,
    cherrywoodBusinessPark,
  ];

  static List<String> get labels =>
      all.map((hub) => hub.label).toList(growable: false);

  static DublinCommuterHub? byId(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    for (final hub in all) {
      if (hub.id == id) return hub;
    }
    return null;
  }

  static DublinCommuterHub? byLabel(String? label) {
    final normalized = _normalizeLabel(label);
    if (normalized.isEmpty) return null;
    for (final hub in all) {
      if (_normalizeLabel(hub.label) == normalized) return hub;
    }
    return null;
  }

  static List<DublinCommuterHub> filterByQuery(String query) {
    final normalized = _normalizeLabel(query);
    if (normalized.isEmpty) return List<DublinCommuterHub>.from(all);

    final exact = <DublinCommuterHub>[];
    final prefix = <DublinCommuterHub>[];
    final contains = <DublinCommuterHub>[];

    for (final hub in all) {
      final hubNorm = _normalizeLabel(hub.label);
      if (hubNorm == normalized) {
        exact.add(hub);
      } else if (hubNorm.startsWith(normalized)) {
        prefix.add(hub);
      } else if (hubNorm.contains(normalized)) {
        contains.add(hub);
      }
    }

    return [...exact, ...prefix, ...contains];
  }

  /// Resolves a saved profile row to a canonical hub (id → label → coords).
  static DublinCommuterHub? resolveFromProfile(Map<String, dynamic> profile) {
    final byStoredId = byId(profile['commute_destination_hub_id']?.toString());
    if (byStoredId != null) return byStoredId;

    final label = profile['commute_destination'] ??
        profile['primary_commute_destination'];
    final byStoredLabel = byLabel(label?.toString());
    if (byStoredLabel != null) return byStoredLabel;

    final lat = profile['destination_latitude'];
    final lon = profile['destination_longitude'];
    if (lat is num && lon is num) {
      return _nearestByCoordinates(lat.toDouble(), lon.toDouble());
    }
    return null;
  }

  static Map<String, dynamic> persistFields(DublinCommuterHub hub) => {
        'commute_destination': hub.label,
        'primary_commute_destination': hub.label,
        'commute_destination_hub_id': hub.id,
        'destination_latitude': hub.latitude,
        'destination_longitude': hub.longitude,
      };

  static String _normalizeLabel(String? value) =>
      (value ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static DublinCommuterHub? _nearestByCoordinates(double lat, double lon) {
    DublinCommuterHub? closest;
    var bestKm = double.infinity;
    for (final hub in all) {
      final km = GeoMath.haversineKm(
        LatLng(lat, lon),
        hub.location,
      );
      if (km < bestKm) {
        bestKm = km;
        closest = hub;
      }
    }
    return bestKm <= 0.75 ? closest : null;
  }
}
