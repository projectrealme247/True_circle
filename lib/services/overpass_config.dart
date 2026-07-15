import 'package:flutter/foundation.dart';

/// Central Overpass timeout and diagnostics configuration.
///
/// Client [requestTimeoutFor] always exceeds the Overpass QL `[timeout:N]` by
/// [safetyBuffer] so the server can finish before the XHR is aborted.
abstract final class OverpassConfig {
  /// Extra headroom above the Overpass query timeout before the XHR aborts.
  static const Duration safetyBuffer = Duration(seconds: 5);

  /// Overpass QL `[timeout:N]` for the full amenity batch query.
  static const int fullQueryTimeoutSeconds = 18;

  /// Overpass QL `[timeout:N]` for the reduced essentials fallback query.
  static const int essentialsQueryTimeoutSeconds = 12;

  static int queryTimeoutSeconds(OverpassQueryType type) => switch (type) {
        OverpassQueryType.full => fullQueryTimeoutSeconds,
        OverpassQueryType.essentials => essentialsQueryTimeoutSeconds,
      };

  /// XHR timeout — always query timeout + [safetyBuffer].
  static Duration requestTimeoutFor(OverpassQueryType type) =>
      Duration(seconds: queryTimeoutSeconds(type)) + safetyBuffer;

  static String queryHeader(OverpassQueryType type) =>
      '[out:json][timeout:${queryTimeoutSeconds(type)}]';

  /// Permanent Overpass fetch diagnostics (debug console).
  static void logFetch({
    required OverpassQueryType queryType,
    required String endpoint,
    required Duration duration,
    required String outcome,
    int? elementCount,
  }) {
    final host = Uri.tryParse(endpoint)?.host ?? endpoint;
    debugPrint(
      'Overpass fetch: query=${queryType.label} '
      'durationMs=${duration.inMilliseconds} '
      'elements=${elementCount ?? 'n/a'} '
      'outcome=$outcome '
      'endpoint=$host '
      'queryTimeoutSec=${queryTimeoutSeconds(queryType)} '
      'requestTimeoutSec=${requestTimeoutFor(queryType).inSeconds}',
    );
  }
}

/// Amenity lookup query shape used by the web Overpass client.
enum OverpassQueryType {
  full,
  essentials;

  String get label => switch (this) {
        OverpassQueryType.full => 'full',
        OverpassQueryType.essentials => 'essentials',
      };
}
