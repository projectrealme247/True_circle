import 'google_geocoding_stub.dart' as impl;

/// Google Maps Geocoding API — resolves Eircodes and Irish addresses to
/// exact building-level coordinates with full address components.
abstract final class GoogleGeocodingService {
  /// Geocodes an Eircode or address query and returns structured components.
  /// Returns null if the key is unconfigured or the lookup fails.
  static Future<GoogleGeocodingResult?> geocode(String query) =>
      impl.geocode(query);

  /// Forward-geocodes a normalized Eircode with Places API fallback.
  static Future<GoogleGeocodingResult?> geocodeEircode(String normalized) =>
      impl.geocodeEircode(normalized);

  /// Reverse-geocodes GPS coordinates to the nearest address + Eircode.
  static Future<GoogleGeocodingResult?> reverseGeocode(
    double latitude,
    double longitude,
  ) =>
      impl.reverseGeocode(latitude, longitude);

  /// GPS path: reverse-geocode, then forward/Places for building-level address.
  static Future<GoogleGeocodingResult?> resolveGpsCoordinates(
    double latitude,
    double longitude,
  ) =>
      impl.resolveGpsCoordinates(latitude, longitude);

  /// Preloads the Maps JS SDK so the first lookup is fast.
  static Future<void> prewarm() => impl.prewarm();
}

class GoogleGeocodingResult {
  const GoogleGeocodingResult({
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.streetNumber,
    this.route,
    this.premise,
    this.neighbourhood,
    this.sublocality,
    this.locality,
    this.county,
    this.postalCode,
  });

  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? streetNumber;
  final String? route;
  final String? premise;
  final String? neighbourhood;
  final String? sublocality;
  final String? locality;
  final String? county;
  final String? postalCode;
}
