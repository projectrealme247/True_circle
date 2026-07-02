import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<({double lat, double lon})?> fetchIpCoordinates() async {
  try {
    final completer = Completer<({double lat, double lon})?>();
    final xhr = web.XMLHttpRequest();
    xhr.open('GET', 'https://ipapi.co/json/');
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
        final lat = decoded['latitude'];
        final lon = decoded['longitude'];
        if (lat is! num || lon is! num) {
          completer.complete(null);
          return;
        }
        completer.complete((lat: lat.toDouble(), lon: lon.toDouble()));
      } catch (_) {
        completer.complete(null);
      }
    }).toJS;
    xhr.onerror = ((web.Event _) => completer.complete(null)).toJS;
    xhr.send();
    return completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
  } catch (_) {
    return null;
  }
}
