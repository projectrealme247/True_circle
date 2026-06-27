import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/screens/listing_detail_screen.dart';
import 'package:true_circle/utils/listing_data.dart';

void main() {
  group('ListingDetailCopy typography', () {
    test('displayTitle title-cases each descriptor segment', () {
      final listing = {
        'title': '1 bed · Dublin 4 · sea proximity',
      };

      expect(
        ListingDetailCopy.displayTitle(listing),
        '1 Bed · Dublin 4 · Sea Proximity',
      );
    });

    test('displayTitle handles commuter belt style segments', () {
      final listing = {
        'title': '2 bed · lucan · commuter belt',
      };

      expect(
        ListingDetailCopy.displayTitle(listing),
        '2 Bed · Lucan · Commuter Belt',
      );
    });

    test('highlightLabel preserves RTB acronym and title-cases words', () {
      expect(
        ListingDetailCopy.highlightLabel('RTB status not provided'),
        'RTB Status Not Provided',
      );
      expect(
        ListingDetailCopy.highlightLabel('Ask host about parking'),
        'Ask Host About Parking',
      );
    });
  });

  group('ListingData matrix fallbacks', () {
    test('unknown rtb and parking use title case copy', () {
      final listing = <String, dynamic>{};

      expect(ListingData.rtbMatrixLabel(listing), 'RTB Status Not Provided');
      expect(ListingData.parkingMatrixLabel(listing), 'Ask Host About Parking');
    });
  });
}
