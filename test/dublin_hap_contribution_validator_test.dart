import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/dublin_hap_contribution_validator.dart';

void main() {
  group('DublinHapContributionValidator', () {
    test('standard cap for single-person household', () {
      expect(DublinHapContributionValidator.standardCapForSession({}), 660);
    });
    test('rejects contribution above standard cap', () {
      final error = DublinHapContributionValidator.validateContribution(
        session: {},
        contributionEur: 700,
        upliftApproved: false,
      );
      expect(error, isNotNull);
    });
    test('allows contribution within 35% uplift cap', () {
      final error = DublinHapContributionValidator.validateContribution(
        session: {},
        contributionEur: 880,
        upliftApproved: true,
        upliftPercent: 0.35,
      );
      expect(error, isNull);
    });
  });
}
