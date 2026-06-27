import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Wraps [LocalAuthentication] for TrueCircle device identity checks.
class BiometricService {
  BiometricService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  static const _authReason = 'Please authenticate to access TrueCircle';

  /// Returns whether this device can use biometric security (Face ID, fingerprint, etc.).
  Future<bool> checkBiometricsSupported() async {
    if (kIsWeb) return false;

    try {
      final deviceSupported = await _localAuth.isDeviceSupported();
      if (!deviceSupported) return false;

      final canCheck = await _localAuth.canCheckBiometrics;
      final types = await _localAuth.getAvailableBiometrics();
      return canCheck || types.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Shows the native biometric prompt. Returns [true] on success, [false] otherwise.
  Future<bool> authenticateUser() async {
    try {
      if (!await checkBiometricsSupported()) return false;

      return await _localAuth.authenticate(
        localizedReason: _authReason,
        biometricOnly: true,
      );
    } on PlatformException {
      return false;
    }
  }
}
