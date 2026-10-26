import 'dart:io';

import '../lib/data/poi_catalog_kind.dart';
import '../lib/services/overpass_catalog_extractor.dart';
import 'osm_pbf_reader.dart';
import 'poi_catalog_writer.dart';
import 'region_seed_config.dart';

/// Offline POI seeding from a Geofabrik `.osm.pbf` extract (no Overpass).
///
/// Use when Overpass is unreachable or rate-limited. Produces the same catalog
/// as `seed_dublin_pois.dart` (same extractor, dedupe, and writer).
///
///   Invoke-WebRequest https://download.geofabrik.de/europe/ireland-and-northern-ireland-latest.osm.pbf -OutFile ireland.osm.pbf
///   dart run tool/seed_pois_from_pbf.dart --pbf=ireland.osm.pbf --region=dublin
Future<void> main(List<String> args) async {
  String? pbfPath;
  var regionId = 'dublin';
  var outputPath = 'lib/data/generated/dublin_poi_catalog.g.dart';
  for (final arg in args) {
    if (arg.startsWith('--pbf=')) pbfPath = arg.substring('--pbf='.length);
    if (arg.startsWith('--region=')) regionId = arg.substring('--region='.length);
    if (arg.startsWith('--output=')) outputPath = arg.substring('--output='.length);
  }
  final region = regionSeedConfigs[regionId];
  if (pbfPath == null || region == null) {
    stderr.writeln(
      'Usage: dart run tool/seed_pois_from_pbf.dart --pbf=<file.osm.pbf> '
      '[--region=${regionSeedConfigs.keys.join("|")}] [--output=path]',
    );
    exit(64);
  }

  // Grid-edge cells query up to ~2km beyond the region box.
  final minLat = region.minLat - 0.02, maxLat = region.maxLat + 0.02;
  final minLon = region.minLon - 0.035, maxLon = region.maxLon + 0.035;
  bool inBox(double lat, double lon) =>
      lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;

  final nodeIds = <int>[];
  final nodeLatE7 = <int>[];
  final nodeLonE7 = <int>[];
  final elements = <Map<String, Object>>[];
  final candidateWays = <OsmWay>[];
  var blockCount = 0;
  var lastNodeId = -1;
  var nodesSorted = true;
  final sw = Stopwatch()..start();

  await for (final block in OsmPbfReader(pbfPath).blocks()) {
    for (final node in block.nodes) {
      if (!inBox(node.lat, node.lon)) continue;
      if (node.id < lastNodeId) nodesSorted = false;
      lastNodeId = node.id;
      nodeIds.add(node.id);
      nodeLatE7.add((node.lat * 1e7).round());
      nodeLonE7.add((node.lon * 1e7).round());
      if (_isCandidate(node.tags)) {
        elements.add({
          'lat': node.lat,
          'lon': node.lon,
          'tags': _forExtractor(node.tags),
        });
      }
    }
    for (final way in block.ways) {
      if (_isCandidate(way.tags)) candidateWays.add(way);
    }
    if (++blockCount % 500 == 0) {
      stdout.writeln(
        '  blocks=$blockCount boxNodes=${nodeIds.length} '
        'poiNodes=${elements.length} candidateWays=${candidateWays.length} '
        '(${sw.elapsed.inSeconds}s)',
      );
    }
  }
  if (!nodesSorted) {
    stderr.writeln('PBF nodes are not sorted by id; cannot resolve way centers.');
    exit(1);
  }

  var wayCount = 0;
  for (final way in candidateWays) {
    double? minA, maxA, minO, maxO;
    for (final ref in way.refs) {
      final i = _binarySearch(nodeIds, ref);
      if (i < 0) continue;
      final lat = nodeLatE7[i] / 1e7, lon = nodeLonE7[i] / 1e7;
      minA = minA == null || lat < minA ? lat : minA;
      maxA = maxA == null || lat > maxA ? lat : maxA;
      minO = minO == null || lon < minO ? lon : minO;
      maxO = maxO == null || lon > maxO ? lon : maxO;
    }
    if (minA == null) continue;
    final centerLat = (minA + maxA!) / 2, centerLon = (minO! + maxO!) / 2;
    if (!inBox(centerLat, centerLon)) continue;
    wayCount++;
    elements.add({
      'center': {'lat': centerLat, 'lon': centerLon},
      'tags': _forExtractor(way.tags),
    });
  }

  final extracted = extractPoiCatalogFromOverpassElements(elements);
  final deduped = dedupePoiCatalog(extracted);
  final counts = countByKind(deduped);

  stdout.writeln('\n--- RESULTS (${sw.elapsed.inSeconds}s) ---');
  stdout.writeln('Candidate elements: ${elements.length} ($wayCount ways)');
  stdout.writeln('Extracted: ${extracted.length}  After dedupe: ${deduped.length}');
  for (final kind in PoiCatalogKind.values) {
    final count = counts[kind] ?? 0;
    if (count > 0) stdout.writeln('  ${kind.name}: $count');
  }

  await writePoiCatalogDart(
    outputPath: outputPath,
    regionId: region.id,
    entries: deduped,
    generator: 'tool/seed_pois_from_pbf.dart',
    source: 'OpenStreetMap (Geofabrik extract ${pbfPath.split(RegExp(r'[\\/]')).last})',
    rerunCommand: 'dart run tool/seed_pois_from_pbf.dart --pbf=<ireland.osm.pbf> --region=${region.id}',
  );
  stdout.writeln('\nWrote catalog → $outputPath');
}

const _shops = {
  'supermarket',
  'convenience',
  'pizza',
  'asian',
  'asian_supermarket',
  'oriental',
};
const _amenities = {
  'school',
  'childcare',
  'kindergarten',
  'pub',
  'bar',
  'biergarten',
  'atm',
  'bank',
  'fast_food',
  'pharmacy',
  'cafe',
  'restaurant',
};
const _leisure = {'fitness_centre', 'sports_centre', 'park'};
const _tourism = {'attraction', 'museum', 'gallery'};
const _landuse = {'commercial', 'industrial'};

/// Same tag families as [buildFullOverpassQuery] (transit/postcode excluded).
bool _isCandidate(Map<String, String> tags) =>
    tags.isNotEmpty &&
    (_shops.contains(tags['shop']) ||
        _amenities.contains(tags['amenity']) ||
        _leisure.contains(tags['leisure']) ||
        _tourism.contains(tags['tourism']) ||
        _landuse.contains(tags['landuse']) ||
        tags.containsKey('office'));

/// The extractor drops anything with `addr:postcode` because the live query
/// fetches postcode-only elements for Eircode lookup. Every element here is
/// already a POI, so the address tag must not disqualify it.
Map<String, String> _forExtractor(Map<String, String> tags) =>
    Map.of(tags)..remove('addr:postcode');

int _binarySearch(List<int> sorted, int value) {
  var lo = 0, hi = sorted.length - 1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    final v = sorted[mid];
    if (v == value) return mid;
    if (v < value) {
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return -1;
}
