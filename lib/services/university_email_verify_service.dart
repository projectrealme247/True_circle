import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../utils/irish_university_domains.dart';

/// Thrown when send/verify fails with a user-facing message.
class UniversityEmailVerifyException implements Exception {
  UniversityEmailVerifyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// University email OTP via Supabase Edge Function + Resend.
///
/// Set [UNI_OTP_MOCK]=true in env.dev.json for local dev without Resend.
abstract final class UniversityEmailVerifyService {
  static const _functionName = 'university-email-otp';
  static const _useMock = bool.fromEnvironment('UNI_OTP_MOCK', defaultValue: false);

  static String? _pendingEmail;
  static String? _mockOtp;
  static DateTime? _mockExpiresAt;

  static bool get usesMockBackend => _useMock;

  /// Sends OTP to [email]. Requires signed-in Supabase session unless mock.
  static Future<void> sendOtp(String email) async {
    if (!IrishUniversityDomains.isAllowedUniversityEmail(email)) {
      throw UniversityEmailVerifyException(
        'Use your college email ending in .ac.ie or a known university domain.',
      );
    }

    final normalized = email.trim().toLowerCase();
    _pendingEmail = normalized;

    if (_useMock) {
      await _sendOtpMock(normalized);
      return;
    }

    if (!AuthService.isAuthenticated) {
      throw UniversityEmailVerifyException(
        'Sign in first, then verify your college email.',
      );
    }

    try {
      final response = await AuthService.client.functions.invoke(
        _functionName,
        body: {'action': 'send', 'email': normalized},
      );

      final data = _responseMap(response);
      if (data['ok'] == true) return;

      throw UniversityEmailVerifyException(
        _errorFromResponse(data, response.status),
      );
    } on UniversityEmailVerifyException {
      rethrow;
    } on FunctionException catch (e) {
      throw UniversityEmailVerifyException(_messageFromFunctionException(e));
    } catch (e) {
      debugPrint('TrueCircle uni OTP send failed: $e');
      throw UniversityEmailVerifyException(
        'Could not send verification email. Try again shortly.',
      );
    }
  }

  /// Debug OTP only when mock backend is active.
  static String? debugOtpHint() =>
      _useMock && kDebugMode ? _mockOtp : null;

  static String? pendingEmail() => _pendingEmail;

  /// Validates OTP via Edge Function (or mock store).
  static Future<bool> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final normalized = email.trim().toLowerCase();

    if (_useMock) {
      return _verifyOtpMock(email: normalized, otp: otp);
    }

    if (!AuthService.isAuthenticated) {
      throw UniversityEmailVerifyException('Sign in required.');
    }

    try {
      final response = await AuthService.client.functions.invoke(
        _functionName,
        body: {
          'action': 'verify',
          'email': normalized,
          'code': otp.trim(),
        },
      );

      final data = _responseMap(response);
      if (data['verified'] == true) {
        _pendingEmail = normalized;
        return true;
      }

      throw UniversityEmailVerifyException(
        _errorFromResponse(data, response.status),
      );
    } on UniversityEmailVerifyException {
      rethrow;
    } on FunctionException catch (e) {
      throw UniversityEmailVerifyException(_messageFromFunctionException(e));
    } catch (e) {
      debugPrint('TrueCircle uni OTP verify failed: $e');
      throw UniversityEmailVerifyException(
        'Could not verify code. Try again.',
      );
    }
  }

  static void clearPending() {
    _pendingEmail = null;
    _mockOtp = null;
    _mockExpiresAt = null;
  }

  static Future<void> _sendOtpMock(String normalized) async {
    _mockOtp = _generateOtp();
    _mockExpiresAt = DateTime.now().add(const Duration(minutes: 10));
    await Future.delayed(const Duration(milliseconds: 400));
    if (kDebugMode) {
      debugPrint('TrueCircle uni email OTP (mock) for $normalized: $_mockOtp');
    }
  }

  static bool _verifyOtpMock({required String email, required String otp}) {
    if (_pendingEmail != email) return false;
    if (_mockExpiresAt == null || DateTime.now().isAfter(_mockExpiresAt!)) {
      return false;
    }
    return otp.trim() == _mockOtp;
  }

  static String _generateOtp() {
    final n = DateTime.now().millisecondsSinceEpoch % 900000 + 100000;
    return n.toString();
  }

  static Map<String, dynamic> _responseMap(FunctionResponse response) {
    final raw = response.data;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }

  static String _errorFromResponse(Map<String, dynamic> data, int status) {
    final error = data['error']?.toString().trim();
    if (error != null && error.isNotEmpty) return error;
    if (status == 401) return 'Sign in required.';
    if (status == 429) return 'Too many attempts. Wait and try again.';
    if (status == 502) {
      return 'Email service unavailable. Check Resend configuration.';
    }
    return 'Verification failed. Try again.';
  }

  static String _messageFromFunctionException(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      final error = details['error']?.toString().trim();
      if (error != null && error.isNotEmpty) return error;
    }
    if (e.status == 401) return 'Sign in required.';
    if (e.status == 404) {
      return 'Verification service not deployed. Run: supabase functions deploy university-email-otp';
    }
    return e.reasonPhrase?.isNotEmpty == true
        ? e.reasonPhrase!
        : 'Verification service error (${e.status}).';
  }
}
