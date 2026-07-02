import '../models/irish_address_suggestion.dart';
import '../models/listing_creation_field_keys.dart';

/// Coarsens coordinates and strips door numbers for public marketplace feeds.
abstract final class AddressPrivacy {
  static const hideExactAddressKey = 'hide_exact_address';
  static const publicLocationKey = 'public_location';
  static const exactEircodeKey = 'exact_eircode';
  static const exactLatitudeKey = 'exact_latitude';
  static const exactLongitudeKey = 'exact_longitude';

  /// ~1.1 km grid — suitable for neighborhood-level discovery maps.
  static double coarsenCoordinate(double value) =>
      (value * 100).roundToDouble() / 100;

  static String stripDoorNumber(String streetLine) {
    final trimmed = streetLine.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .replaceFirst(RegExp(r'^\d+[a-zA-Z]?[\s,/\-]+'), '')
        .trim();
  }

  static String publicLocationFrom({
    required String area,
    required String county,
    String? streetLine,
    bool hideExact = true,
  }) {
    if (!hideExact && streetLine != null && streetLine.trim().isNotEmpty) {
      return '$streetLine, $area, $county';
    }
    return '$area, $county';
  }

  static Map<String, dynamic> applyToPayload({
    required Map<String, dynamic> payload,
    required bool hideExactAddress,
    IrishAddressSuggestion? selected,
    String? area,
    String? county,
    String? streetLine,
    double? exactLat,
    double? exactLon,
    String? exactEircode,
  }) {
    if (!hideExactAddress) {
      payload[hideExactAddressKey] = false;
      return payload;
    }

    final resolvedArea = area ?? selected?.area ?? '';
    final resolvedCounty = county ?? selected?.county ?? 'Dublin';
    final resolvedStreet = streetLine ?? selected?.streetLine ?? '';
    final lat = exactLat ?? selected?.latitude;
    final lon = exactLon ?? selected?.longitude;
    final eircode = exactEircode ?? selected?.eircode;

    final publicLabel = publicLocationFrom(
      area: resolvedArea,
      county: resolvedCounty,
      streetLine: resolvedStreet,
      hideExact: true,
    );

    payload[hideExactAddressKey] = true;
    payload[publicLocationKey] = publicLabel;
    payload['location'] = publicLabel;

    if (lat != null && lon != null) {
      payload[exactLatitudeKey] = lat;
      payload[exactLongitudeKey] = lon;
      payload['latitude'] = coarsenCoordinate(lat);
      payload['longitude'] = coarsenCoordinate(lon);
    }

    if (eircode != null && eircode.isNotEmpty) {
      payload[exactEircodeKey] = eircode;
      payload.remove('eircode');
      payload.remove(ListingCreationFieldKeys.eircode);
    }

    return payload;
  }
}
