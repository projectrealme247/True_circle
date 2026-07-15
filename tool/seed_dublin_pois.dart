import 'dart:io';

import '../lib/data/poi_catalog_kind.dart';
import 'overpass_seed_client.dart';
import 'poi_catalog_writer.dart';
import 'region_seed_config.dart';

/// One-time OpenStreetMap/Overpass POI seeding for metro catalogs.
///
/// Manually triggered only — no auto-scheduling.
///
/// Examples:
///   dart run tool/seed_dublin_pois.dart --estimate --region=dublin
///   dart run tool/seed_dublin_pois.dart --dry-run-samples
///   dart run tool/seed_dublin_pois.dart --dry-run --cell=53.412,-6.418
///   dart run tool/seed_dublin_pois.dart --full --region=dublin
Future<void> main(List<String> args) async {
  final parsed = _parseArgs(args);

  final region = regionSeedConfigs[parsed.regionId];
  if (region == null) {
    stderr.writeln(
      'Unknown region "${parsed.regionId}". Available: ${regionSeedConfigs.keys.join(", ")}',
    );
    exit(1);
  }

  final estimate = estimateOverpassSeedRequests(region);
  stdout.writeln('Region: ${region.label}');
  stdout.writeln(
    'Grid: ${region.cellSizeKm}km cells, ${region.stepKm}km step, '
    '1 batched Overpass query per cell',
  );
  stdout.writeln('Estimated grid cells: ${estimate.cellCount}');
  stdout.writeln('Estimated Overpass requests (full sweep): ${estimate.requestCount}');
  stdout.writeln('Overpass daily guideline: ~10,000 requests/day');
  stdout.writeln(
    'Within guideline: ${estimate.requestCount <= 10000 ? "YES" : "NO — widen step or shrink bbox"}',
  );
  stdout.writeln('Request delay: ${region.requestDelayMs}ms between cells');
  stdout.writeln('Primary endpoint: ${OverpassSeedClient.endpoints.first}');
  stdout.writeln('Manual one-time script only — not scheduled.');

  if (parsed.estimateOnly) {
    exit(0);
  }

  if (!parsed.fullSweep && parsed.dryRunCells.isEmpty) {
    stderr.writeln(
      '\nNo sweep started. Try:\n'
      '  --dry-run-samples   (3 standard Dublin pins)\n'
      '  --dry-run --cell=lat,lon\n'
      '  --full --region=dublin   (after explicit confirmation)',
    );
    exit(0);
  }

  final client = OverpassSeedClient();
  final collected = <PoiCatalogEntry>[];

  try {
    if (parsed.dryRunCells.isNotEmpty) {
      for (final cell in parsed.dryRunCells) {
        stdout.writeln('\n--- DRY RUN: ${cell.label} @ ${cell.lat},${cell.lon} ---');
        final items = await client.fetchCell(
          lat: cell.lat,
          lon: cell.lon,
          onLog: stdout.writeln,
        );
        stdout.writeln('  → ${items.length} POIs');
        final counts = countByKind(items);
        for (final kind in PoiCatalogKind.values) {
          final count = counts[kind] ?? 0;
          if (count > 0) stdout.writeln('     ${kind.name}: $count');
        }
        for (final item in items.take(10)) {
          stdout.writeln(
            '     • [${item.kind.name}] ${item.name} '
            '(${item.lat.toStringAsFixed(5)}, ${item.lon.toStringAsFixed(5)})',
          );
        }
        if (items.length > 10) stdout.writeln('     … +${items.length - 10} more');
        collected.addAll(items);
        await Future<void>.delayed(Duration(milliseconds: region.requestDelayMs));
      }
    } else {
      stdout.writeln('\n--- FULL SWEEP: ${estimate.cellCount} cells ---');
      final cells = buildSeedGrid(region);
      var cellIndex = 0;
      for (final cell in cells) {
        cellIndex++;
        stdout.writeln(
          'Cell $cellIndex/${cells.length} @ '
          '${cell.lat.toStringAsFixed(4)},${cell.lon.toStringAsFixed(4)}',
        );
        final items = await client.fetchCell(lat: cell.lat, lon: cell.lon);
        collected.addAll(items);
        await Future<void>.delayed(
          Duration(milliseconds: region.requestDelayMs),
        );
      }
    }
  } finally {
    client.close();
  }

  final deduped = dedupePoiCatalog(collected);
  final counts = countByKind(deduped);

  stdout.writeln('\n--- RESULTS ---');
  stdout.writeln('Raw POIs collected: ${collected.length}');
  stdout.writeln('After dedupe: ${deduped.length}');
  for (final kind in PoiCatalogKind.values) {
    final count = counts[kind] ?? 0;
    if (count > 0) stdout.writeln('  ${kind.name}: $count');
  }

  if (parsed.writeCatalog) {
    final output =
        parsed.outputPath ?? 'lib/data/generated/dublin_poi_catalog.g.dart';
    await writePoiCatalogDart(
      outputPath: output,
      regionId: region.id,
      entries: deduped,
    );
    stdout.writeln('\nWrote catalog → $output');
  } else {
    stdout.writeln(
      '\nCatalog file not written (dry-run). After confirming quality, run:\n'
      '  dart run tool/seed_dublin_pois.dart --full --region=dublin',
    );
  }
}

