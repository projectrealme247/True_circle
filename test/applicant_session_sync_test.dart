import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/applicant_session_sync.dart';

void main() {
  group('ApplicantSessionSync.normalizeCommuteProfiles', () {
    test('adds max_commute_minutes fallback from session budget', () {
      final normalized = ApplicantSessionSync.normalizeCommuteProfiles({
        'maximum_commute_budget_minutes': 30,
        'commute_profiles': [
          {
            'id': 'primary',
            'label': 'You',
            'commute_method': 'public_transport_walking',
            'commute_destination_hub_id': 'tcd',
          },
        ],
      });

      expect(normalized.single['max_commute_minutes'], 30);
    });

    test('preserves per-profile max_commute_minutes', () {
      final normalized = ApplicantSessionSync.normalizeCommuteProfiles({
        'commute_profiles': [
          {
            'id': 'primary',
            'commute_method': 'public_transport_walking',
            'commute_destination_hub_id': 'tcd',
            'max_commute_minutes': 20,
          },
          {
            'id': 'partner',
            'commute_method': 'driving',
            'commute_destination_hub_id': 'ucd',
            'max_commute_minutes': 50,
          },
        ],
      });

      expect(normalized[0]['max_commute_minutes'], 20);
      expect(normalized[1]['max_commute_minutes'], 50);
    });
  });

  group('ApplicantSessionSync.buildCoApplicants', () {
    test('builds primary applicant from scalar session fields', () {
      final applicants = ApplicantSessionSync.buildCoApplicants({
        'net_monthly_income': 4200,
        'trust_tier': 'Grand',
        'employment_verified': true,
        'household_has_pets': false,
        'household_smoker': false,
        'preferred_lease_months': 12,
        'earliest_move_in_date': '2026-09-01',
      });

      expect(applicants.length, 1);
      expect(applicants.first['net_monthly_income'], 4200);
      expect(applicants.first['has_verified_grand_badge'], isTrue);
      expect(applicants.first['has_verified_corporate_email'], isTrue);
      expect(applicants.first['preferred_lease_months'], 12);
      expect(applicants.first['lifestyle_display_chips'], ['Non-smoker']);
    });

    test('adds partner when partner income is provided', () {
      final applicants = ApplicantSessionSync.buildCoApplicants({
        'net_monthly_income': 3200,
        'partner_net_monthly_income': 2800,
        'household_smoker': true,
      });

      expect(applicants.length, 2);
      expect(applicants[1]['net_monthly_income'], 2800);
      expect(applicants.first['lifestyle_display_chips'], contains('Smoker'));
    });
  });

  group('ApplicantSessionSync.enrich', () {
    test('merges HAP contribution into co_applicants household income path', () {
      final enriched = ApplicantSessionSync.enrich({
        'net_monthly_income': 3000,
        'has_hap_voucher': true,
        'hap_voucher_contribution': 500,
        'commute_profiles': [
          {
            'id': 'primary',
            'commute_method': 'public_transport_walking',
            'commute_destination_hub_id': 'tcd',
            'max_commute_minutes': 40,
          },
        ],
      });

      expect(enriched['co_applicants'], isA<List>());
      expect((enriched['co_applicants'] as List).length, 1);
      expect(enriched['has_hap_voucher'], isTrue);
      expect(
        (enriched['commute_profiles'] as List).single['max_commute_minutes'],
        40,
      );
    });
  });
}
