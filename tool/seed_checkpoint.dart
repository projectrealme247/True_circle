import 'dart:convert';
import 'dart:io';

import '../lib/data/poi_catalog_kind.dart';

/// Per-cell progress for a full POI sweep so an interrupted run can resume.
class SeedCheckpoint {
  SeedCheckpoint(this.path);

  factory SeedCheckpoint.forRegion(String regionId) =>
      SeedCheckpoint('.dart_tool/poi_seed_checkpoint_$regionId.json');

  final String path;

  Future<Map<int, List<PoiCatalogEntry>>> load() async {
    final file = File(path);
    if (!await file.exists()) return {};
    final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries)
        int.parse(entry.key): [
          for (final raw in entry.value as List)
            PoiCatalogEntry(
              name: raw['n'] as String,
              lat: (raw['a'] as num).toDouble(),
              lon: (raw['o'] as num).toDouble(),
              kind: PoiCatalogKind.values.byName(raw['k'] as String),
            ),
        ],
    };
  }

  Future<void> save(Map<int, List<PoiCatalogEntry>> done) async {
    final encoded = jsonEncode({
      for (final entry in done.entries)
        '${entry.key}': [
          for (final poi in entry.value)
            {'n': poi.name, 'a': poi.lat, 'o': poi.lon, 'k': poi.kind.name},
        ],
    });
    final file = File(path);
    await file.parent.create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(encoded);
    await tmp.rename(path);
  }

  Future<void> delete() async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
