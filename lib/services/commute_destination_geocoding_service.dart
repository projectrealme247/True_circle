import 'package:geocoding/geocoding.dart';

import '../config/market/dublin_commuter_hubs.dart';
import '../models/dublin_destination_suggestion.dart';
import 'seeker_destination_nominatim_service.dart';

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

    if (geocodeForTests != null) {
      return _resolveWithGeocodeForTests(trimmed, geocodeForTests);
    }

    final suggestions =
        await SeekerDestinationNominatimService.searchOnSubmit(trimmed);
    if (suggestions.isEmpty) return null;

    return SeekerDestinationNominatimService.hubFromSuggestion(suggestions.first);
  }

  static Future<DublinCommuterHub?> resolveFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    final suggestion = await SeekerDestinationNominatimService.reverseGeocode(
      latitude,
      longitude,
    );
    if (suggestion == null) return null;
    return SeekerDestinationNominatimService.hubFromSuggestion(suggestion);
  }

  static Future<DublinCommuterHub?> _resolveWithGeocodeForTests(
    String trimmed,
    Future<List<Location>> Function(String query) geocodeForTests,
  ) async {
    final searchQuery = trimmed.toLowerCase().contains('ireland')
        ? trimmed
        : '$trimmed, Dublin, Ireland';

    try {
      final results = await geocodeForTests(searchQuery);
      if (results.isEmpty) return null;

      final loc = results.first;
      return DublinCommuterHubs.fromGeocoded(
        label: trimmed,
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
    } catch (_) {
      return null;
    }
  }
}
