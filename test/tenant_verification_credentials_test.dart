import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/applicant_trust_tier.dart';
import 'package:true_circle/utils/tenant_verification_credentials.dart';

void main() {
  group('TenantVerificationCredentials', () {
    test('shows Verified User from employment unlock, not trust_tier', () {
      final credentials = TenantVerificationCredentials.fromSession({
        'trust_tier': 'Grand',
        'trust_stage': 2,
        'occupant_type': 'Working Professionals',
        'employment_verified': true,
        'verification_track': 'Corporate Track',
      });

      expect(credentials.tierLabel, ApplicantTrustTier.verifiedUserLabel);
      expect(credentials.isVerifiedUser, isTrue);
      expect(credentials.track, TenantVerificationTrack.corporate);
      expect(credentials.showTrackChecklist, isTrue);
      expect(
        credentials.track!.successBadge,
        contains('Corporate Track'),
      );
      expect(
        credentials.track!.neutralStatusBadge,
        contains('Pre-Arrival / Relocator Mode'),
      );
    });

    test('resolves Open Banking Track checklist without Verified User', () {
      final credentials = TenantVerificationCredentials.fromSession({
        'trust_tier': 'Grand',
        'trust_stage': 2,
        'occupant_type': 'Working Professionals',
        'financial_verified': true,
        'verification_track': 'Open Banking Track',
      });

      expect(credentials.track, TenantVerificationTrack.openBanking);
      expect(credentials.isVerifiedUser, isFalse);
      expect(credentials.tierLabel, isEmpty);
      expect(
        credentials.track!.neutralStatusBadge,
        contains('Self-Declared / Local Resident'),
      );
    });

    test('trust_stage alone does not show Verified User', () {
      final credentials = TenantVerificationCredentials.fromSession({
        'trust_tier': 'Sound',
        'trust_stage': 3,
        'occupant_type': 'Students',
      });

      expect(credentials.tierLabel, isEmpty);
      expect(credentials.isVerifiedUser, isFalse);
      expect(credentials.showTrackChecklist, isFalse);
    });

    test('student university email unlocks Verified User', () {
      final credentials = TenantVerificationCredentials.fromSession({
        'occupant_type': 'Students',
        'verified_university_email': 'a***@ucd.ie',
        'light_trust_verified': true,
      });

      expect(credentials.isVerifiedUser, isTrue);
      expect(credentials.tierLabel, ApplicantTrustTier.verifiedUserLabel);
    });

    test('denylist flags sensitive session keys', () {
      expect(
        TenantVerificationCredentials.containsSensitiveExposure({
          'full_name': 'Test',
          'monthly_salary_eur': 3200,
        }),
        isTrue,
      );
      expect(
        TenantVerificationCredentials.containsSensitiveExposure({
          'full_name': 'Test',
          'verification_track': 'Open Banking Track',
        }),
        isFalse,
      );
    });
  });
}
