import 'package:flutter/foundation.dart';

import '../config/market/dublin_transit_network.dart';
import '../config/market/market_config.dart';
import '../utils/geo_math.dart';
import 'auth_service.dart';

/// Path B automated transit macro-tagging for host listings.
abstract final class TransitExtractionService {
  /// Builds `proximity_data` when coords fall within the strict walk envelope.
  static Map<String, dynamic>? extractLocally({
    required double latitude,
    required double longitude,
  }) {
    if (MarketConfig.current.id != MarketId.dublin) return null;

    final match = DublinTransitNetwork.matchWithinWalkingThreshold(
      LatLng(latitude, longitude),
    );
    if (match == null) return null;

    return _proximityPayload(
      latitude: latitude,
      longitude: longitude,
      match: match,
      source: 'path_b_local',
    );
  }

  /// Invokes the serverless PostGIS routing hook (best-effort; local fallback on failure).
  static Future<Map<String, dynamic>?> enrichViaEdgeFunction({
    required double latitude,
    required double longitude,
    String? listingId,
  }) async {
    if (MarketConfig.current.id != MarketId.dublin) return null;

    try {
      final response = await AuthService.client.functions.invoke(
        'enrich-location',
        body: {
          'latitude': latitude,
          'longitude': longitude,
          if (listingId != null && listingId.isNotEmpty)
            'listing_id': listingId,
        },
      );

      final data = response.data;
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      final proximity = map['proximity_data'];
      if (proximity is Map) {
        return Map<String, dynamic>.from(proximity);
      }
      if (map.containsKey('transit_type')) return map;
      return null;
    } catch (e, stack) {
      debugPrint('TransitExtractionService edge enrich failed: $e\n$stack');
      return extractLocally(latitude: latitude, longitude: longitude);
    }
  }

  /// Local extraction first for instant UI; edge hook refines when available.
  static Future<Map<String, dynamic>?> resolveProximityData({
    required double latitude,
    required double longitude,
    String? listingId,
    bool callEdgeFunction = true,
  }) async {
    final local = extractLocally(latitude: latitude, longitude: longitude);
    if (!callEdgeFunction) return local;

    final remote = await enrichViaEdgeFunction(
      latitude: latitude,
      longitude: longitude,
      listingId: listingId,
    );
    return remote ?? local;
  }

  static Map<String, dynamic> _proximityPayload({
    required double latitude,
    required double longitude,
    required TransitProximityMatch match,
    required String source,
  }) {
    final transitType = DublinTransitNetwork.transitTypeLabel(match.node.mode);
    final stopName = match.node.name;
    final walkMinutes = match.walkMinutes;

    return {
      'transit_type': transitType,
      'walk_minutes': walkMinutes,
      'nearest_stop_name': stopName,
      'nearest_stop_id': match.node.id,
      'nearest_transit_name': stopName,
      'nearest_transit_minutes': walkMinutes,
      'luas_line': transitType,
      'luas_minutes': walkMinutes,
      'transit_headline': '$walkMinutes-min walk to $stopName',
      'has_direct_luas': match.node.mode != DublinTransitMode.busHighFrequency,
      'source': source,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
