import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'eircode_geocoding_service.dart';
import 'nominatim_forward.dart';

Future<Map<String, dynamic>?> searchEircode(String eircode) async {
  final compact = eircode.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  if (compact.length != 7) return null;

  final spaced =
      '${compact.substring(0, 3)} ${compact.substring(3)}';

  // Postalcode index first, then free-text — but only accept exact Eircode matches.
  for (final params in [
    {
      'postalcode': compact,
      'countrycodes': 'ie',
      'format': 'json',
      'addressdetails': '1',
      'limit': '10',
    },
    {
      'postalcode': spaced,
      'countrycodes': 'ie',
      'format': 'json',
      'addressdetails': '1',
      'limit': '10',
    },
    {
      'q': '$spaced, Ireland',
      'countrycodes': 'ie',
      'format': 'json',
      'addressdetails': '1',
      'limit': '10',
    },
  ]) {
    final result = await _nominatimGet(params, expectedEircode: spaced);
    if (result != null) return result;
  }
  return null;
}

/// Pin lookup for proximity — accepts routing-key matches when exact postcode is missing.
/// Rejects any result outside the Dublin metro bounding box.
Future<Map<String, dynamic>?> searchEircodePin(String eircode) async {
  final exact = await searchEircode(eircode);
  if (exact != null) return exact;

  final compact = eircode.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  if (compact.length != 7) return null;

  // Only try this relaxed search for Dublin Eircodes (routing key D**)
  if (!compact.startsWith('D')) return null;

  final spaced =
      '${compact.substring(0, 3)} ${compact.substring(3)}';

  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': '$spaced, Ireland',
      'countrycodes': 'ie',
      'format': 'json',
      'addressdetails': '1',
      'limit': '8',
    });
    final completer = Completer<Map<String, dynamic>?>();
    final xhr = web.XMLHttpRequest();
    xhr.open('GET', uri.toString());
    xhr.setRequestHeader('Accept', 'application/json');
    xhr.setRequestHeader('User-Agent', 'TrueCircle/1.0 (listing-eircode-pin)');
    xhr.onload = ((web.Event _) {
      try {
        if (xhr.status < 200 || xhr.status >= 300) {
          completer.complete(null);
          return;
        }
        final decoded = jsonDecode(xhr.responseText);
        if (decoded is! List || decoded.isEmpty) {
          completer.complete(null);
          return;
        }
        for (final item in decoded) {
          if (item is! Map) continue;
          final parsed = _parseNominatimItem(item);
          if (parsed == null) continue;
          final lat = parsed['lat'] as double;
          final lon = parsed['lon'] as double;
          if (!EircodeGeocodingService.coordinatesMatchDistrict(
            lat,
            lon,
            spaced,
          )) {
            continue;
          }
          completer.complete(parsed);
          return;
        }
        completer.complete(null);
      } catch (_) {
        completer.complete(null);
      }
    }).toJS;
    xhr.onerror = ((web.Event _) => completer.complete(null)).toJS;
    xhr.send();
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>?> _nominatimGet(
  Map<String, String> params, {
  required String expectedEircode,
}) async {
  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
    final completer = Completer<Map<String, dynamic>?>();
    final xhr = web.XMLHttpRequest();
    xhr.open('GET', uri.toString());
    xhr.setRequestHeader('Accept', 'application/json');
    xhr.setRequestHeader('User-Agent', 'TrueCircle/1.0 (listing-eircode-search)');
    xhr.onload = ((web.Event _) {
      try {
        if (xhr.status < 200 || xhr.status >= 300) {
          completer.complete(null);
          return;
        }
        final decoded = jsonDecode(xhr.responseText);
        if (decoded is! List || decoded.isEmpty) {
          completer.complete(null);
          return;
        }
        for (final item in decoded) {
          if (item is! Map) continue;
          final parsed = _parseNominatimItem(item);
          if (parsed == null) continue;
          if (!_matchesExpectedEircode(parsed, expectedEircode)) continue;
          if (!EircodeGeocodingService.coordinatesMatchDistrict(
            parsed['lat'] as double,
            parsed['lon'] as double,
            expectedEircode,
          )) {
            continue;
          }
          completer.complete(parsed);
          return;
        }
        completer.complete(null);
      } catch (_) {
        completer.complete(null);
      }
    }).toJS;
    xhr.onerror = ((web.Event _) => completer.complete(null)).toJS;
    xhr.send();
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _parseNominatimItem(Map item) {
  final address = item['address'];
  final lat = double.tryParse(item['lat']?.toString() ?? '');
  final lon = double.tryParse(item['lon']?.toString() ?? '');
  if (lat == null || lon == null || address is! Map) return null;

  final result = <String, dynamic>{
    'lat': lat,
    'lon': lon,
    'display_name': item['display_name']?.toString() ?? '',
  };
  for (final key in [
    'house_number',
    'road',
    'neighbourhood',
    'suburb',
    'city_district',
    'city',
    'county',
    'postcode',
    'state',
    'country',
  ]) {
    final v = address[key];
    if (v != null) result[key] = v.toString();
  }
  return result;
}

bool _matchesExpectedEircode(Map<String, dynamic> data, String expectedEircode) {
  final postcode = data['postcode']?.toString() ?? '';
  if (postcode.isNotEmpty &&
      EircodeGeocodingService.sameEircode(postcode, expectedEircode)) {
    return true;
  }
  final displayName = data['display_name']?.toString() ?? '';
  final compactExpected =
      expectedEircode.replaceAll(' ', '').toUpperCase();
  return displayName.toUpperCase().replaceAll(' ', '').contains(compactExpected);
}

/// Dublin metro bounding box — format is west,north,east,south (lon,lat,lon,lat).
/// Used as a preference boost only (no bounded=1) so edge-of-metro addresses
/// are still found. Hard filtering is done by [_isWithinDublinMetro].
const _dublinMetroViewbox = '-6.55,53.50,-6.00,53.20';

/// Search for an Irish street address using Nominatim free-text search.
/// Returns up to 5 results within the Dublin metro area with clean labels.
Future<List<NominatimAddressResult>> searchAddress(String query) async {
  try {
    final completer = Completer<List<NominatimAddressResult>>();
    final encoded = Uri.encodeComponent('$query, Ireland');
    final url =
        'https://nominatim.openstreetmap.org/search'
        '?q=$encoded'
        '&format=json&addressdetails=1&limit=8'
        '&countrycodes=ie'
        '&viewbox=$_dublinMetroViewbox';

    final xhr = web.XMLHttpRequest();
    xhr.open('GET', url);
    xhr.setRequestHeader('Accept', 'application/json');
    xhr.onload = ((web.Event _) {
      try {
        if (xhr.status < 200 || xhr.status >= 300) {
          completer.complete(const []);
          return;
        }
        final decoded = jsonDecode(xhr.responseText);
        if (decoded is! List || decoded.isEmpty) {
          completer.complete(const []);
          return;
        }
        final results = <NominatimAddressResult>[];
        for (final item in decoded) {
          if (item is! Map) continue;
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          if (lat == null || lon == null) continue;
          if (!_isWithinDublinMetro(lat, lon)) continue;

          final address = item['address'];

          String houseNumber = '';
          String road = '';
          String suburb = '';
          String neighbourhood = '';
          String quarter = '';
          String cityDistrict = '';
          String city = '';
          String postcode = '';
          String county = 'Dublin';

          if (address is Map) {
            houseNumber = address['house_number']?.toString() ?? '';
            road = address['road']?.toString() ?? '';
            suburb = address['suburb']?.toString() ?? '';
            neighbourhood = address['neighbourhood']?.toString() ?? '';
            quarter = address['quarter']?.toString() ?? '';
            cityDistrict = address['city_district']?.toString() ?? '';
            city = address['city']?.toString() ?? '';
            postcode = address['postcode']?.toString() ?? '';
            final countyRaw = address['county']?.toString() ?? '';
            if (countyRaw.isNotEmpty) county = countyRaw;
          }

          final streetLine = houseNumber.isNotEmpty && road.isNotEmpty
              ? '$houseNumber $road'
              : road;

          final localArea = suburb.isNotEmpty
              ? suburb
              : neighbourhood.isNotEmpty
                  ? neighbourhood
                  : quarter;

          final district = cityDistrict.isNotEmpty ? cityDistrict : city;

          final label = _buildAddressLabel(
            streetLine: streetLine,
            localArea: localArea,
            district: district,
            postcode: postcode,
          );

          results.add(NominatimAddressResult(
            displayLabel: label.isNotEmpty ? label : streetLine,
            lat: lat,
            lon: lon,
            streetLine: streetLine.isNotEmpty ? streetLine : label,
            area: localArea.isNotEmpty ? localArea : district,
            county: county,
          ));
          if (results.length >= 5) break;
        }
        completer.complete(results);
      } catch (_) {
        completer.complete(const []);
      }
    }).toJS;
    xhr.onerror = ((web.Event _) => completer.complete(const [])).toJS;
    xhr.send();
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => const [],
    );
  } catch (_) {
    return const [];
  }
}

