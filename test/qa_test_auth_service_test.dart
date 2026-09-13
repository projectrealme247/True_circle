import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/models/onboarding_user_role.dart';
import 'package:true_circle/services/profile_storage_service.dart';
import 'package:true_circle/services/qa_test_auth_service.dart';
import 'package:true_circle/services/trust_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults lock identity, role, and marketplace space', () {
    final independentHost =
        QaTestAuthService.defaultsFor(QaTestAccount.landlordIndependent);
    expect(independentHost['email'], 'landlord.independent@truecircle.qa');
    expect(independentHost['supabase_user_id'], 'qa-landlord-independent-uuid');
    expect(independentHost['role'], UserRole.landlord.storageToken);
    expect(independentHost['qa_mode'], isTrue);
    expect(independentHost['demo_mode'], isTrue);
    expect(
      independentHost['active_marketplace_space'],
      MarketplaceSpace.fullRental.storageToken,
    );
    expect(independentHost['host_profile_complete'], isTrue);
    expect(independentHost['linkedin_verified'], isTrue);

    final sharedSeeker =
        QaTestAuthService.defaultsFor(QaTestAccount.seekerShared);
    expect(sharedSeeker['role'], UserRole.seeker.storageToken);
    expect(sharedSeeker['occupant_type'], 'student');
    expect(sharedSeeker['light_trust_verified'], isTrue);
    expect(
      sharedSeeker['active_marketplace_space'],
      MarketplaceSpace.sharedSpace.storageToken,
    );
  });

  test('merge restores same-account edits and ignores other identities', () {
    final prior = {
      ...QaTestAuthService.defaultsFor(QaTestAccount.seekerIndependent),
      'budget_max': 3200,
      'full_name': 'Edited Independent Seeker',
    };
    final merged = QaTestAuthService.mergeAccountSession(
      QaTestAccount.seekerIndependent,
      prior,
    );
    expect(merged['budget_max'], 3200);
    expect(merged['full_name'], 'Edited Independent Seeker');
    expect(merged['supabase_user_id'], 'qa-seeker-independent-uuid');
    expect(merged['qa_mode'], isTrue);

    final crossed = QaTestAuthService.mergeAccountSession(
      QaTestAccount.seekerIndependent,
      QaTestAuthService.defaultsFor(QaTestAccount.landlordShared),
    );
    expect(crossed['supabase_user_id'], 'qa-seeker-independent-uuid');
    expect(crossed['role'], UserRole.seeker.storageToken);
    expect(crossed['budget_max'], 2800);
  });

  test('QA sessions disable mock host listings', () {
    expect(
      QaTestAuthService.allowMockHostListings(
        QaTestAuthService.defaultsFor(QaTestAccount.landlordIndependent),
      ),
      isFalse,
    );
    expect(QaTestAuthService.allowMockHostListings({'demo_mode': true}), isTrue);
    expect(QaTestAuthService.allowMockHostListings(null), isTrue);
  });

  test('named slot survives current-profile clear', () async {
    final account = QaTestAccount.landlordShared;
    final session = QaTestAuthService.defaultsFor(account);
    await ProfileStorageService.save(session);
    await ProfileStorageService.saveSlot(account.slotKey, session);
    await ProfileStorageService.clear();

    expect(await ProfileStorageService.load(), isNull);
    final slot = await ProfileStorageService.loadSlot(account.slotKey);
    expect(slot?['supabase_user_id'], account.userId);
    expect(slot?['email'], account.email);
  });

  test('QA seekers meet contact verification', () {
    expect(
      TrustService.meetsContactVerification(
        QaTestAuthService.defaultsFor(QaTestAccount.seekerIndependent),
      ),
      isTrue,
    );
    expect(
      TrustService.meetsContactVerification(
        QaTestAuthService.defaultsFor(QaTestAccount.seekerShared),
      ),
      isTrue,
    );
  });
}
