import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<Map<String, String>?> lookup(double lat, double lon) async {
  try {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/reverse',
      {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'format': 'json',
        'addressdetails': '1',
        'zoom': '18',
      },
    );
    final completer = Completer<Map<String, String>?>();
    final xhr = web.XMLHttpRequest();
    xhr.open('GET', uri.toString());
    xhr.setRequestHeader('Accept', 'application/json');
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
          completer.complete(null);
          return;
        }
        final fields = <String, String>{
          for (final entry in address.entries)
            entry.key.toString(): entry.value?.toString() ?? '',
        };
        final displayName = decoded['display_name']?.toString() ?? '';
        if (displayName.isNotEmpty) {
          fields['display_name'] = displayName;
        }
        completer.complete(fields);
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
