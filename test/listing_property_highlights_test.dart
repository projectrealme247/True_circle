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
        'parking_available': true,
        'parking_type': 'driveway',
      });

      expect(cells, hasLength(4));
      expect(cells[0].label, 'Secure Bike Storage Available');
      expect(cells[1].label, 'Driveway');
      expect(cells[2].label, 'Budget Protection Active');
      expect(cells[3].label, 'Verified Landlord Status');
    });

    test('independentPlaceFactCells uses property facts only, no fillers', () {
      final cells = ListingPropertyHighlights.independentPlaceFactCells({
        'bedrooms': '2 bed',
        'bathrooms': '1',
        'property_category': 'Apartment',
        'furnishing': 'Furnished',
        'available_from': '2026-08-04',
        'parking_type': 'driveway',
        'parking_available': true,
        'pets_policy': 'not_allowed',
        'agreement_type': 'long_term',
        'sublet_duration_value': '1',
        'sublet_duration_unit': 'years',
        'ber_rating': 'B2',
      });

      expect(cells.map((c) => c.label).toList(), [
        '2 Beds',
        '1 Bath',
        'Apartment',
        'Furnished',
        '4 Aug',
        'Driveway',
        'No Pets',
        'Long-Term · 1 year',
        'BER B2',
      ]);
      expect(cells.every((c) => !c.isPlatformFallback), isTrue);
    });

    test('independentPlaceFactCells returns empty when no facts', () {
      final cells = ListingPropertyHighlights.independentPlaceFactCells({});
      expect(cells, isEmpty);
    });

    test('sharedLivingRoomSnapshotCells uses short room and bath labels', () {
      final cells = ListingPropertyHighlights.sharedLivingRoomSnapshotCells({
        'room_type_matching': 'private_room',
        'bathroom_type': 'private_ensuite',
        'available_from': '2026-09-07',
        'price': '700/month',
      });

      expect(cells.map((c) => c.label).toList(), [
        '🛏️ Private',
        '🚿 Private Bathroom',
        '📅 7 Sep',
        '💶 €700/month',
      ]);
      expect(cells.every((c) => !c.isPlatformFallback), isTrue);
    });

    test('sharedLivingCultureCells hides when empty', () {
      expect(
        ListingPropertyHighlights.sharedLivingCultureCells({}),
        isEmpty,
      );
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
