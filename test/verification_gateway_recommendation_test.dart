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
    test('student shows university email primary and pre-arrival alternate', () {
      final layout = verificationGatewayLayoutForSession({
        'seeker_persona': 'student',
        'dublin_location_context': 'already_in_dublin',
      });

      expect(layout.subtitle, contains('Tailored for Students'));
      expect(layout.recommended, VerificationGatewayPath.universityEmailOtp);
      expect(layout.alternates, [
        VerificationGatewayPath.offerLetterUpload,
      ]);
      expect(
        layout.alternates,
        isNot(contains(VerificationGatewayPath.openBanking)),
      );
      expect(
        layout.alternates,
        isNot(contains(VerificationGatewayPath.linkedInCorporate)),
      );
    });

    test('student arriving soon still recommends university email', () {
      final layout = verificationGatewayLayoutForSession({
        'seeker_persona': 'student',
        'dublin_location_context': 'arriving_soon',
      });

      expect(layout.recommended, VerificationGatewayPath.universityEmailOtp);
      expect(layout.alternates, contains(VerificationGatewayPath.offerLetterUpload));
      expect(
        layout.alternates,
        isNot(contains(VerificationGatewayPath.openBanking)),
      );
    });

    test('family shows LinkedIn and employment only', () {
      final layout = verificationGatewayLayoutForSession({
        'seeker_persona': 'family',
      });

      expect(layout.recommended, VerificationGatewayPath.linkedInCorporate);
      expect(layout.alternates, [
        VerificationGatewayPath.employmentContractUpload,
      ]);
      expect(
        layout.alternates,
        isNot(contains(VerificationGatewayPath.openBanking)),
      );
      expect(
        layout.recommended,
        isNot(VerificationGatewayPath.inboundRelocation),
      );
    });

    test('relocating professional shows LinkedIn and employment only', () {
      final layout = verificationGatewayLayoutForSession({
        'seeker_persona': 'relocating',
      });

      expect(layout.recommended, VerificationGatewayPath.linkedInCorporate);
      expect(
        layout.alternates,
        contains(VerificationGatewayPath.employmentContractUpload),
      );
      expect(
        layout.alternates,
        isNot(contains(VerificationGatewayPath.openBanking)),
      );
      expect(layout.alternates, isNot(contains(VerificationGatewayPath.universityEmailOtp)));
    });

    test('Phase 1 layouts never include Open Banking', () {
      for (final session in [
        {'seeker_persona': 'student'},
        {'seeker_persona': 'family'},
        {'seeker_persona': 'relocating'},
        {'seeker_persona': 'professional'},
        {
          'seeker_persona': 'professional',
          'dublin_location_context': 'arriving_soon',
        },
        <String, dynamic>{},
      ]) {
        final layout = verificationGatewayLayoutForSession(
          session.isEmpty ? null : session,
        );
        expect(
          layout.recommended,
          isNot(VerificationGatewayPath.openBanking),
        );
        expect(
          layout.alternates,
          isNot(contains(VerificationGatewayPath.openBanking)),
        );
      }
    });
  });

  group('getVerificationLabel', () {
    test('student maps to university email', () {
      final label = getVerificationLabel({
        'seeker_persona': 'student',
        'dublin_location_context': 'already_in_dublin',
      });

      expect(label.pathTitle, 'I have a university email');
      expect(label.leadingEmoji, '🎓');
      expect(label.route, '/verify/id/university-email');
      expect(label.path, VerificationGatewayPath.universityEmailOtp);
    });

    test('family maps to LinkedIn without Open Banking copy', () {
      final label = getVerificationLabel({'seeker_persona': 'family'});

      expect(label.pathTitle, 'LinkedIn');
      expect(label.path, VerificationGatewayPath.linkedInCorporate);
      expect(label.description.toLowerCase(), isNot(contains('open banking')));
      expect(label.description.toLowerCase(), isNot(contains('financial accounts')));
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
      ]);
    });

    test('sessionless fallback excludes Open Banking', () {
      final alternates = alternateVerificationPaths(
        VerificationGatewayPath.linkedInCorporate,
      );
      expect(alternates, isNot(contains(VerificationGatewayPath.openBanking)));
    });
  });
}
