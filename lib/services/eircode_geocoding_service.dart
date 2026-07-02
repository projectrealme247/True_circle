import 'package:geocoding/geocoding.dart';

import '../config/market/dublin_districts.dart';

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

  /// Three-character Eircode routing key (e.g. D15, D01, D6W).
  static String? routingKey(String raw) {
    final compact = normalize(raw).replaceAll(' ', '').toUpperCase();
    if (compact.length < 3) return null;
    if (compact.startsWith('D6W')) return 'D6W';
    if (RegExp(r'^D\d{2}').hasMatch(compact)) {
      return compact.substring(0, 3);
    }
    return compact.substring(0, 3);
  }

  /// Expected routing key from a Dublin district label like "Dublin 15 (...)".
  static String? expectedRoutingKeyForDistrict(String districtLabel) {
    final match = RegExp(
      r'Dublin\s+(\d{1,2})(W)?',
      caseSensitive: false,
    ).firstMatch(districtLabel.trim());
    if (match == null) return null;
    final number = match.group(1)!;
    final west = match.group(2)?.toUpperCase() ?? '';
    if (west == 'W' && number == '6') return 'D6W';
    return 'D${number.padLeft(2, '0')}';
  }

  /// True when [eircode]'s routing key matches the Dublin district in [districtLabel].
  static bool matchesDistrict(String eircode, String districtLabel) {
    final expected = expectedRoutingKeyForDistrict(districtLabel);
    final actual = routingKey(eircode);
    if (expected == null || actual == null) return false;
    return expected == actual;
  }

  /// True when two Eircodes are the same after normalisation.
  static bool sameEircode(String a, String b) {
    final left = normalize(a).replaceAll(' ', '');
    final right = normalize(b).replaceAll(' ', '');
    return left.isNotEmpty && left == right;
  }

  /// True when [lat]/[lon] fall inside the Dublin district implied by [eircode].
  /// Returns false for coordinates clearly outside Dublin.
  static bool coordinatesMatchDistrict(
    double lat,
    double lon,
    String eircode,
  ) {
    final district = dublinDistrictLabelFromCoordinates(lat, lon);
    if (district == null) {
      // If coordinates are outside all Dublin district polygons,
      // only accept if they are at least within a generous Dublin metro box.
      return _isWithinDublinMetro(lat, lon);
    }
    return matchesDistrict(eircode, district);
  }

  static bool _isWithinDublinMetro(double lat, double lon) {
    return lat >= 53.20 && lat <= 53.50 && lon >= -6.55 && lon <= -6.00;
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
