import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/config/market/dublin_districts.dart';
import 'package:true_circle/utils/listing_area_resolution.dart';

void main() {
  group('resolveListingAreaKey', () {
    test('D03 NX79 with Clontarf coordinates resolves to Dublin 3', () {
      const lat = 53.364;
      const lon = -6.228;

      final key = resolveListingAreaKey(
        eircode: 'D03 NX79',
        lat: lat,
        lon: lon,
      );

      expect(key, 'dublin3');
      expect(
        dublinDistrictLabelForKey(key!),
        'Dublin 3 (Clontarf, Fairview)',
      );
    });

    test('valid Dublin eircode wins over overlapping coordinate district', () {
      final coordDistrict = dublinDistrictLabelFromCoordinates(53.364, -6.228);
      expect(coordDistrict, 'Dublin 13 (Howth, Baldoyle)');

      final key = resolveListingAreaKey(
        eircode: 'D03 NX79',
        lat: 53.364,
        lon: -6.228,
      );

      expect(key, isNot('dublin13'));
      expect(key, 'dublin3');
    });

    test('logs disagreement when eircode and coordinate districts differ', () {
      final logs = <String>[];

      resolveListingAreaKey(
        eircode: 'D03 NX79',
        lat: 53.364,
        lon: -6.228,
        onDistrictMismatch: logs.add,
      );

      expect(logs, hasLength(1));
      expect(logs.single, contains('D03 NX79'));
      expect(logs.single, contains('dublin3'));
      expect(logs.single, contains('Dublin 13'));
    });

    test('uses coordinates when eircode is absent', () {
      final key = resolveListingAreaKey(
        lat: 53.364,
        lon: -6.228,
      );

      expect(key, 'dublin13');
    });

    test('uses coordinates when eircode is invalid', () {
      final key = resolveListingAreaKey(
        eircode: 'not-an-eircode',
        lat: 53.364,
        lon: -6.228,
      );

      expect(key, 'dublin13');
    });

    test('listingAreaKeyFromEircode maps D03 routing key to dublin3', () {
      expect(listingAreaKeyFromEircode('D03 NX79'), 'dublin3');
      expect(listingAreaKeyFromEircode('d03nx79'), 'dublin3');
    });
  });
}
