import 'package:geocoding/geocoding.dart';

import '../config/market/dublin_commuter_hubs.dart';
import '../utils/geo_math.dart';

/// Forward-geocodes free-text Dublin commute destinations into GIS anchors.
abstract final class CommuteDestinationGeocodingService {
  static Future<DublinCommuterHub?> resolveCustomDestination(
    String query, {
    Future<List<Location>> Function(String query)? geocodeForTests,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    final canonical = DublinCommuterHubs.byLabel(trimmed);
    if (canonical != null) return canonical;

    final searchQuery = trimmed.toLowerCase().contains('ireland')
        ? trimmed
        : '$trimmed, Dublin, Ireland';

    try {
      final results = geocodeForTests != null
          ? await geocodeForTests(searchQuery)
          : await locationFromAddress(searchQuery);
      if (results.isEmpty) return null;

      final loc = results.first;
      if (!_isWithinGreaterDublin(loc.latitude, loc.longitude)) {
        return null;
      }

      return DublinCommuterHubs.fromGeocoded(
        label: trimmed,
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isWithinGreaterDublin(double lat, double lon) {
    const center = LatLng(53.3498, -6.2603);
    return GeoMath.haversineKm(center, LatLng(lat, lon)) <= 45;
  }
}
