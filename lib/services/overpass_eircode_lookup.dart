import 'overpass_eircode_lookup_stub.dart'
    if (dart.library.js_interop) 'overpass_eircode_lookup_web.dart' as impl;

/// OSM Overpass lookup for elements tagged with an exact Irish Eircode.
abstract final class OverpassEircodeLookup {
  static Future<OverpassEircodeHit?> resolve(String eircode) =>
      impl.resolveEircode(eircode);
}

class OverpassEircodeHit {
  const OverpassEircodeHit({
    required this.latitude,
    required this.longitude,
    this.houseNumber,
    this.street,
    this.city,
    this.postcode,
  });

  final double latitude;
  final double longitude;
  final String? houseNumber;
  final String? street;
  final String? city;
  final String? postcode;
}
