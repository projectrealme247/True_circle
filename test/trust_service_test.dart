import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:true_circle/screens/auth_screen.dart';
import 'package:true_circle/services/invite_code_service.dart';
import 'package:true_circle/services/trust_service.dart';
import 'package:true_circle/utils/irish_university_domains.dart';

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
    test('upgradeLightTrust unlocks contact via university flags', () async {
      AuthScreen.currentUserSession = {
        'occupant_type': 'Students',
      };

      await TrustService.upgradeLightTrust(
        method: 'university_email',
        verifiedEmail: 'student@ucdconnect.ie',
      );

      final session = AuthScreen.currentUserSession!;
      expect(session.containsKey('trust_stage'), isFalse);
      expect(session.containsKey('identity_trust_tier'), isFalse);
      expect(session['light_trust_verified'], isTrue);
      expect(TrustService.canContact(), isTrue);
      expect(session['verified_university_email'], contains('@'));
    });

    test('declaration unlocks pre-arrival contact', () async {
      AuthScreen.currentUserSession = {
        'occupant_type': 'Students',
      };

      await TrustService.submitPreArrivalStudentDeclaration();

      expect(TrustService.preArrivalContactReady(), isTrue);
      expect(TrustService.canContact(), isTrue);
      expect(
        AuthScreen.currentUserSession!['pre_arrival_student'],
        isTrue,
      );
      expect(
        AuthScreen.currentUserSession!.containsKey('invite_code_verified'),
        isFalse,
      );
      expect(
        AuthScreen.currentUserSession!.containsKey('onboarding_letter_verified'),
        isFalse,
      );
    });

    test('legacy invite plus letter still unlocks contact', () async {
      AuthScreen.currentUserSession = {
        'occupant_type': 'Students',
        'invite_code_verified': true,
        'onboarding_letter_verified': true,
      };

      expect(TrustService.preArrivalContactReady(), isTrue);
      expect(TrustService.canContact(), isTrue);
    });

    test('upgradeLightTrust clears pre-arrival flags', () async {
      AuthScreen.currentUserSession = {
        'invite_code_verified': true,
        'onboarding_letter_verified': true,
        'pre_arrival_contact_ready': true,
      };

      await TrustService.upgradeLightTrust(
        method: 'university_email',
        verifiedEmail: 'student@tcd.ie',
      );

      expect(AuthScreen.currentUserSession!['pre_arrival_contact_ready'], isNull);
      expect(AuthScreen.currentUserSession!['pre_arrival_student'], isNull);
      expect(
        AuthScreen.currentUserSession!.containsKey('trust_stage'),
        isFalse,
      );
    });

    test('upgradeCorporateDocument sets employment flags without trust fields', () async {
      AuthScreen.currentUserSession = {
        'full_name': 'Priya Sharma',
      };

      await TrustService.upgradeCorporateDocument(
        verificationSeal: 'sealed-mock',
        verifiedAt: '2026-06-11',
      );

      final session = AuthScreen.currentUserSession!;
      expect(session.containsKey('trust_tier'), isFalse);
      expect(session.containsKey('trust_stage'), isFalse);
      expect(session.containsKey('identity_trust_tier'), isFalse);
      expect(session['employment_verified'], isTrue);
      expect(session['verification_track'], 'Corporate Track');
    });

    test('stampListingTrust sets pre-arrival badge without host trust fields', () {
      AuthScreen.currentUserSession = {
        'invite_code_verified': true,
        'onboarding_letter_verified': true,
        'pre_arrival_contact_ready': true,
      };

      final stamped = TrustService.stampListingTrust({'title': 'Room'});
      expect(stamped['host_pre_arrival_badge'], isTrue);
      expect(stamped.containsKey('host_trust_stage'), isFalse);
      expect(stamped.containsKey('host_trust_multiplier'), isFalse);
      expect(stamped.containsKey('host_verified_badge'), isFalse);
    });

    test('stampListingTrust pre-arrival badge ignores trust_stage', () {
      AuthScreen.currentUserSession = {
        'trust_stage': 3,
        'invite_code_verified': true,
        'onboarding_letter_verified': true,
        'pre_arrival_contact_ready': true,
      };

      final stamped = TrustService.stampListingTrust({'title': 'Room'});
      expect(stamped['host_pre_arrival_badge'], isTrue);
    });
  });

  group('InviteCodeService', () {
    test('generate and list codes for university-verified user', () async {
      AuthScreen.currentUserSession = {
        'light_trust_verified': true,
        'verified_university_email': 'a***@ucd.ie',
        'email': 'host@example.com',
      };

      final code = await InviteCodeService.generateForCurrentUser();
      expect(code, startsWith('CK-'));

      final listed = await InviteCodeService.listForCurrentUser();
      expect(listed.length, 1);
      expect(listed.first.code, code);
      expect(listed.first.remaining, InviteCodeService.maxRedemptionsPerCode);
    });

    test('stage alone does not allow minting invite codes', () async {
      AuthScreen.currentUserSession = {
        'trust_stage': 3,
        'email': 'host@example.com',
      };

      expect(InviteCodeService.canMintInviteCodes(), isFalse);
      expect(
        () => InviteCodeService.generateForCurrentUser(),
        throwsA(isA<StateError>()),
      );
      expect(await InviteCodeService.listForCurrentUser(), isEmpty);
    });
  });
}
