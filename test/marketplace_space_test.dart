import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/utils/numeric_bounds.dart';

void main() {
  group('NumericBounds', () {
    test('clamps percent to 0-100', () {
      expect(NumericBounds.clampPercent(-5), 0);
      expect(NumericBounds.clampPercent(150), 100);
      expect(NumericBounds.clampPercent(72.4), 72.4);
    });
  });
  group('MarketplaceSpace', () {
    test('maps shared arrangement from session', () {
      expect(
        MarketplaceSpace.fromSession({'preferred_arrangement': 'shared'}),
        MarketplaceSpace.sharedSpace,
      );
    });
  });
}
