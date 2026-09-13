import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/listing_data.dart';

void main() {
  group('ListingData detail helpers', () {
    test('bedCount parses bedroom count from title when field absent', () {
      final listing = {
        'title': '1 bed · Dublin 4 · sea proximity',
        'bedrooms': '',
      };

      expect(ListingData.bedCount(listing), 1);
      expect(ListingData.bedsHighlightLabel(listing), '1 Bed');
    });

    test('detailTransitWalkProfile parses walk copy from description', () {
      final listing = {
        'description':
            'Fully furnished. Sandymount Strand 10 min walk. Professionals preferred.',
      };

      final profile = ListingData.detailTransitWalkProfile(listing);
      expect(profile, isNotNull);
      expect(profile!.minutes, 10);
      expect(profile.destination, 'Sandymount Strand');
    });

    test('parking matrix uses softer copy when unknown', () {
      final listing = <String, dynamic>{};

      expect(ListingData.parkingMatrixLabel(listing), 'Ask Host About Parking');
    });
  });
}
