import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/applicant_trust_tier.dart';
import 'package:true_circle/models/move_in_timing.dart';
import 'package:true_circle/utils/landlord_decision_summary_builder.dart';

void main() {
  group('LandlordDecisionSummaryBuilder', () {
    test('surfaces household pets guarantor layout and move-in without raw income', () {
      final summary = LandlordDecisionSummaryBuilder.fromSession(
        session: {
          'preferred_layout': '2 Bed',
          'move_in_window': 'next_month',
          'family_adults': 2,
          'family_children': 0,
          'group_size': 2,
          'seeker_persona': 'professional',
          'occupant_type': 'Working Professionals',
          'household_has_pets': false,
          'guarantor_status': 'yes',
          'net_monthly_income': 5000,
          'partner_net_monthly_income': 3000,
          'trust_tier': 'Sound',
          'trust_stage': 3,
          'employment_verified': true,
          'financial_verified': true,
          'preferred_lease_months': 12,
        },
        listing: {
          'price': '€2,150 / month',
          'bedrooms': '2 bed',
          'available_from': '2026-08-01',
          'availability_flexibility': 'plus_1_month',
          'lease_term_months': 12,
          'pets_allowed': false,
        },
        isSharedLiving: false,
        trustTier: ApplicantTrustTier.sound,
        leaseTermMatch: true,
        preferredLeaseMonths: 12,
        employmentVerified: true,
        financialVerified: true,
      );

      expect(summary.affordabilityMultiplier, greaterThanOrEqualTo(3.0));
      expect(summary.hasAffordability, isTrue);
      expect(summary.affordabilityMeetsTarget, isTrue);
      expect(summary.affordabilityLabel, '3.7× rent');
      expect(summary.affordabilityLabel.contains('verified'), isFalse);
      expect(summary.incomeSourceLabel, 'Self-declared');
      expect(summary.affordabilityLabel.contains('€'), isFalse);
      expect(summary.propertyRequirementMatch, isTrue);
      expect(summary.moveInQuality, isNot(TimingMatchQuality.none));
      expect(summary.householdHasPets, isFalse);
      expect(summary.guarantorStatus?.storageToken, 'yes');
      expect(summary.isCouple, isTrue);
      expect(summary.verificationChipLabels, containsAll([
        ApplicantTrustTier.verifiedUserLabel,
        'Employment',
      ]));
      expect(summary.verificationChipLabels.contains('Income'), isFalse);
    });

    test('unknown affordability when income cannot be calculated', () {
      final summary = LandlordDecisionSummaryBuilder.fromSession(
        session: {
          'preferred_layout': 'Studio',
          'move_in_window': 'flexible',
          'trust_tier': 'Sound',
        },
        listing: {
          'bedrooms': '2 bed',
          'price': '€1800',
          'available_from': '2026-08-01',
          'availability_flexibility': 'flexible',
        },
        isSharedLiving: false,
        trustTier: ApplicantTrustTier.sound,
      );

      expect(summary.affordabilityMultiplier, 0);
      expect(summary.hasAffordability, isFalse);
      expect(summary.affordabilityMeetsTarget, isFalse);
      expect(summary.affordabilityLabel, 'Unknown');
    });

    test('flags studio seeker against 2-bed listing as property mismatch', () {
      final summary = LandlordDecisionSummaryBuilder.fromSession(
        session: {
          'preferred_layout': 'Studio',
          'move_in_window': 'flexible',
          'trust_tier': 'Just Landed',
        },
        listing: {
          'bedrooms': '2 bed',
          'price': '€1800',
          'available_from': '2026-08-01',
          'availability_flexibility': 'flexible',
        },
        isSharedLiving: false,
      );

      expect(summary.propertyRequirementMatch, isFalse);
      expect(summary.moveInQuality, TimingMatchQuality.flexible);
      expect(summary.hasAffordability, isFalse);
      expect(summary.affordabilityLabel, 'Unknown');
    });
  });
}
