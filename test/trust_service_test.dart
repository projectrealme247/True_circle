import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:true_circle/screens/auth_screen.dart';
import 'package:true_circle/services/invite_code_service.dart';
import 'package:true_circle/services/trust_service.dart';
import 'package:true_circle/utils/irish_university_domains.dart';
import 'package:true_circle/utils/viewer_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthScreen.currentUserSession = null;
  });

  group('IrishUniversityDomains', () {
    test('allows .ac.ie emails', () {
      expect(IrishUniversityDomains.isAllowedUniversityEmail('a@student.ucd.ie'), isTrue);
      expect(IrishUniversityDomains.isAllowedUniversityEmail('b@mydit.ac.ie'), isTrue);
    });

    test('allows known university hosts', () {
      expect(IrishUniversityDomains.isAllowedUniversityEmail('x@ucdconnect.ie'), isTrue);
      expect(IrishUniversityDomains.isAllowedUniversityEmail('x@tcd.ie'), isTrue);
    });

    test('rejects personal email', () {
      expect(IrishUniversityDomains.isAllowedUniversityEmail('x@gmail.com'), isFalse);
    });
  });

  group('TrustService Dublin two-track', () {
    test('Stage 3 via upgradeLightTrust unlocks contact', () async {
      AuthScreen.currentUserSession = {
        'trust_stage': TrustStage.socialVerified.level,
      };

      await TrustService.upgradeLightTrust(
        method: 'university_email',
        verifiedEmail: 'student@ucdconnect.ie',
      );

      expect(TrustService.currentStage(), TrustStage.idVerified);
      expect(TrustService.canContact(), isTrue);
      expect(
        AuthScreen.currentUserSession!['verified_university_email'],
        contains('@'),
      );
    });

    test('Track B invite only does not unlock contact', () async {
      AuthScreen.currentUserSession = {
        'trust_stage': TrustStage.socialVerified.level,
      };

      await TrustService.completeInviteCodeRedemption(
        code: 'CK-TEST',
        invitedByUserId: 'host-1',
      );

      expect(TrustService.currentStage(), TrustStage.socialVerified);
      expect(TrustService.preArrivalContactReady(), isFalse);
      expect(TrustService.canContact(), isFalse);
    });

    test('Track B invite plus letter unlocks contact at Stage 2', () async {
      AuthScreen.currentUserSession = {
        'trust_stage': TrustStage.socialVerified.level,
      };

      await TrustService.completeInviteCodeRedemption(
        code: 'CK-TEST',
        invitedByUserId: 'host-1',
      );
      await TrustService.submitOnboardingLetter(localPath: 'offer.pdf');

      expect(TrustService.currentStage(), TrustStage.socialVerified);
      expect(TrustService.preArrivalContactReady(), isTrue);
      expect(TrustService.canContact(), isTrue);
    });

    test('upgradeLightTrust clears pre-arrival flags', () async {
      AuthScreen.currentUserSession = {
        'trust_stage': TrustStage.socialVerified.level,
        'invite_code_verified': true,
        'onboarding_letter_verified': true,
        'pre_arrival_contact_ready': true,
      };

      await TrustService.upgradeLightTrust(
        method: 'university_email',
        verifiedEmail: 'student@tcd.ie',
      );

      expect(AuthScreen.currentUserSession!['pre_arrival_contact_ready'], isNull);
      expect(TrustService.currentStage(), TrustStage.idVerified);
    });

    test('upgradeCorporateDocument sets Grand tier metadata', () async {
      AuthScreen.currentUserSession = {
        'full_name': 'Priya Sharma',
        'trust_stage': TrustStage.casual.level,
      };

      await TrustService.upgradeCorporateDocument(
        verificationSeal: 'sealed-mock',
        verifiedAt: '2026-06-11',
      );

      final session = AuthScreen.currentUserSession!;
      expect(session['trust_tier'], 'Grand');
      expect(session['employment_verified'], isTrue);
      expect(session['verification_track'], 'Corporate Track');
      expect(TrustService.currentStage(), TrustStage.socialVerified);
    });

    test('stampListingTrust sets pre-arrival badge', () {
      AuthScreen.currentUserSession = {
        'trust_stage': TrustStage.socialVerified.level,
        'invite_code_verified': true,
        'onboarding_letter_verified': true,
        'pre_arrival_contact_ready': true,
      };

      final stamped = TrustService.stampListingTrust({'title': 'Room'});
      expect(stamped['host_pre_arrival_badge'], isTrue);
      expect(stamped['host_verified_badge'], isFalse);
      expect(stamped['host_trust_multiplier'], 0.9);
    });
  });

  group('InviteCodeService', () {
    test('generate and list codes for Stage 3 user', () async {
      AuthScreen.currentUserSession = {
        'trust_stage': TrustStage.idVerified.level,
        'email': 'host@example.com',
      };

      final code = await InviteCodeService.generateForCurrentUser();
      expect(code, startsWith('CK-'));

      final listed = await InviteCodeService.listForCurrentUser();
      expect(listed.length, 1);
      expect(listed.first.code, code);
      expect(listed.first.remaining, InviteCodeService.maxRedemptionsPerCode);
    });
  });
}
