import 'package:flutter/foundation.dart';

import '../config/market/dublin_districts.dart';
import '../services/eircode_geocoding_service.dart';
import 'city_area_match.dart';

/// Resolves the canonical listing area key for property-area matching.
///
/// Valid Dublin Eircode routing keys take precedence over coordinate boxes.
/// Coordinates are used only when the Eircode is absent or not mappable.
String? resolveListingAreaKey({
  String eircode = '',
  double? lat,
  double? lon,
  String? areaLabel,
  void Function(String message)? onDistrictMismatch,
}) {
  final trimmedEircode = eircode.trim();
  if (EircodeGeocodingService.isValidFormat(trimmedEircode)) {
    final fromEircode = listingAreaKeyFromEircode(trimmedEircode);
    if (fromEircode != null) {
      if (lat != null && lon != null) {
        _logDistrictMismatchIfNeeded(
          eircode: trimmedEircode,
          eircodeKey: fromEircode,
          lat: lat,
          lon: lon,
          onDistrictMismatch: onDistrictMismatch,
        );
      }
      return fromEircode;
    }
  }

  if (lat != null && lon != null) {
    final district = dublinDistrictLabelFromCoordinates(lat, lon);
    if (district != null) {
      return CityAreaMatch.profileAreaKey(district);
    }
  }

  if (areaLabel != null && areaLabel.isNotEmpty) {
    return CityAreaMatch.profileAreaKey(areaLabel);
  }

  return null;
}

/// Maps a valid Dublin Eircode routing key (e.g. D03) to a profile area key.
String? listingAreaKeyFromEircode(String eircode) {
  final routing = EircodeGeocodingService.routingKey(eircode);
  if (routing == null) return null;
  if (routing == 'D6W') {
    return CityAreaMatch.profileAreaKey('Dublin 6W');
  }
  final match = RegExp(r'^D(\d{2})$').firstMatch(routing);
  if (match == null) return null;
  final number = int.tryParse(match.group(1)!);
  if (number == null) return null;
  return CityAreaMatch.profileAreaKey('Dublin $number');
}

void _logDistrictMismatchIfNeeded({
  required String eircode,
  required String eircodeKey,
  required double lat,
  required double lon,
  void Function(String message)? onDistrictMismatch,
}) {
  final coordDistrict = dublinDistrictLabelFromCoordinates(lat, lon);
  if (coordDistrict == null) return;

  final coordKey = CityAreaMatch.profileAreaKey(coordDistrict);
  if (coordKey == null || coordKey == eircodeKey) return;

  final message =
      'Listing area mismatch at ($lat, $lon): eircode '
      '${EircodeGeocodingService.normalize(eircode)} -> $eircodeKey; '
      'coordinates -> $coordDistrict ($coordKey). Using eircode district.';
  onDistrictMismatch?.call(message);
  debugPrint(message);
}
