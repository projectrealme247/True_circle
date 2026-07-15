import 'dart:math' as math;

/// Region bounding box + grid parameters for Overpass POI seeding.
class RegionSeedConfig {
  const RegionSeedConfig({
    required this.id,
    required this.label,
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
    this.cellSizeKm = 2.0,
    this.stepKm = 1.0,
    this.requestDelayMs = 1500,
  });

  final String id;
  final String label;
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;
  final double cellSizeKm;
  final double stepKm;

  /// Delay between Overpass requests (respectful one-time seeding).
  final int requestDelayMs;
}

/// Predefined metro regions. Add Cork/Galway/Limerick configs here later.
final Map<String, RegionSeedConfig> regionSeedConfigs = {
  'dublin': const RegionSeedConfig(
    id: 'dublin',
    label: 'Dublin metro (24 districts + suburbs)',
    minLat: 53.205,
    maxLat: 53.505,
    minLon: -6.565,
    maxLon: -6.045,
    cellSizeKm: 2.0,
    stepKm: 1.0,
    requestDelayMs: 1500,
  ),
};

/// Standard dry-run sample pins for Dublin coverage checks.
const dublinSampleDryRunCells = <({String label, double lat, double lon})>[
  (label: 'City Centre (D1/D2)', lat: 53.3498, lon: -6.2603),
  (label: 'Hollywoodrath / D15', lat: 53.412, lon: -6.418),
  (label: 'Swords / North County', lat: 53.4597, lon: -6.2181),
];

/// One batched Overpass query per grid cell (same as live Phase 2).
({int cellCount, int requestCount}) estimateOverpassSeedRequests(
  RegionSeedConfig region,
) {
  final cells = buildSeedGrid(region);
  return (cellCount: cells.length, requestCount: cells.length);
}

/// Builds overlapping grid cell centers covering [region].
List<({double lat, double lon, int row, int col})> buildSeedGrid(
  RegionSeedConfig region,
) {
  final latKm = 111.0;
  final lonKm =
      111.0 * math.cos((region.minLat + region.maxLat) / 2 * math.pi / 180);
  final latStep = region.stepKm / latKm;
  final lonStep = region.stepKm / lonKm;

  final cells = <({double lat, double lon, int row, int col})>[];
  var row = 0;
  for (var lat = region.minLat; lat <= region.maxLat; lat += latStep, row++) {
    var col = 0;
    for (var lon = region.minLon; lon <= region.maxLon; lon += lonStep, col++) {
      cells.add((lat: lat, lon: lon, row: row, col: col));
    }
  }
  return cells;
}
