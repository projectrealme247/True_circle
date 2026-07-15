import '../config/market/dublin_districts.dart';
import '../models/irish_address_suggestion.dart';
import '../utils/dublin_placemark_label.dart';
import '../utils/irish_address_format.dart';
import 'eircode_geocoding_service.dart';
import 'irish_address_lookup_service.dart';
import 'nominatim_forward.dart';
import 'nominatim_reverse.dart';
import 'overpass_eircode_lookup.dart';

/// Resolves a valid Irish Eircode to an [IrishAddressSuggestion].
///
/// Uses free OSM services (Nominatim, Overpass) plus local Dublin district
/// data. Building-level addresses are not auto-resolved — users confirm or
/// edit their display address after Eircode pins the neighbourhood.
abstract final class EircodeLookupService {
  /// Reverse-geocodes GPS coordinates to area + optional Eircode, then
  /// forward-resolves when a postcode is available.
  static Future<IrishAddressSuggestion?> resolveFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    final nominatim = await NominatimReverse.lookup(latitude, longitude);
    if (nominatim != null && nominatim.isNotEmpty) {
      final postcode = _normalizePostalCode(nominatim['postcode']);
      if (postcode != null) {
        final forward = await resolve(postcode);
        if (forward != null) {
          return _withGpsCoordinates(forward, latitude, longitude);
        }
      }

      final fromNominatim = _fromFieldMap(
        nominatim,
        normalized: postcode ?? '',
        lat: latitude,
        lon: longitude,
      );
      if (fromNominatim.displayLabel.trim().isNotEmpty) {
        return _withGpsCoordinates(fromNominatim, latitude, longitude);
      }
    }

    final placemark = await DublinPlacemarkLabel.lookup(latitude, longitude);
    if (placemark.eircode != null) {
      final forward = await resolve(placemark.eircode!);
      if (forward != null) {
        return _withGpsCoordinates(forward, latitude, longitude);
      }
    }

    if (placemark.label.trim().isNotEmpty) {
      final label = IrishAddressFormat.sanitizeCommaSeparatedLabel(
        placemark.eircode != null
            ? '${placemark.label}, ${EircodeGeocodingService.normalize(placemark.eircode!)}'
            : placemark.label,
      );
      return IrishAddressSuggestion(
        displayLabel: label,
        streetLine: label,
        area: placemark.label,
        county: 'Dublin',
        eircode: placemark.eircode,
        latitude: latitude,
        longitude: longitude,
      );
    }

