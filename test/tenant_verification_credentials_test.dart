import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/tenant_verification_credentials.dart';
import 'package:true_circle/utils/viewer_profile.dart';

void main() {
  group('TenantVerificationCredentials', () {
    test('resolves Corporate Track checklist for Grand tier', () {
      final credentials = TenantVerificationCredentials.fromSession({
        'trust_tier': 'Grand',
        'trust_stage': 2,
        'employment_verified': true,
        'verification_track': 'Corporate Track',
      });

      expect(credentials.tierLabel, 'Grand');
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

    test('resolves Open Banking Track checklist', () {
      final credentials = TenantVerificationCredentials.fromSession({
        'trust_tier': 'Grand',
        'trust_stage': 2,
        'financial_verified': true,
        'verification_track': 'Open Banking Track',
      });

      expect(credentials.track, TenantVerificationTrack.openBanking);
      expect(
        credentials.track!.neutralStatusBadge,
        contains('Self-Declared / Local Resident'),
      );
    });

    test('resolves Sound tier from trust_stage', () {
      final credentials = TenantVerificationCredentials.fromSession({
        'trust_tier': 'Sound',
        'trust_stage': 3,
      });

      expect(credentials.tierLabel, 'Sound');
      expect(credentials.trustStage, TrustStage.idVerified);
      expect(credentials.showTrackChecklist, isFalse);
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
