import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/listing_property_highlights.dart';
import 'package:true_circle/utils/listing_strength_calculator.dart';

void main() {
  group('ListingPropertyHighlights', () {
    test('activeHighlights reads bike storage boolean', () {
      final cells = ListingPropertyHighlights.activeHighlights({
        'secure_bike_storage': true,
      });

      expect(
        cells.map((cell) => cell.label),
        contains('Secure Bike Storage Available'),
      );
    });

    test('gridCells always returns four items with platform fallbacks', () {
      final cells = ListingPropertyHighlights.gridCells({});

      expect(cells, hasLength(4));
      expect(cells[2].label, 'Budget Protection Active');
      expect(cells[3].label, 'Verified Landlord Status');
    });

    test('gridCells places custom amenities before reserved fallbacks', () {
      final cells = ListingPropertyHighlights.gridCells({
        'secure_bike_storage': true,
        'rtb_registered': true,
      });

      expect(cells, hasLength(4));
      expect(cells[0].label, 'Secure Bike Storage Available');
      expect(cells[1].label, 'RTB Registered Landlord');
      expect(cells[2].label, 'Budget Protection Active');
      expect(cells[3].label, 'Verified Landlord Status');
    });
  });

  group('ListingStrengthCalculator', () {
    test('uses auto-draft subtitle when description not edited', () {
      final snapshot = ListingStrengthCalculator.fromListing({
        'title': 'Bright 2-bed in Dublin 8',
        'description': 'Auto copy here with enough length to count for scoring.',
        'description_auto_drafted': true,
        'description_is_edited': false,
        'price': '2200/month',
        'location': 'Dublin 8',
        'images': ['a', 'b', 'c'],
      });

      expect(snapshot.isDescriptionEdited, isFalse);
      expect(snapshot.statusSubtitle, contains('optimized auto-draft copy'));
    });
  });
}
