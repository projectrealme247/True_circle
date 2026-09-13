import '../../models/seeker_onboarding_enums.dart';
import '../../utils/geo_math.dart';
import 'dublin_transit_network.dart';

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

/// Display chip + canonical hub for seeker macro destination quick picks.
class SeekerMacroPreset {
  const SeekerMacroPreset({required this.chipLabel, required this.hub});

  final String chipLabel;
  final DublinCommuterHub hub;
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
    label: 'Cherrywood',
    latitude: 53.2440,
    longitude: -6.1465,
    anchorStationId: 'luas_green_cherrywood',
  );

  static const ifscDocklands = DublinCommuterHub(
    id: 'ifsc_docklands',
    label: 'IFSC',
    latitude: 53.3478,
    longitude: -6.2427,
    anchorStationId: 'luas_red_connolly',
  );

  static const dcu = DublinCommuterHub(
    id: 'dcu',
    label: 'Dublin City University (DCU)',
    latitude: 53.3851,
    longitude: -6.2577,
    anchorStationId: 'luas_green_parnell',
  );

  static const sandyford = DublinCommuterHub(
    id: 'sandyford',
    label: 'Sandyford',
    latitude: 53.2775,
    longitude: -6.2040,
    anchorStationId: 'luas_green_sandyford',
  );

  static const dublinAirport = DublinCommuterHub(
    id: 'dublin_airport',
    label: 'Dublin Airport / North Dublin',
    latitude: 53.4264,
    longitude: -6.2499,
    anchorStationId: 'dart_clontarf_road',
  );

  static const stJamesHospital = DublinCommuterHub(
    id: 'st_james_hospital',
    label: "St James's Hospital",
    latitude: 53.3419,
    longitude: -6.2954,
    anchorStationId: 'luas_red_heuston',
  );

  static const beaumontHospital = DublinCommuterHub(
    id: 'beaumont_hospital',
    label: 'Beaumont Hospital',
    latitude: 53.3884,
    longitude: -6.2275,
    anchorStationId: 'luas_green_parnell',
  );

  static const rcsi = DublinCommuterHub(
    id: 'rcsi',
    label: 'Royal College of Surgeons in Ireland (RCSI)',
    latitude: 53.3412,
    longitude: -6.2575,
    anchorStationId: 'luas_green_st_stephens_green',
  );

  static const nci = DublinCommuterHub(
    id: 'nci',
    label: 'National College of Ireland (NCI)',
    latitude: 53.3489,
    longitude: -6.2432,
    anchorStationId: 'luas_green_mayor_square',
  );

  static const blanchardstownBusinessPark = DublinCommuterHub(
    id: 'blanchardstown_business_park',
    label: 'Blanchardstown Business & Technology Park',
    latitude: 53.4057,
    longitude: -6.3779,
    anchorStationId: 'bus_hf_blanchardstown',
  );

  static const tuDublin = DublinCommuterHub(
    id: 'tu_dublin',
    label: 'TU Dublin',
    latitude: 53.3547,
    longitude: -6.2797,
    anchorStationId: 'luas_green_parnell',
  );

  static const maynooth = DublinCommuterHub(
    id: 'maynooth',
    label: 'Maynooth University',
    latitude: 53.3835,
    longitude: -6.5996,
    anchorStationId: 'bus_hf_lucan',
  );

  static const otherLocationLabel = 'Other location…';

  static const all = <DublinCommuterHub>[
    stStephensGreen,
    grandCanalDock,
    tcd,
    ucd,
    siliconDocks,
    cherrywoodBusinessPark,
    ifscDocklands,
    dcu,
    sandyford,
    dublinAirport,
    stJamesHospital,
    beaumontHospital,
    rcsi,
    nci,
    tuDublin,
    maynooth,
    blanchardstownBusinessPark,
  ];

  /// Quick-tap macro presets (passport / legacy surfaces).
  static const seekerMacroPresets = <SeekerMacroPreset>[
    SeekerMacroPreset(chipLabel: '🎓 Trinity (TCD)', hub: tcd),
    SeekerMacroPreset(chipLabel: '🎓 UCD', hub: ucd),
    SeekerMacroPreset(chipLabel: '🎓 DCU', hub: dcu),
    SeekerMacroPreset(chipLabel: '🧑‍💻 Silicon Docks', hub: siliconDocks),
    SeekerMacroPreset(chipLabel: '💼 IFSC', hub: ifscDocklands),
    SeekerMacroPreset(chipLabel: '🏪 Sandyford', hub: sandyford),
  ];

  /// Student weekday destination presets (Destination Step V3).
  /// Destination is required via preset or custom search — no "Not sure yet".
  static const studentDestinationPresets = <SeekerMacroPreset>[
    SeekerMacroPreset(chipLabel: '🎓 Trinity College Dublin (TCD)', hub: tcd),
    SeekerMacroPreset(chipLabel: '🎓 University College Dublin (UCD)', hub: ucd),
    SeekerMacroPreset(chipLabel: '🎓 Dublin City University (DCU)', hub: dcu),
    SeekerMacroPreset(chipLabel: '🎓 TU Dublin', hub: tuDublin),
    SeekerMacroPreset(chipLabel: '🎓 Maynooth University', hub: maynooth),
    SeekerMacroPreset(chipLabel: '🎓 National College of Ireland (NCI)', hub: nci),
    SeekerMacroPreset(
      chipLabel: '🩺 Royal College of Surgeons in Ireland (RCSI)',
      hub: rcsi,
    ),
  ];

  /// Professional / Family weekday destination presets (Destination Step V3).
  static const professionalDestinationPresets = <SeekerMacroPreset>[
    SeekerMacroPreset(chipLabel: '💼 IFSC', hub: ifscDocklands),
    SeekerMacroPreset(chipLabel: '🧑‍💻 Silicon Docks', hub: siliconDocks),
    SeekerMacroPreset(chipLabel: '🏙️ City Centre', hub: stStephensGreen),
    SeekerMacroPreset(chipLabel: '🏪 Sandyford', hub: sandyford),
    SeekerMacroPreset(chipLabel: '🏢 Cherrywood', hub: cherrywoodBusinessPark),
    SeekerMacroPreset(
      chipLabel: '🏬 Blanchardstown Business & Technology Park',
      hub: blanchardstownBusinessPark,
    ),
    SeekerMacroPreset(
      chipLabel: '✈️ Dublin Airport / North Dublin',
      hub: dublinAirport,
    ),
  ];

  /// Union of student + professional presets (legacy surfaces).
  static const seekerOnboardingPresets = <SeekerMacroPreset>[
    ...studentDestinationPresets,
    ...professionalDestinationPresets,
  ];

  /// Persona-filtered hub list for onboarding popular destinations.
  ///
  /// Student → colleges; Professional / Family / Relocating → business hubs.
  static List<SeekerMacroPreset> seekerOnboardingPresetsForPersona(
    SeekerPersona? persona,
  ) {
    return switch (persona) {
      SeekerPersona.student =>
        List<SeekerMacroPreset>.from(studentDestinationPresets),
      SeekerPersona.professional ||
      SeekerPersona.family ||
      SeekerPersona.relocating ||
      null =>
        List<SeekerMacroPreset>.from(professionalDestinationPresets),
    };
  }

  /// Curated anchors for working professionals and families.
  static const professionalPopular = <DublinCommuterHub>[
    stStephensGreen,
    grandCanalDock,
    siliconDocks,
    ifscDocklands,
    cherrywoodBusinessPark,
    dublinAirport,
  ];

  /// Curated anchors for students.
  static const studentPopular = <DublinCommuterHub>[
    tcd,
    ucd,
    dcu,
    stStephensGreen,
    grandCanalDock,
  ];

  static List<DublinCommuterHub> hubsForOccupantType(String? occupantType) {
    if (occupantType == 'Students') {
      return List<DublinCommuterHub>.from(studentPopular);
    }
    return List<DublinCommuterHub>.from(professionalPopular);
  }

  static bool isCustomHub(DublinCommuterHub hub) => hub.id.startsWith('custom_');

  /// Builds a commute anchor from a geocoded Dublin-area place name.
  static DublinCommuterHub fromGeocoded({
    required String label,
    required double latitude,
    required double longitude,
  }) {
    final nearestCanonical = _nearestByCoordinates(latitude, longitude);
    final nearestTransit = DublinTransitNetwork.nearestTo(
      LatLng(latitude, longitude),
    );
    final anchorId = nearestCanonical?.anchorStationId ?? nearestTransit.id;
    final normalized = label.trim();
    final slug = normalized
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return DublinCommuterHub(
      id: 'custom_${slug.isEmpty ? 'place' : slug}',
      label: normalized,
      latitude: latitude,
      longitude: longitude,
      anchorStationId: anchorId,
    );
  }

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
    // Legacy saved labels after Destination Step V3 renames.
    if (normalized == 'ifsc / docklands' || normalized == 'ifsc') {
      return ifscDocklands;
    }
    if (normalized == 'cherrywood business park' || normalized == 'cherrywood') {
      return cherrywoodBusinessPark;
    }
    if (normalized == 'dublin airport' ||
        normalized == 'dublin airport / north dublin') {
      return dublinAirport;
    }
    if (normalized == 'rcsi (royal college of surgeons)' ||
        normalized == 'royal college of surgeons in ireland (rcsi)' ||
        normalized == 'rcsi') {
      return rcsi;
    }
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
    final hubId = profile['commute_destination_hub_id']?.toString();
    if (hubId != null && hubId.startsWith('custom_')) {
      final lat = profile['destination_latitude'];
      final lon = profile['destination_longitude'];
      final label = profile['commute_destination'] ??
          profile['primary_commute_destination'];
      if (lat is num && lon is num && label != null) {
        return fromGeocoded(
          label: label.toString(),
          latitude: lat.toDouble(),
          longitude: lon.toDouble(),
        );
      }
    }

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
