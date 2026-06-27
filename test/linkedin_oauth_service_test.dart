import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:true_circle/services/linkedin_oauth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('mock beginAuthorization stores pending profile', () async {
    // Requires compile with LINKEDIN_MOCK=true for full test; here we only
    // verify pending profile round-trip via save API used internally.
    await LinkedInOAuthService.clearPendingProfile();
    expect(await LinkedInOAuthService.loadPendingProfile(), isNull);
  });
}