    return null;
  }

  static Future<IrishAddressSuggestion?> resolve(String rawQuery) async {
    final compact = rawQuery.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (!EircodeGeocodingService.isValidFormat(compact)) return null;

    final normalized = EircodeGeocodingService.normalize(compact);

    // 1 & 2. Nominatim forward search and OSM Overpass addr:postcode (parallel).
    final concurrentHits = await Future.wait([
      NominatimForward.searchEircode(compact),
      OverpassEircodeLookup.resolve(normalized),
    ]);
    final forward = concurrentHits[0] as Map<String, dynamic>?;
    final overpass = concurrentHits[1] as OverpassEircodeHit?;

    if (forward != null) {
      final suggestion = _fromNominatimMap(forward, normalized);
      if (suggestion != null && _isConsistent(suggestion, normalized)) {
        return suggestion;
      }
    }

    if (overpass != null) {
      final suggestion = await _fromOverpassHit(overpass, normalized);
      if (suggestion != null && _isConsistent(suggestion, normalized)) {
        return suggestion;
      }
    }

    // 3. Plugin geocoder + Nominatim reverse.
    try {
      final coords = await EircodeGeocodingService.resolveCoordinates(normalized);
      if (!EircodeGeocodingService.coordinatesMatchDistrict(
        coords.latitude,
        coords.longitude,
        normalized,
      )) {
        throw EircodeValidationException(
          'Eircode resolution returned coordinates outside the expected district.',
        );
      }
      final nominatim = await NominatimReverse.lookup(
        coords.latitude,
        coords.longitude,
      );
      if (nominatim != null && nominatim.isNotEmpty) {
        final suggestion = _fromFieldMap(
          nominatim,
          normalized: normalized,
          lat: coords.latitude,
          lon: coords.longitude,
        );
        if (_isConsistent(suggestion, normalized)) return suggestion;
      }
      return _minimalSuggestion(
        normalized: normalized,
        lat: coords.latitude,
        lon: coords.longitude,
      );
    } catch (_) {
      // Fall through.
    }

    // 4. Irish address lookup (placemark-based fallback).
    final results = await IrishAddressLookupService.search(normalized);
    if (results.isNotEmpty) {
      final first = results.first;
      if (_isConsistent(first, normalized)) return first;
    }

    // 5. District centroid — valid Eircodes still get a usable pin + amenities.
    final pinCoords = await resolvePinCoordinates(normalized);
    if (pinCoords != null) {
      final nominatim = await NominatimReverse.lookup(
        pinCoords.lat,
        pinCoords.lon,
      );
      if (nominatim != null && nominatim.isNotEmpty) {
        final suggestion = _fromFieldMap(
          nominatim,
          normalized: normalized,
          lat: pinCoords.lat,
          lon: pinCoords.lon,
        );
        if (_isConsistent(suggestion, normalized)) return suggestion;
      }
      return _minimalSuggestion(
        normalized: normalized,
        lat: pinCoords.lat,
        lon: pinCoords.lon,
      );
    }

    final districtLabel =
        IrishAddressFormat.countyZoneLabel(const {}, eircode: normalized);
    final centroid = dublinDistrictCentroidFromLabel(districtLabel);
    if (centroid != null) {
      return _minimalSuggestion(
        normalized: normalized,
        lat: centroid.lat,
        lon: centroid.lon,
      );
    }

    return null;
  }

  /// Best WGS-84 pin for an Eircode — used for proximity and area-level fallbacks.
  static Future<({double lat, double lon})?> resolvePinCoordinates(
    String rawEircode,
  ) async {
    final normalized = EircodeGeocodingService.normalize(rawEircode);
    if (!EircodeGeocodingService.isValidFormat(normalized)) return null;

    final overpass = await OverpassEircodeLookup.resolve(normalized);
    if (overpass != null) {
      return (lat: overpass.latitude, lon: overpass.longitude);
    }

    final forward = await NominatimForward.searchEircodePin(normalized);
    if (forward != null) {
      final lat = (forward['lat'] as num?)?.toDouble();
      final lon = (forward['lon'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        return (lat: lat, lon: lon);
      }
    }

    try {
      final coords = await EircodeGeocodingService.resolveCoordinates(normalized);
      if (coords.latitude.isFinite &&
          coords.longitude.isFinite &&
          EircodeGeocodingService.coordinatesMatchDistrict(
            coords.latitude,
            coords.longitude,
            normalized,
          )) {
        return (lat: coords.latitude, lon: coords.longitude);
      }
    } catch (_) {
      // Fall through to district centroid.
    }

    final districtLabel =
        IrishAddressFormat.countyZoneLabel(const {}, eircode: normalized);
    final centroid = dublinDistrictCentroidFromLabel(districtLabel);
    if (centroid != null) {
      return (lat: centroid.lat, lon: centroid.lon);
    }

    return null;
  }

  static IrishAddressSuggestion _withGpsCoordinates(
    IrishAddressSuggestion suggestion,
    double latitude,
    double longitude,
  ) {
    return IrishAddressSuggestion(
      displayLabel: suggestion.displayLabel,
      streetLine: suggestion.streetLine,
      area: suggestion.area,
      county: suggestion.county,
      eircode: suggestion.eircode,
      latitude: latitude,
      longitude: longitude,
    );
  }

  static String? _normalizePostalCode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final compact = raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (!EircodeGeocodingService.isValidFormat(compact)) return null;
    return EircodeGeocodingService.normalize(compact);
  }

  static bool _isConsistent(IrishAddressSuggestion suggestion, String normalized) {
    return EircodeGeocodingService.coordinatesMatchDistrict(
      suggestion.latitude,
      suggestion.longitude,
      normalized,
    );
  }

  static Future<IrishAddressSuggestion?> _fromOverpassHit(
    OverpassEircodeHit hit,
    String normalized,
  ) async {
    final nominatim = await NominatimReverse.lookup(hit.latitude, hit.longitude);
    final fields = <String, String>{
      if (hit.houseNumber != null && hit.houseNumber!.isNotEmpty)
        'house_number': hit.houseNumber!,
      if (hit.street != null && hit.street!.isNotEmpty) 'road': hit.street!,
      if (hit.city != null && hit.city!.isNotEmpty) 'suburb': hit.city!,
      if (hit.postcode != null && hit.postcode!.isNotEmpty)
        'postcode': hit.postcode!,
    };
    if (nominatim != null) {
      for (final entry in nominatim.entries) {
        fields.putIfAbsent(entry.key, () => entry.value);
      }
    }
    return _fromFieldMap(
      fields,
      normalized: normalized,
      lat: hit.latitude,
      lon: hit.longitude,
    );
  }

  static IrishAddressSuggestion? _fromNominatimMap(
    Map<String, dynamic> data,
    String normalized,
  ) {
    final lat = (data['lat'] as num?)?.toDouble();
    final lon = (data['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;

    final fields = <String, String>{
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
      ])
        if (data[key] != null) key: data[key].toString(),
    };

    return _fromFieldMap(
      fields,
      normalized: normalized,
      lat: lat,
      lon: lon,
    );
  }

  static IrishAddressSuggestion _fromFieldMap(
    Map<String, String> fields, {
    required String normalized,
    required double lat,
    required double lon,
  }) {
    final resolvedEircode = normalized.isNotEmpty
        ? normalized
        : _normalizePostalCode(fields['postcode']);

    final displayLabel = resolvedEircode != null
        ? IrishAddressFormat.formatFull(
            fields: fields,
            eircode: resolvedEircode,
          )
        : _displayLabelWithoutEircode(fields);

    return IrishAddressSuggestion(
      displayLabel: IrishAddressFormat.sanitizeCommaSeparatedLabel(displayLabel),
      streetLine: IrishAddressFormat.sanitizeCommaSeparatedLabel(
        IrishAddressFormat.hasStreetLine(fields)
            ? displayLabel.split(',').first.trim()
            : displayLabel,
      ),
      area: IrishAddressFormat.formatPublicArea(fields) ?? '',
      county: IrishAddressFormat.countyZoneLabel(
        fields,
        eircode: resolvedEircode,
      ),
      eircode: resolvedEircode,
      latitude: lat,
      longitude: lon,
    );
  }

  static String _displayLabelWithoutEircode(Map<String, String> fields) {
    final displayName = fields['display_name']?.trim() ?? '';
    if (displayName.isNotEmpty) {
      final comma = displayName.indexOf(',');
      if (comma > 0) {
        return displayName.substring(0, comma).trim();
      }
      return displayName;
    }

    final parts = <String>[];
    if (IrishAddressFormat.hasStreetLine(fields)) {
      final hn = fields['house_number']?.trim() ?? '';
      final road = fields['road']?.trim() ?? '';
      parts.add(hn.isNotEmpty ? '$hn $road' : road);
    }
    final area = IrishAddressFormat.formatPublicArea(fields);
    if (area != null && area.isNotEmpty) parts.add(area);
    final county = fields['county']?.trim() ?? '';
    if (county.isNotEmpty) parts.add(county);
    return parts.join(', ');
  }

  static IrishAddressSuggestion _minimalSuggestion({
    required String normalized,
    required double lat,
    required double lon,
  }) {
    final zone = IrishAddressFormat.countyZoneLabel({}, eircode: normalized);
    return IrishAddressSuggestion(
      displayLabel: '$zone, $normalized',
      streetLine: normalized,
      area: zone,
      county: zone,
      eircode: normalized,
      latitude: lat,
      longitude: lon,
    );
  }
}
