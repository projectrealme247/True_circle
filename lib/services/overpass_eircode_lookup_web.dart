import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'eircode_geocoding_service.dart';
import 'overpass_eircode_lookup.dart';

Future<OverpassEircodeHit?> resolveEircode(String eircode) async {
  final normalized = EircodeGeocodingService.normalize(eircode);
  final compact = normalized.replaceAll(' ', '');
  if (!EircodeGeocodingService.isValidFormat(compact)) return null;

  final query = '''
[out:json][timeout:14];
(
  node["addr:postcode"="$normalized"];
  way["addr:postcode"="$normalized"];
  relation["addr:postcode"="$normalized"];
  node["addr:postcode"="$compact"];
  way["addr:postcode"="$compact"];
  relation["addr:postcode"="$compact"];
);
out center 1;
''';

  try {
    final completer = Completer<OverpassEircodeHit?>();
    final xhr = web.XMLHttpRequest();
    xhr.open('POST', 'https://overpass-api.de/api/interpreter');
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
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
        final elements = decoded['elements'];
        if (elements is! List || elements.isEmpty) {
          completer.complete(null);
          return;
        }
        for (final element in elements) {
          if (element is! Map) continue;
          final hit = _parseElement(element, normalized);
          if (hit != null) {
            completer.complete(hit);
            return;
          }
        }
        completer.complete(null);
      } catch (_) {
        completer.complete(null);
      }
    }).toJS;
    xhr.onerror = ((web.Event _) => completer.complete(null)).toJS;
    xhr.send('data=${Uri.encodeComponent(query)}'.toJS);
    return completer.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () => null,
    );
  } catch (_) {
    return null;
  }
}

OverpassEircodeHit? _parseElement(Map element, String normalized) {
  final tags = element['tags'];
  if (tags is! Map) return null;

  final postcode = tags['addr:postcode']?.toString() ?? '';
  if (postcode.isNotEmpty &&
      !EircodeGeocodingService.sameEircode(postcode, normalized)) {
    return null;
  }

  final center = element['center'];
  double? lat;
  double? lon;
  if (center is Map) {
    lat = (center['lat'] as num?)?.toDouble();
    lon = (center['lon'] as num?)?.toDouble();
  }
  lat ??= (element['lat'] as num?)?.toDouble();
  lon ??= (element['lon'] as num?)?.toDouble();
  if (lat == null || lon == null) return null;
  if (!EircodeGeocodingService.coordinatesMatchDistrict(lat, lon, normalized)) {
    return null;
  }

  return OverpassEircodeHit(
    latitude: lat,
    longitude: lon,
    houseNumber: tags['addr:housenumber']?.toString(),
    street: tags['addr:street']?.toString(),
    city: tags['addr:city']?.toString() ?? tags['addr:suburb']?.toString(),
    postcode: postcode.isEmpty ? normalized : postcode,
  );
}
