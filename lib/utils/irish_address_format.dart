import '../services/eircode_geocoding_service.dart';

/// Formats Irish addresses for listing display (Eircode Finder / Daft style).
abstract final class IrishAddressFormat {
  /// `[Street Line], [Neighbourhood/Area], [County Zone], [Eircode]`
  /// e.g. `9 Hollywoodrath Park, Hollystown, Dublin 15, D15 FT9N`
  static String formatFull({
    required Map<String, String> fields,
    required String eircode,
  }) {
    final normalized = EircodeGeocodingService.normalize(eircode);
    final parts = <String>[];

    final streetLine = _streetLine(fields);
    if (streetLine.isNotEmpty) parts.add(streetLine);

    final area = formatPublicArea(fields);
    if (area != null && area.isNotEmpty) {
      parts.add(area);
    } else {
      final suburb = fields['suburb']?.trim() ?? '';
      final neighbourhood = fields['neighbourhood']?.trim() ?? '';
      final cityDistrict = fields['city_district']?.trim() ?? '';
      if (suburb.isNotEmpty) {
        parts.add(suburb);
      } else if (neighbourhood.isNotEmpty) {
        parts.add(neighbourhood);
      } else if (cityDistrict.isNotEmpty) {
        parts.add(cityDistrict);
      }
    }

    final countyZone = countyZoneLabel(fields, eircode: normalized);
    if (countyZone.isNotEmpty) parts.add(countyZone);

    parts.add(normalized);
    return parts.join(', ');
  }

  static String? formatPublicArea(Map<String, String> fields) {
    final neighbourhood = fields['neighbourhood']?.trim() ?? '';
    final suburb = fields['suburb']?.trim() ?? '';
    final cityDistrict = fields['city_district']?.trim() ?? '';

    final segments = <String>[];
    if (neighbourhood.isNotEmpty) segments.add(neighbourhood);
    if (suburb.isNotEmpty && suburb != neighbourhood) segments.add(suburb);
    if (segments.isEmpty && cityDistrict.isNotEmpty) segments.add(cityDistrict);
    if (segments.isEmpty) return null;
    return segments.join(', ');
  }

  static String countyZoneLabel(
    Map<String, String> fields, {
    String? eircode,
  }) {
    for (final key in ['city_district', 'city', 'county', 'state']) {
      final raw = fields[key]?.trim() ?? '';
      final match = RegExp(
        r'Dublin\s*\d{1,2}W?',
        caseSensitive: false,
      ).firstMatch(raw);
      if (match != null) return _titleCaseDublinDistrict(match.group(0)!);
    }

    if (eircode != null) {
      final routing = EircodeGeocodingService.routingKey(eircode);
      final resultPostcode = fields['postcode']?.trim() ?? '';
      if (resultPostcode.isNotEmpty &&
          EircodeGeocodingService.isValidFormat(resultPostcode) &&
          !EircodeGeocodingService.sameEircode(resultPostcode, eircode)) {
        // Do not override with the searched Eircode's district when the geocoder
        // returned a different postcode (e.g. D02 coords for a D15 query).
        final fromResult = countyZoneLabel(
          fields,
          eircode: EircodeGeocodingService.normalize(resultPostcode),
        );
        if (fromResult.isNotEmpty) return fromResult;
      }
      if (routing != null && routing.toUpperCase().startsWith('D')) {
        if (routing.toUpperCase() == 'D6W') return 'Dublin 6W';
        final digits = routing.substring(1);
        final parsed = int.tryParse(digits);
        if (parsed != null) return 'Dublin $parsed';
      }
    }

    final city = fields['city']?.trim() ?? '';
    if (city.isNotEmpty) return city;
    return fields['county']?.trim() ?? 'Dublin';
  }

  static String _streetLine(Map<String, String> fields) {
    final houseNumber = fields['house_number']?.trim() ?? '';
    final road = fields['road']?.trim() ?? '';
    if (road.isEmpty) return '';
    return houseNumber.isNotEmpty ? '$houseNumber $road' : road;
  }

  /// Daft-style label from Google `formatted_address` (drops trailing Ireland).
  static String fromGoogleFormatted(String formatted, {String? eircode}) {
    var label = formatted.trim();
    if (label.endsWith(', Ireland')) {
      label = label.substring(0, label.length - ', Ireland'.length).trim();
    }
    if (eircode != null && eircode.isNotEmpty) {
      final normalized = EircodeGeocodingService.normalize(eircode);
      final compact = normalized.replaceAll(' ', '');
      label = label.replaceAll(
        RegExp(compact, caseSensitive: false),
        normalized,
      );
    }
    return label;
  }

  static bool hasStreetLine(Map<String, String> fields) =>
      _streetLine(fields).isNotEmpty;

  /// True when the first segment looks like a door number + street (Daft-style).
  static bool isBuildingLevelLabel(String label) {
    final first = label.split(',').first.trim();
    if (RegExp(r'^\d+[A-Za-z]?\s').hasMatch(first)) return true;
    return RegExp(
      r'\b(Park|Road|Street|Avenue|Drive|Lane|Court|Green|Close|Way|Grove|Place|Terrace|Rise|View)\b',
      caseSensitive: false,
    ).hasMatch(first);
  }

  static String _titleCaseDublinDistrict(String raw) {
    final match = RegExp(
      r'dublin\s*(\d{1,2})(w)?',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (match == null) return raw;
    final west = (match.group(2) ?? '').toUpperCase();
    return west == 'W' ? 'Dublin ${match.group(1)}W' : 'Dublin ${match.group(1)}';
  }
}