bool _isWithinDublinMetro(double lat, double lon) {
  return lat >= 53.18 && lat <= 53.55 && lon >= -6.60 && lon <= -5.95;
}

/// Reverse geocode coordinates to a readable address via Nominatim.
Future<String?> reverseGeocode(double lat, double lon) async {
  try {
    final completer = Completer<String?>();
    final url =
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lon&format=json&addressdetails=1&zoom=18';

    final xhr = web.XMLHttpRequest();
    xhr.open('GET', url);
    xhr.setRequestHeader('Accept', 'application/json');
    xhr.setRequestHeader('User-Agent', 'TrueCircle/1.0 (reverse-geocode)');
    xhr.onload = ((web.Event _) {
      try {
        if (xhr.status < 200 || xhr.status >= 300) {
          completer.complete(null);
          return;
        }
        final decoded = jsonDecode(xhr.responseText);
        if (decoded is! Map) {
          completer.complete(null);
          return;
        }
        final address = decoded['address'];
        if (address is! Map) {
          completer.complete(decoded['display_name']?.toString());
          return;
        }

        final houseNumber = address['house_number']?.toString() ?? '';
        final road = address['road']?.toString() ?? '';
        final suburb = address['suburb']?.toString() ?? '';
        final neighbourhood = address['neighbourhood']?.toString() ?? '';
        final cityDistrict = address['city_district']?.toString() ?? '';
        final city = address['city']?.toString() ?? '';
        final postcode = address['postcode']?.toString() ?? '';

        final streetLine = houseNumber.isNotEmpty && road.isNotEmpty
            ? '$houseNumber $road'
            : road;
        final localArea = suburb.isNotEmpty ? suburb : neighbourhood;
        final district = cityDistrict.isNotEmpty ? cityDistrict : city;

        final label = _buildAddressLabel(
          streetLine: streetLine,
          localArea: localArea,
          district: district,
          postcode: postcode,
        );
        completer.complete(label.isNotEmpty ? label : null);
      } catch (_) {
        completer.complete(null);
      }
    }).toJS;
    xhr.onerror = ((web.Event _) => completer.complete(null)).toJS;
    xhr.send();
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
  } catch (_) {
    return null;
  }
}

