import 'package:geocoding/geocoding.dart';

import '../models/irish_address_suggestion.dart';
import '../services/eircode_geocoding_service.dart';

/// Forward-geocoding autocomplete for Irish addresses and Eircodes.
abstract final class IrishAddressLookupService {
  static const _maxResults = 6;
  static const _minQueryLength = 3;

  static Future<List<IrishAddressSuggestion>> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < _minQueryLength) return const [];

    final compact = query.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (EircodeGeocodingService.isValidFormat(compact)) {
      try {
        final normalized = EircodeGeocodingService.normalize(compact);
        final coords =
            await EircodeGeocodingService.resolveCoordinates(normalized);
        final placemarks =
            await placemarkFromCoordinates(coords.latitude, coords.longitude);
        final suggestion = _fromPlacemark(
          placemarks.isNotEmpty ? placemarks.first : null,
          coords.latitude,
          coords.longitude,
          fallbackQuery: normalized,
        );
        if (suggestion != null) {
          return [
            IrishAddressSuggestion(
              displayLabel: normalized,
              streetLine: suggestion.streetLine,
              area: suggestion.area,
              county: suggestion.county,
              eircode: normalized,
              latitude: coords.latitude,
              longitude: coords.longitude,
            ),
          ];
        }
      } catch (_) {
        // Fall through to forward-geocode search.
      }
    }

    final queries = <String>{
      '$query, Ireland',
      if (!query.toLowerCase().contains('dublin')) '$query, Dublin, Ireland',
    };

    if (EircodeGeocodingService.isValidFormat(compact)) {
      queries.add('${EircodeGeocodingService.normalize(compact)}, Ireland');
    }

    final seen = <String>{};
    final results = <IrishAddressSuggestion>[];

    for (final q in queries) {
      if (results.length >= _maxResults) break;
      try {
        final locations = await locationFromAddress(q);
        for (final loc in locations) {
          if (results.length >= _maxResults) break;
          if (!loc.latitude.isFinite || !loc.longitude.isFinite) continue;
          if (!_isWithinDublinMetro(loc.latitude, loc.longitude)) continue;

          Placemark? placemark;
          try {
            final placemarks =
                await placemarkFromCoordinates(loc.latitude, loc.longitude);
            if (placemarks.isNotEmpty) placemark = placemarks.first;
          } catch (_) {
            placemark = null;
          }

          final suggestion = _fromPlacemark(
            placemark,
            loc.latitude,
            loc.longitude,
            fallbackQuery: query,
          );
          if (suggestion == null) continue;
          if (seen.add(suggestion.displayLabel)) {
            results.add(suggestion);
          }
        }
      } catch (_) {
        continue;
      }
    }

    return results;
  }

  static IrishAddressSuggestion? _fromPlacemark(
    Placemark? placemark,
    double lat,
    double lon, {
    required String fallbackQuery,
  }) {
    if (placemark == null) {
      return IrishAddressSuggestion(
        displayLabel: '$fallbackQuery, Ireland',
        streetLine: fallbackQuery,
        area: fallbackQuery,
        county: 'Dublin',
        latitude: lat,
        longitude: lon,
      );
    }

    final streetNumber = _clean(placemark.subThoroughfare);
    final thoroughfare = _clean(placemark.thoroughfare);
    final subLocality = _clean(placemark.subLocality);
    final locality = _clean(placemark.locality);
    final admin = _clean(placemark.administrativeArea);
    final postal = _clean(placemark.postalCode);

    final streetParts = <String>[
      if (streetNumber.isNotEmpty) streetNumber,
      if (thoroughfare.isNotEmpty) thoroughfare,
    ];
    final streetLine = streetParts.join(' ');

    final area = subLocality.isNotEmpty
        ? subLocality
        : (locality.isNotEmpty ? locality : _clean(placemark.name));

    final county = admin.isNotEmpty ? admin : 'Dublin';

    String? eircode;
    if (postal.isNotEmpty && EircodeGeocodingService.isValidFormat(postal)) {
      eircode = EircodeGeocodingService.normalize(postal);
    }

    final labelParts = <String>[
      if (streetLine.isNotEmpty) streetLine,
      if (area.isNotEmpty && area != streetLine) area,
      if (locality.isNotEmpty &&
          locality != area &&
          !locality.toLowerCase().contains('dublin'))
        locality,
      if (county.isNotEmpty) county,
      if (eircode != null) eircode,
    ];

    final displayLabel = labelParts.isNotEmpty
        ? labelParts.join(', ')
        : '$fallbackQuery, Ireland';

    return IrishAddressSuggestion(
      displayLabel: displayLabel,
      streetLine: streetLine.isNotEmpty ? streetLine : fallbackQuery,
      area: area.isNotEmpty ? area : locality,
      county: county,
      eircode: eircode,
      latitude: lat,
      longitude: lon,
    );
  }

  static String _clean(String? value) => value?.trim() ?? '';

  static bool _isWithinDublinMetro(double lat, double lon) {
    return lat >= 53.20 && lat <= 53.50 && lon >= -6.55 && lon <= -6.00;
  }
}
