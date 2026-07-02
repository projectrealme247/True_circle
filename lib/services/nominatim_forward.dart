import '../utils/irish_address_format.dart';
import 'nominatim_forward_stub.dart'
    if (dart.library.js_interop) 'nominatim_forward_web.dart' as impl;

/// A geocoded address result from Nominatim.
class NominatimAddressResult {
  const NominatimAddressResult({
    required this.displayLabel,
    required this.lat,
    required this.lon,
    required this.streetLine,
    required this.area,
    required this.county,
  });

  final String displayLabel;
  final double lat;
  final double lon;
  final String streetLine;
  final String area;
  final String county;
}

/// Forward-geocode an Eircode via Nominatim, returning address components.
///
/// Returns a map with keys: lat, lon, display_name, house_number, road,
/// neighbourhood, suburb, city_district, city, county, postcode.
/// Returns null if the lookup fails or the platform is not web.
abstract final class NominatimForward {
  static Future<Map<String, dynamic>?> searchEircode(String eircode) =>
      impl.searchEircode(eircode);

  /// Best pin for amenities — exact Eircode match first, then routing-key match.
  static Future<Map<String, dynamic>?> searchEircodePin(String eircode) =>
      impl.searchEircodePin(eircode);

  /// Search for a street address in Dublin, returning up to 5 geocoded results.
  /// This is the primary geocoding method for the listing form.
  static Future<List<NominatimAddressResult>> searchAddress(String query) =>
      impl.searchAddress(query);

  /// Build a human-readable street address from the Nominatim result map.
  /// e.g. "9 Hollywoodrath Park, Hollystown, Dublin 15, D15 FT9N"
  static String? formatAddress(Map<String, dynamic> data, {String? eircode}) {
    final fields = <String, String>{
      for (final key in [
        'house_number',
        'road',
        'neighbourhood',
        'suburb',
        'city_district',
        'city',
        'county',
        'state',
        'postcode',
      ])
        if (data[key] != null) key: data[key].toString(),
    };

    final code = (eircode ?? fields['postcode'] ?? '').trim();
    if (code.isEmpty) return null;
    return IrishAddressFormat.formatFull(fields: fields, eircode: code);
  }

  /// Reverse geocode lat/lon to a readable address string via Nominatim.
  static Future<String?> reverseGeocode(double lat, double lon) =>
      impl.reverseGeocode(lat, lon);

  /// Extract a short public-area label for the privacy checkbox.
  /// e.g. "Hollywoodrath, Hollystown"
  static String? formatPublicArea(Map<String, dynamic> data) =>
      IrishAddressFormat.formatPublicArea({
        for (final entry in data.entries)
          entry.key.toString(): entry.value?.toString() ?? '',
      });
}