class _DryRunCell {
  const _DryRunCell({required this.label, required this.lat, required this.lon});
  final String label;
  final double lat;
  final double lon;
}

class _ParsedArgs {
  const _ParsedArgs({
    required this.regionId,
    required this.estimateOnly,
    required this.dryRunCells,
    required this.writeCatalog,
    required this.fullSweep,
    this.outputPath,
  });

  final String regionId;
  final bool estimateOnly;
  final List<_DryRunCell> dryRunCells;
  final bool writeCatalog;
  final bool fullSweep;
  final String? outputPath;
}

_ParsedArgs _parseArgs(List<String> args) {
  var regionId = 'dublin';
  var estimateOnly = args.isEmpty;
  final dryRunCells = <_DryRunCell>[];
  var writeCatalog = true;
  var fullSweep = false;
  String? outputPath;

  for (final arg in args) {
    if (arg == '--estimate' || arg == '--estimate-only') {
      estimateOnly = true;
      writeCatalog = false;
    } else if (arg == '--full') {
      fullSweep = true;
      estimateOnly = false;
    } else if (arg == '--dry-run') {
      writeCatalog = false;
      estimateOnly = false;
    } else if (arg == '--dry-run-samples') {
      writeCatalog = false;
      estimateOnly = false;
      for (final sample in dublinSampleDryRunCells) {
        dryRunCells.add(
          _DryRunCell(label: sample.label, lat: sample.lat, lon: sample.lon),
        );
      }
    } else if (arg == '--write') {
      writeCatalog = true;
    } else if (arg.startsWith('--region=')) {
      regionId = arg.substring('--region='.length);
    } else if (arg.startsWith('--cell=')) {
      final parts = arg.substring('--cell='.length).split(',');
      if (parts.length == 2) {
        dryRunCells.add(
          _DryRunCell(
            label: 'Custom cell',
            lat: double.parse(parts[0]),
            lon: double.parse(parts[1]),
          ),
        );
        estimateOnly = false;
      }
    } else if (arg.startsWith('--output=')) {
      outputPath = arg.substring('--output='.length);
    } else if (arg == '--help' || arg == '-h') {
      stdout.writeln('Usage: dart run tool/seed_dublin_pois.dart [options]');
      stdout.writeln('  --estimate              Print request budget only');
      stdout.writeln('  --dry-run-samples       Dry-run 3 standard Dublin pins');
      stdout.writeln('  --dry-run --cell=lat,lon  Dry-run one grid cell');
      stdout.writeln('  --full --region=dublin  Full sweep (manual, after confirmation)');
      exit(0);
    }
  }

  if (dryRunCells.isNotEmpty && !args.contains('--write')) {
    writeCatalog = false;
  }

  if (dryRunCells.isEmpty && !estimateOnly) {
    writeCatalog = fullSweep;
  }

  return _ParsedArgs(
    regionId: regionId,
    estimateOnly: estimateOnly,
    dryRunCells: dryRunCells,
    writeCatalog: writeCatalog,
    fullSweep: fullSweep,
    outputPath: outputPath,
  );
}
