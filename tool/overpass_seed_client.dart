import 'dart:convert';
import 'dart:io';

import '../lib/data/poi_catalog_kind.dart';
import '../lib/services/overpass_catalog_extractor.dart';
import '../lib/services/overpass_full_query.dart';

/// Overpass API client for one-time POI catalog seeding (CLI only).
class OverpassSeedClient {
  OverpassSeedClient({HttpClient? httpClient})
      : _http = httpClient ?? HttpClient()
          ..connectionTimeout = requestTimeout
          ..idleTimeout = requestTimeout;

  static const userAgent =
      'TrueCircle-POI-Seeder/1.0 (+https://github.com/truecircle; one-time manual seed)';

  static const requestTimeout = Duration(seconds: 45);

  static const endpoints = [
    'https://overpass.private.coffee/api/interpreter',
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  final HttpClient _http;

  /// One batched Overpass request per grid cell (same query as live Phase 2).
  Future<List<PoiCatalogEntry>> fetchCell({
    required double lat,
    required double lon,
    void Function(String message)? onLog,
  }) async {
    final latStr = lat.toStringAsFixed(6);
    final lonStr = lon.toStringAsFixed(6);
    final query = buildFullOverpassQuery(latStr, lonStr);
    Object? lastError;

    for (final endpoint in endpoints) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          if (attempt > 0) {
            onLog?.call('  → retry in 3s…');
            await Future<void>.delayed(const Duration(seconds: 3));
          }
          onLog?.call('POST $endpoint');
          final elements = await _postQuery(endpoint, query);
          if (elements == null) {
            onLog?.call('  → invalid response from $endpoint');
            break;
          }
          if (elements.isEmpty) {
            onLog?.call('  → empty response from $endpoint');
            break;
          }
          onLog?.call('  → ${elements.length} raw elements');
          return extractPoiCatalogFromOverpassElements(elements);
        } catch (e) {
          lastError = e;
          onLog?.call('  → failed: $e');
          final retryable = e is HttpException &&
              (e.message.contains('504') ||
                  e.message.contains('429') ||
                  e.message.contains('timeout'));
          if (!retryable || attempt == 1) break;
        }
      }
    }

    throw HttpException(
      'All Overpass endpoints failed for $lat,$lon: $lastError',
    );
  }

  Future<List<dynamic>?> _postQuery(String endpoint, String query) async {
    return _postQueryImpl(endpoint, query).timeout(
      requestTimeout,
      onTimeout: () => throw HttpException(
        'HTTP timeout after ${requestTimeout.inSeconds}s',
        uri: Uri.parse(endpoint),
      ),
    );
  }

  Future<List<dynamic>?> _postQueryImpl(String endpoint, String query) async {
    final uri = Uri.parse(endpoint);
    final request = await _http.postUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, userAgent);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded');
    request.write('data=${Uri.encodeComponent(query)}');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}: $body', uri: uri);
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    final elements = decoded['elements'];
    if (elements is! List) return null;
    return elements;
  }

  void close() => _http.close(force: true);
}
