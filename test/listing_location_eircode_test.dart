import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:true_circle/config/market/dublin_districts.dart';
import 'package:true_circle/services/eircode_geocoding_service.dart';
import 'package:true_circle/services/eircode_lookup_service.dart';
import 'package:true_circle/services/nominatim_forward.dart';

void main() {
  group('Listing location — Eircode & address resolution', () {
    test('1. D15 FT9N validates and normalises (Daft-style input)', () {
      expect(EircodeGeocodingService.isValidFormat('d15 ft9n'), isTrue);
      expect(EircodeGeocodingService.isValidFormat('D15FT9N'), isTrue);
      expect(EircodeGeocodingService.normalize('d15ft9n'), 'D15 FT9N');
    });

    test('2. NominatimForward builds full street address for Hollywoodrath', () {
      final address = NominatimForward.formatAddress(
        {
          'house_number': '9',
          'road': 'Hollywoodrath Park',
          'neighbourhood': 'Hollywoodrath',
          'suburb': 'Hollystown',
          'city_district': 'Dublin 15',
          'city': 'Dublin',
          'postcode': 'D15 FT9N',
        },
        eircode: 'D15 FT9N',
      );
      expect(
        address,
        '9 Hollywoodrath Park, Hollywoodrath, Hollystown, Dublin 15, D15 FT9N',
      );
    });

    test('3. NominatimForward builds public area for privacy checkbox', () {
      final publicArea = NominatimForward.formatPublicArea({
        'neighbourhood': 'Hollywoodrath',
        'suburb': 'Hollystown',
      });
      expect(publicArea, 'Hollywoodrath, Hollystown');
    });

    test('4. resolveCoordinates returns coords when geocoder succeeds', () async {
      const hollystownLat = 53.412;
      const hollystownLon = -6.418;

      final coords = await EircodeGeocodingService.resolveCoordinates(
        'D15 FT9N',
        geocode: (_) async => [
          Location(
            latitude: hollystownLat,
            longitude: hollystownLon,
            timestamp: DateTime.now(),
          ),
        ],
      );

      expect(coords.latitude, hollystownLat);
      expect(coords.longitude, hollystownLon);
    });

    test('5. Dublin 15 district centroid is in north-west Dublin', () {
      final centroid = dublinDistrictCentroidFromLabel('Dublin 15 (Blanchardstown)');
      expect(centroid, isNotNull);
      expect(centroid!.lat, greaterThan(53.35));
      expect(centroid.lat, lessThan(53.45));
      expect(centroid.lon, lessThan(-6.30));
    });

    test('6. sameEircode compares compact and spaced forms', () {
      expect(EircodeGeocodingService.sameEircode('D15 FT9N', 'd15ft9n'), isTrue);
      expect(EircodeGeocodingService.sameEircode('D15 FT9N', 'D02 P638'), isFalse);
    });

    test('7. coordinatesMatchDistrict rejects Dublin 2 coords for D15 FT9N', () {
      const kildareStreetLat = 53.3411249;
      const kildareStreetLon = -6.2545;

      expect(
        EircodeGeocodingService.coordinatesMatchDistrict(
          kildareStreetLat,
          kildareStreetLon,
          'D15 FT9N',
        ),
        isFalse,
      );
      expect(
        EircodeGeocodingService.coordinatesMatchDistrict(
          53.412,
          -6.418,
          'D15 FT9N',
        ),
        isTrue,
      );
    });

    test(
      '8. EircodeLookupService.resolve falls back to the Dublin 15 district '
      'centroid when no exact building-level match exists (real-world case: '
      'Nominatim/Overpass rarely index individual Irish Eircodes)',
      () async {
        // Nominatim/Overpass are unreachable/stubbed in the test VM, and the
        // native geocoding plugin has no platform implementation here either
        // — this exercises the same "no exact hit" path web users hit for
        // most residential Eircodes.
        final suggestion = await EircodeLookupService.resolve('D15 FT9N');

        expect(suggestion, isNotNull);
        expect(suggestion!.eircode, 'D15 FT9N');
        expect(suggestion.county, contains('Dublin 15'));
        expect(
          EircodeGeocodingService.coordinatesMatchDistrict(
            suggestion.latitude,
            suggestion.longitude,
            'D15 FT9N',
          ),
          isTrue,
        );
      },
    );

    test('9. EircodeLookupService.resolve rejects malformed input', () async {
      expect(await EircodeLookupService.resolve('not an eircode'), isNull);
    });
  });
}
