import 'nominatim_forward.dart';

Future<Map<String, dynamic>?> searchEircode(String eircode) async => null;

Future<Map<String, dynamic>?> searchEircodePin(String eircode) async => null;

Future<List<NominatimAddressResult>> searchAddress(String query) async =>
    const [];

Future<String?> reverseGeocode(double lat, double lon) async => null;
