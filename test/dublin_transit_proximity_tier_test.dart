import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/dublin_transit_proximity_tier.dart';

void main() {
  group('DublinTransitProximityTier', () {
    test('tier 1 for Luas within 10 minutes', () {
      final tier = DublinTransitProximityTier.fromListing({
        'proximity_data': {
          'transit_type': 'Luas Green Line',
          'walk_minutes': 8
        },
      });
      expect(tier?.tier, 1);
    });
    test('tier 1 for DART within 10 minutes', () {
      final tier = DublinTransitProximityTier.fromListing({
        'proximity_data': {'transit_type': 'DART', 'walk_minutes': 9},
      });
      expect(tier?.tier, 1);
      expect(tier?.shortLabel, 'Luas/DART ≤10 min');
    });
    test('tier 2 for Dublin Bus within 12 minutes', () {
      final tier = DublinTransitProximityTier.fromListing({
        'proximity_data': {
          'transit_type': 'Dublin Bus High-Frequency',
          'walk_minutes': 11
        },
      });
      expect(tier?.tier, 2);
    });
    test('returns null without proximity data', () {
      expect(DublinTransitProximityTier.fromListing({}), isNull);
    });
  });
}
