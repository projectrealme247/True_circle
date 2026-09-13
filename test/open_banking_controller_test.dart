import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:true_circle/controllers/open_banking_controller.dart';
import 'package:true_circle/screens/auth_screen.dart';
import 'package:true_circle/services/open_banking_provider.dart';
import 'package:true_circle/services/trust_service.dart';
import 'package:true_circle/utils/open_banking_liquidity_validator.dart';
import 'package:true_circle/utils/profile_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthScreen.currentUserSession = {
      'full_name': 'Priya Sharma',
      'budget_min': 1400,
    };
  });

  group('ProfileData.identityAnchorMatches', () {
    test('matches bank KYC holder to profile full name', () {
      expect(
        ProfileData.identityAnchorMatches('Priya Sharma', 'MS PRIYA SHARMA'),
        isTrue,
      );
      expect(
        ProfileData.identityAnchorMatches('Priya Sharma', 'Alex Murphy'),
        isFalse,
      );
    });
  });

  group('OpenBankingLiquidityValidator', () {
    test('accepts recurring salary above floor', () {
      expect(
        OpenBankingLiquidityValidator.meetsPlatformCapability(
          currentBalanceEur: 500,
          recurringSalaryDetected: true,
          monthlySalaryEur: 3200,
        ),
        isTrue,
      );
    });

    test('accepts balance when salary not detected', () {
      expect(
        OpenBankingLiquidityValidator.meetsPlatformCapability(
          currentBalanceEur: 2500,
          recurringSalaryDetected: false,
        ),
        isTrue,
      );
    });
  });

  group('OpenBankingController.evaluateAisSnapshot', () {
    test('returns Grand result when identity and liquidity pass', () {
      final result = OpenBankingController.evaluateAisSnapshot(
        snapshot: const OpenBankingAisSnapshot(
          accountHolderName: 'Priya Sharma',
          currentBalanceEur: 3500,
          recurringSalaryDetected: true,
          monthlySalaryEur: 3200,
          institution: IrishOpenBankInstitution.aib,
        ),
        profileFullName: 'Priya Sharma',
        userBudgetMinEur: 1400,
      );

      expect(result.trustTier, 'Grand');
      expect(result.verificationTrack, 'Open Banking Track');
    });

    test('throws when holder name mismatches profile', () {
      expect(
        () => OpenBankingController.evaluateAisSnapshot(
          snapshot: const OpenBankingAisSnapshot(
            accountHolderName: 'Alex Murphy',
            currentBalanceEur: 3500,
            recurringSalaryDetected: true,
            monthlySalaryEur: 3200,
          ),
          profileFullName: 'Priya Sharma',
        ),
        throwsA(isA<OpenBankingException>()),
      );
    });
  });

  group('TrustService.upgradeOpenBanking', () {
    test('sets financial metadata without trust_tier', () async {
      await TrustService.upgradeOpenBanking(
        verificationSeal: 'sealed-ob',
        verifiedAt: '2026-06-11',
        institutionLabel: 'AIB',
      );

      final session = AuthScreen.currentUserSession!;
      expect(session.containsKey('trust_tier'), isFalse);
      expect(session.containsKey('trust_stage'), isFalse);
      expect(session.containsKey('identity_trust_tier'), isFalse);
      expect(session['financial_verified'], isTrue);
      expect(session['verification_track'], 'Open Banking Track');
      expect(session['open_banking_institution'], 'AIB');
    });
  });
}
