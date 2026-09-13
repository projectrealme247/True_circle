import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/preferred_layout_match.dart';

void main() {
  group('PreferredLayoutMatch bed rules', () {
    test('Studio matches studio only', () {
      expect(
        PreferredLayoutMatch.evaluate(
          preferredLayout: 'Studio',
          listing: {'bedrooms': 'Studio'},
        ).matches,
        isTrue,
      );
      expect(
        PreferredLayoutMatch.evaluate(
          preferredLayout: 'Studio',
          listing: {'bedrooms': '1 bed'},
        ).matches,
        isFalse,
      );
    });

    test('1 Bed accepts 1+ beds, not studio', () {
      expect(
        PreferredLayoutMatch.evaluate(
          preferredLayout: '1 Bed',
          listing: {'bedrooms': '1 bed'},
        ).matches,
        isTrue,
      );
      expect(
        PreferredLayoutMatch.evaluate(
          preferredLayout: '1 Bed',
          listing: {'bedrooms': '2 bed'},
        ).matches,
        isTrue,
      );
      expect(
        PreferredLayoutMatch.evaluate(
          preferredLayout: '1 Bed',
          listing: {'bedrooms': 'Studio'},
        ).matches,
        isFalse,
      );
    });

    test('2 Bed accepts 2+', () {
      expect(
        PreferredLayoutMatch.evaluate(
          preferredLayout: '2 Bed',
          listing: {'bedrooms': '1 bed'},
        ).matches,
        isFalse,
      );
      expect(
        PreferredLayoutMatch.evaluate(
          preferredLayout: '2 Bed',
          listing: {'bedrooms': '3 bed'},
        ).matches,
        isTrue,
      );
    });

    test('4+ requires four or more', () {
      expect(
        PreferredLayoutMatch.evaluate(
          preferredLayout: '4+ Bed',
          listing: {'bedrooms': '3 bed'},
        ).matches,
        isFalse,
      );
      expect(
        PreferredLayoutMatch.evaluate(
          preferredLayout: '4+ Bed',
          listing: {'bedrooms': '4 bed'},
        ).matches,
        isTrue,
      );
    });

    test('does not use occupant persona when layout present', () {
      // Family persona historically forced 2+; studio layout must still fail 1-bed listing.
      final result = PreferredLayoutMatch.evaluate(
        preferredLayout: 'Studio',
        listing: {'bedrooms': '2 bed'},
      );
      expect(result.matches, isFalse);
      expect(result.requirement, PreferredBedRequirement.studio);
    });
  });
}
