import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/services/verification_gateway_recommendation.dart';

void main() {
  group('isInboundRelocationPersona', () {
    test('returns true for relocating persona', () {
      expect(
        isInboundRelocationPersona({'seeker_persona': 'relocating'}),
        isTrue,
      );
    });

    test('returns true for family persona', () {
      expect(
        isInboundRelocationPersona({'seeker_persona': 'family'}),
        isTrue,
      );
    });

    test('returns true for professional arriving soon', () {
      expect(
        isInboundRelocationPersona({
          'seeker_persona': 'professional',
          'dublin_location_context': 'arriving_soon',
        }),
        isTrue,
      );
    });

    test('returns false for student persona', () {
      expect(
        isInboundRelocationPersona({'seeker_persona': 'student'}),
        isFalse,
      );
    });
  });

  group('verificationGatewayLayoutForSession', () {
    test('student shows university OTP primary and suppresses LinkedIn', () {
      final layout = verificationGatewayLayoutForSession({
        'seeker_persona': 'student',
        'dublin_location_context': 'already_in_dublin',
      });

      expect(layout.subtitle, contains('Tailored for Students'));
      expect(layout.recommended, VerificationGatewayPath.universityEmailOtp);
      expect(layout.alternates, [
        VerificationGatewayPath.offerLetterUpload,
        VerificationGatewayPath.openBanking,
      ]);
      expect(layout.alternates, isNot(contains(VerificationGatewayPath.linkedInCorporate)));
      expect(layout.alternates, isNot(contains(VerificationGatewayPath.inboundRelocation)));
    });

    test('student arriving soon still recommends university OTP', () {
      final layout = verificationGatewayLayoutForSession({
        'seeker_persona': 'student',
        'dublin_location_context': 'arriving_soon',
      });

      expect(layout.recommended, VerificationGatewayPath.universityEmailOtp);
      expect(layout.alternates, contains(VerificationGatewayPath.offerLetterUpload));
    });

    test('family shows inbound relocation and suppresses university OTP', () {
      final layout = verificationGatewayLayoutForSession({
        'seeker_persona': 'family',
      });

      expect(layout.recommended, VerificationGatewayPath.inboundRelocation);
      expect(layout.alternates, [
        VerificationGatewayPath.employmentContractUpload,
        VerificationGatewayPath.linkedInCorporate,
        VerificationGatewayPath.openBanking,
      ]);
      expect(layout.alternates, isNot(contains(VerificationGatewayPath.universityEmailOtp)));
    });

    test('relocating professional shows inbound relocation primary', () {
      final layout = verificationGatewayLayoutForSession({
        'seeker_persona': 'relocating',
      });

      expect(layout.recommended, VerificationGatewayPath.inboundRelocation);
      expect(layout.alternates, contains(VerificationGatewayPath.linkedInCorporate));
      expect(layout.alternates, isNot(contains(VerificationGatewayPath.universityEmailOtp)));
    });
  });

  group('getVerificationLabel', () {
    test('student maps to university email OTP', () {
      final label = getVerificationLabel({
        'seeker_persona': 'student',
        'dublin_location_context': 'already_in_dublin',
      });

      expect(label.pathTitle, 'University Email OTP');
      expect(label.leadingEmoji, '🎓');
      expect(label.route, '/verify/id/university-email');
      expect(label.path, VerificationGatewayPath.universityEmailOtp);
    });

    test('family maps to inbound relocation without emoji in title', () {
      final label = getVerificationLabel({'seeker_persona': 'family'});

      expect(label.pathTitle, 'Inbound Relocation Verification');
      expect(label.pathTitle, isNot(contains('💼')));
      expect(label.path, VerificationGatewayPath.inboundRelocation);
    });
  });

  group('alternateVerificationPaths', () {
    test('uses persona-filtered alternates when session provided', () {
      final alternates = alternateVerificationPaths(
        VerificationGatewayPath.universityEmailOtp,
        session: {'seeker_persona': 'student'},
      );

      expect(alternates, [
        VerificationGatewayPath.offerLetterUpload,
        VerificationGatewayPath.openBanking,
      ]);
    });
  });
}
