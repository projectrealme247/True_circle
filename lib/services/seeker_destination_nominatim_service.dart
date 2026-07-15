import '../config/market/dublin_commuter_hubs.dart';
import '../models/dublin_destination_suggestion.dart';
import '../utils/dublin_placemark_label.dart';
import '../utils/geo_math.dart';
import 'seeker_destination_nominatim_stub.dart'
    if (dart.library.js_interop) 'seeker_destination_nominatim_web.dart'
    as impl;

/// On-demand Nominatim search for seeker commute destinations (no keystroke autocomplete).
abstract final class SeekerDestinationNominatimService {
  static const _dublinCenter = LatLng(53.3498, -6.2603);

  static Future<List<DublinDestinationSuggestion>> searchOnSubmit(
    String query,
  ) =>
      impl.search(query);

  static Future<DublinDestinationSuggestion?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    if (!_isWithinGreaterDublin(latitude, longitude)) return null;

    final nominatim = await impl.reverseGeocode(latitude, longitude);
    if (nominatim != null) return nominatim;

    final label = await DublinPlacemarkLabel.resolve(latitude, longitude);
    if (label.trim().isEmpty) return null;

    return DublinDestinationSuggestion(
      displayLabel: label.trim(),
      latitude: latitude,
      longitude: longitude,
      source: 'gps',
    );
  }

  static DublinCommuterHub hubFromSuggestion(DublinDestinationSuggestion suggestion) {
    return DublinCommuterHubs.fromGeocoded(
      label: suggestion.displayLabel,
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
    );
  }

  static bool _isWithinGreaterDublin(double lat, double lon) {
    return GeoMath.haversineKm(_dublinCenter, LatLng(lat, lon)) <= 45;
  }
}
