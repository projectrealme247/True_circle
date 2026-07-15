import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../models/dublin_destination_suggestion.dart';
import '../utils/geo_math.dart';
import '../utils/nominatim_label_sanitizer.dart';
import 'nominatim_reverse.dart';

const _maxResults = 3;
const _dublinCenter = LatLng(53.3498, -6.2603);

Future<List<DublinDestinationSuggestion>> search(String query) async {
  final trimmed = query.trim();
  if (trimmed.length < 2) return const [];

  try {
    final completer = Completer<List<DublinDestinationSuggestion>>();
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': trimmed,
        'format': 'json',
        'limit': '$_maxResults',
        'countrycodes': 'ie',
        'addressdetails': '1',
      },
    );

    final xhr = web.XMLHttpRequest();
    xhr.open('GET', uri.toString());
    xhr.setRequestHeader('Accept', 'application/json');
    xhr.setRequestHeader(
      'User-Agent',
      'TrueCircle/1.0 (seeker-destination-search)',
    );
    xhr.onload = ((web.Event _) {
      try {
        if (xhr.status < 200 || xhr.status >= 300) {
          completer.complete(const []);
          return;
        }
        final decoded = jsonDecode(xhr.responseText);
        if (decoded is! List) {
          completer.complete(const []);
          return;
        }

        final results = <DublinDestinationSuggestion>[];
        for (final item in decoded) {
          if (results.length >= _maxResults) break;
          if (item is! Map) continue;

          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          if (lat == null || lon == null) continue;
          if (!_isWithinGreaterDublin(lat, lon)) continue;

          final address = item['address'];
          String label = '';
          if (address is Map) {
            final fields = <String, String>{
              for (final entry in address.entries)
                entry.key.toString(): entry.value?.toString() ?? '',
            };
            final built = NominatimLabelSanitizer.fromAddressMap(fields);
            label = NominatimLabelSanitizer.formatSuggestionLabel(
              built.isNotEmpty
                  ? built
                  : NominatimLabelSanitizer.cleanDisplayString(
                      item['display_name']?.toString() ?? trimmed,
                    ),
            );
          }
          if (label.isEmpty) {
            label = NominatimLabelSanitizer.formatSuggestionLabel(
              item['display_name']?.toString() ?? trimmed,
            );
          }
          if (label.isEmpty) continue;

          results.add(
            DublinDestinationSuggestion(
              displayLabel: label,
              latitude: lat,
              longitude: lon,
              source: 'nominatim',
            ),
          );
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

Future<DublinDestinationSuggestion?> reverseGeocode(
  double latitude,
  double longitude,
) async {
  if (!_isWithinGreaterDublin(latitude, longitude)) return null;

  final fields = await NominatimReverse.lookup(latitude, longitude);
  if (fields != null && fields.isNotEmpty) {
    final label = NominatimLabelSanitizer.formatSuggestionLabel(
      NominatimLabelSanitizer.fromAddressMap(fields),
    );
    if (label.isNotEmpty) {
      return DublinDestinationSuggestion(
        displayLabel: label,
        latitude: latitude,
        longitude: longitude,
        source: 'gps',
      );
    }
  }

  return null;
}

bool _isWithinGreaterDublin(double lat, double lon) {
  return GeoMath.haversineKm(_dublinCenter, LatLng(lat, lon)) <= 45;
}
