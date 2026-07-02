import 'fast_location_ip_lookup_stub.dart'
    if (dart.library.io) 'fast_location_ip_lookup_io.dart'
    if (dart.library.js_interop) 'fast_location_ip_lookup_web.dart' as impl;

/// Coarse IP-based geolocation — used when GPS times out.
abstract final class FastLocationIpLookup {
  static Future<({double lat, double lon})?> coordinates() =>
      impl.fetchIpCoordinates();
}
