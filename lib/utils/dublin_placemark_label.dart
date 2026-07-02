import 'package:geocoding/geocoding.dart';

import '../config/market/dublin_districts.dart';
import '../services/eircode_geocoding_service.dart';
import '../services/nominatim_reverse.dart';

/// Reverse-geocoded Dublin area label plus optional Eircode from the same lookup.
class DublinLocationLookup {
  const DublinLocationLookup({required this.label, this.eircode});

  final String label;
  final String? eircode;
}

/// Builds a human-readable Dublin area label from reverse-geocoding placemarks.
abstract final class DublinPlacemarkLabel {
  /// Single reverse-geocode pass — returns area label and Eircode together.
  static Future<DublinLocationLookup> lookup(double lat, double lon) async {
    // GPS geofence is the most reliable district signal on web (geocoders often
    // return a generic/wrong routing key like D08 for all of Dublin).
    final coordDistrict = dublinDistrictLabelFromCoordinates(lat, lon);

    Placemark? placemark;
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        placemark = placemarks.first;
      }
    } catch (_) {
      // Geocoding plugin may fail on web; fall through to Nominatim.
    }

    var eircode = placemark == null
        ? null
        : _extractEircodeFromRaw(placemark.postalCode);

    final nominatim = await NominatimReverse.lookup(lat, lon);
    if (nominatim != null) {
      eircode ??= _extractEircodeFromNominatim(nominatim);
    }

    if (coordDistrict != null) {
      if (eircode != null &&
          !EircodeGeocodingService.matchesDistrict(eircode, coordDistrict)) {
        eircode = null;
      }
      return DublinLocationLookup(label: coordDistrict, eircode: eircode);
    }

    final placemarkCandidates =
        placemark == null ? const <String>[] : _placemarkCandidates(placemark);
    final fromPlacemark = _resolveFromCandidates(placemarkCandidates);
    if (fromPlacemark != null && fromPlacemark != _genericFallback) {
      if (eircode != null &&
          !EircodeGeocodingService.matchesDistrict(eircode, fromPlacemark)) {
        eircode = null;
      }
      return DublinLocationLookup(label: fromPlacemark, eircode: eircode);
    }

    if (nominatim != null) {
      final nominatimCandidates = nominatim.entries
          .where((entry) => entry.key != 'display_name')
          .map((entry) => _clean(entry.value))
          .toList();
      final fromNominatim = _resolveFromCandidates(nominatimCandidates);
      if (fromNominatim != null && fromNominatim != _genericFallback) {
        if (eircode != null &&
            !EircodeGeocodingService.matchesDistrict(eircode, fromNominatim)) {
          eircode = null;
        }
        return DublinLocationLookup(label: fromNominatim, eircode: eircode);
      }
    }

    return DublinLocationLookup(label: _genericFallback, eircode: eircode);
  }

  static Future<String> resolve(double lat, double lon) async {
    final result = await lookup(lat, lon);
    return result.label;
  }

  static String fromPlacemark(Placemark placemark) =>
      _resolveFromCandidates(_placemarkCandidates(placemark)) ?? _genericFallback;

  /// Returns the best available postal code (Eircode or routing key) for the
  /// given coordinates.  Tries the native geocoder first, then Nominatim.
  /// Returns `null` when nothing useful is found.
  static Future<String?> extractPostalCode(double lat, double lon) async {
    final result = await lookup(lat, lon);
    return result.eircode;
  }

  static String? _extractEircodeFromRaw(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final compact = raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (EircodeGeocodingService.isValidFormat(compact)) {
      return EircodeGeocodingService.normalize(compact);
    }
    final match = RegExp(
      r'(?:[AC-FHKNPRTV-Y][0-9]{2}|D6W)[0-9AC-FHKNPRTV-Y]{4}',
      caseSensitive: false,
    ).firstMatch(compact);
    if (match == null) return null;
    final candidate = match.group(0)!;
    if (!EircodeGeocodingService.isValidFormat(candidate)) return null;
    return EircodeGeocodingService.normalize(candidate);
  }

  static String? _extractEircodeFromNominatim(Map<String, String> nominatim) {
    final direct = _extractEircodeFromRaw(nominatim['postcode']);
    if (direct != null) return direct;
    for (final value in nominatim.values) {
      final found = _extractEircodeFromRaw(value);
      if (found != null) return found;
    }
    return null;
  }

  static List<String> _placemarkCandidates(Placemark placemark) => [
        _clean(placemark.subLocality),
        _clean(placemark.postalCode),
        _clean(placemark.subAdministrativeArea),
        _clean(placemark.thoroughfare),
        _clean(placemark.name),
        _clean(placemark.locality),
        _clean(placemark.administrativeArea),
      ];

  static String? _resolveFromCandidates(List<String> rawCandidates) {
    final candidates = rawCandidates
        .map(_clean)
        .where((value) => value.isNotEmpty)
        .toList();

    for (final candidate in candidates) {
      final district =
          _districtFromPostalCode(candidate) ?? _districtFromAlias(candidate);
      if (district != null) return district;
    }

    for (final candidate in candidates) {
      final numbered = _districtFromName(candidate);
      if (numbered != null) return numbered;
    }

    for (final candidate in candidates) {
      if (_isGenericDublin(candidate) || _isAdministrativeNoise(candidate)) {
        continue;
      }
      final alias = _districtFromAlias(candidate);
      if (alias != null) return alias;
      return _withDublinSuffix(candidate);
    }

    return null;
  }

  static String? _districtFromAlias(String raw) {
    if (raw.isEmpty || _isAdministrativeNoise(raw)) return null;
    final lower = raw.toLowerCase();
    for (final entry in dublinCityAliases.entries) {
      for (final alias in entry.value) {
        if (alias.length < 3) continue;
        if (lower.contains(alias) || alias.contains(lower)) {
          return dublinCityDisplayNames[entry.key];
        }
      }
    }
    return null;
  }

  static String? _districtFromPostalCode(String postalCode) {
    if (postalCode.isEmpty) return null;
    final match =
        RegExp(r'^D(\d{1,2})', caseSensitive: false).firstMatch(postalCode);
    if (match == null) return null;
    return 'Dublin ${match.group(1)}';
  }

  static String? _districtFromName(String raw) {
    if (raw.isEmpty || _isGenericDublin(raw) || _isAdministrativeNoise(raw)) {
      return null;
    }
    final numbered = RegExp(
      r'dublin[\s_-]?(\d{1,2}[w]?)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (numbered != null) {
      return 'Dublin ${numbered.group(1)!.toUpperCase()}';
    }
    return null;
  }

  static String _withDublinSuffix(String area) {
    final lower = area.toLowerCase();
    if (RegExp(r'dublin\s+\d', caseSensitive: false).hasMatch(lower)) {
      return area;
    }
    if (lower.contains('dublin')) return area;
    return '$area, Dublin';
  }

  static bool _isAdministrativeNoise(String value) {
    final lower = value.toLowerCase();
    if (RegExp(r'\bded\b').hasMatch(lower)) return true;
    if (RegExp(r'\belectoral\b').hasMatch(lower)) return true;
    if (RegExp(r'\bdivision\b').hasMatch(lower) &&
        RegExp(r'\d').hasMatch(lower)) {
      return true;
    }
    if (RegExp(r'\bward\b').hasMatch(lower) && RegExp(r'\d').hasMatch(lower)) {
      return true;
    }
    if (RegExp(r'\bed\b').hasMatch(lower) && RegExp(r'\b\d{4}\b').hasMatch(lower)) {
      return true;
    }
    return false;
  }

  static bool _isGenericDublin(String value) {
    final lower = value.toLowerCase();
    return lower == 'dublin' ||
        lower == 'ireland' ||
        lower == 'county dublin' ||
        lower == 'co. dublin';
  }

  static String _clean(String? value) => value?.trim() ?? '';

  static const _genericFallback = 'Dublin, Ireland';
}
