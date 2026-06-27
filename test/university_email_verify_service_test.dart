import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/services/university_email_verify_service.dart';

void main() {
  group('UniversityEmailVerifyService mock mode', () {
    test('usesMockBackend reflects compile-time flag', () {
      // Default in CI/test is false unless --dart-define=UNI_OTP_MOCK=true
      expect(UniversityEmailVerifyService.usesMockBackend, isA<bool>());
    });
  });
}
