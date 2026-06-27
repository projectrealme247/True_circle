import 'package:geocoding/geocoding.dart';

/// Eircode format validation and coordinate resolution for Dublin listings.
abstract final class EircodeGeocodingService {
  /// Routing key exceptions and standard Irish Eircode pattern.
  static final RegExp _eircodePattern = RegExp(
    r'^(?:[AC-FHKNPRTV-Y][0-9]{2}|D6W)\s?[0-9AC-FHKNPRTV-Y]{4}$',
    caseSensitive: false,
  );

  static String normalize(String raw) {
    final compact = raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (compact.length < 7) return compact;
    return '${compact.substring(0, 3)} ${compact.substring(3)}';
  }

  static bool isValidFormat(String raw) {
    final normalized = normalize(raw).replaceAll(' ', '');
    if (normalized.length != 7) return false;
    return _eircodePattern.hasMatch(normalized);
  }

  /// Resolves an Eircode to WGS-84 coordinates via forward geocoding.
  static Future<({double latitude, double longitude})> resolveCoordinates(
    String eircode, {
    Future<List<Location>> Function(String query)? geocode,
  }) async {
    final normalized = normalize(eircode);
    if (!isValidFormat(normalized)) {
      throw EircodeValidationException(
        'Enter a valid Irish Eircode (e.g. D02 X285).',
      );
    }

    final query = '$normalized, Ireland';
    final locations = geocode != null
        ? await geocode(query)
        : await locationFromAddress(query);

    if (locations.isEmpty) {
      throw EircodeValidationException(
        'We could not locate that Eircode. Check it and try again.',
      );
    }

    final first = locations.first;
    final lat = first.latitude;
    final lng = first.longitude;
    if (!lat.isFinite || !lng.isFinite || (lat == 0 && lng == 0)) {
      throw EircodeValidationException(
        'Eircode resolution returned invalid coordinates.',
      );
    }

    return (latitude: lat, longitude: lng);
  }
}

class EircodeValidationException implements Exception {
  EircodeValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}
