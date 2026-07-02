import 'nominatim_reverse_stub.dart'
    if (dart.library.js_interop) 'nominatim_reverse_web.dart' as impl;

/// Reverse-geocode coordinates via OpenStreetMap Nominatim (web fallback).
abstract final class NominatimReverse {
  static Future<Map<String, String>?> lookup(double lat, double lon) =>
      impl.lookup(lat, lon);
}
