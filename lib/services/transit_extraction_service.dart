import 'package:flutter/foundation.dart';

import '../config/market/dublin_transit_network.dart';
import '../config/market/market_config.dart';
import '../utils/geo_math.dart';
import 'auth_service.dart';

/// Path B automated transit macro-tagging for host listings.
///
/// Local Dublin transit matching is always available. Edge enrichment via
/// `enrich-location` is optional best-effort and must never block listing flow.
abstract final class TransitExtractionService {
  /// Once the edge reports a missing Maps/Places key, skip further invokes.
  static bool _edgeEnrichmentDisabled = false;
  static bool _mapsKeySkipLogged = false;

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

  /// Nearest stop within [maxKm] when strict 1 km walking envelope has no match.
  static Map<String, dynamic>? extractNearest({
    required double latitude,
    required double longitude,
    double maxKm = 5.0,
  }) {
    if (MarketConfig.current.id != MarketId.dublin) return null;

    final location = LatLng(latitude, longitude);
    final nearest = DublinTransitNetwork.nearestTo(location);
    final km = GeoMath.haversineKm(location, nearest.position);
    if (km > maxKm) return null;

    return _proximityPayload(
      latitude: latitude,
      longitude: longitude,
      match: TransitProximityMatch(
        node: nearest,
        walkMinutes: GeoMath.walkingMinutes(km),
        distanceKm: km,
      ),
      source: 'path_b_nearest',
    );
  }

  /// Invokes the serverless PostGIS routing hook (best-effort; local fallback).
  ///
  /// Optional — missing Google Maps/Places keys skip enrichment quietly.
  static Future<Map<String, dynamic>?> enrichViaEdgeFunction({
    required double latitude,
    required double longitude,
    String? listingId,
  }) async {
    if (MarketConfig.current.id != MarketId.dublin) return null;

    if (_edgeEnrichmentDisabled) {
      return extractLocally(latitude: latitude, longitude: longitude);
    }

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
      final errorText = map['error']?.toString() ?? '';
      if (_isMissingMapsKey(errorText)) {
        _disableEdgeForMissingMapsKey();
        return extractLocally(latitude: latitude, longitude: longitude);
      }
      final proximity = map['proximity_data'];
      if (proximity is Map) {
        return Map<String, dynamic>.from(proximity);
      }
      if (map.containsKey('transit_type')) return map;
      return null;
    } catch (e) {
      if (_isMissingMapsKey(e.toString())) {
        _disableEdgeForMissingMapsKey();
      } else if (kDebugMode) {
        debugPrint('[Transit] edge enrich failed: $e');
      }
      return extractLocally(latitude: latitude, longitude: longitude);
    }
  }

  static void _disableEdgeForMissingMapsKey() {
    _edgeEnrichmentDisabled = true;
    if (!_mapsKeySkipLogged) {
      _mapsKeySkipLogged = true;
      if (kDebugMode) {
        debugPrint('[Transit] skipped - GOOGLE_MAPS_API_KEY missing');
      }
    }
  }

  static bool _isMissingMapsKey(String message) {
    final lower = message.toLowerCase();
    return lower.contains('google_maps_api_key') ||
        lower.contains('google_places_api_key') ||
        (lower.contains('google') &&
            (lower.contains('not configured') ||
                lower.contains('api key') ||
                lower.contains('missing')));
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

  /// Test-only: reset edge-skip latch between cases.
  @visibleForTesting
  static void resetEdgeEnrichmentStateForTests() {
    _edgeEnrichmentDisabled = false;
    _mapsKeySkipLogged = false;
  }
}