/// Builds a clean human-readable address label from structured Nominatim fields.
/// e.g. "9 Hollywoodrath Park, Hollywoodrath, Dublin 15, D15 FT9N"
String _buildAddressLabel({
  required String streetLine,
  required String localArea,
  required String district,
  required String postcode,
}) {
  final parts = <String>[];
  if (streetLine.isNotEmpty && !_isNoisyPart(streetLine)) {
    parts.add(streetLine);
  }
  if (localArea.isNotEmpty && !_isNoisyPart(localArea)) {
    parts.add(localArea);
  }
  if (district.isNotEmpty &&
      !_isNoisyPart(district) &&
      !parts.any((p) => p.toLowerCase().contains(district.toLowerCase()))) {
    parts.add(district);
  }
  if (postcode.isNotEmpty) parts.add(postcode);
  return parts.join(', ');
}

/// Filters out noisy Nominatim administrative labels like "The Ward DED 1986",
/// "Clonsilla ED", "Dublin City" duplicates, and similar electoral division cruft.
bool _isNoisyPart(String part) {
  final lower = part.toLowerCase().trim();
  if (RegExp(r'\bded\b', caseSensitive: false).hasMatch(lower)) return true;
  if (RegExp(r'\bed\b', caseSensitive: false).hasMatch(lower) &&
      RegExp(r'\d').hasMatch(lower)) {
    return true;
  }
  if (lower.contains('the ward')) return true;
  if (lower.contains('civil parish')) return true;
  if (lower.contains('electoral division')) return true;
  return false;
}
