import '../utils/profile_data.dart';

/// Student financial-support selection (Phase 4).
///
/// Persisted as [storageKey]. Legacy sessions may still carry [legacyStorageKey].
abstract final class FinancialSupportType {
  FinancialSupportType._();

  static const storageKey = 'financial_support_type';
  static const legacyStorageKey = 'student_type';

  static const familySupported = 'Family supported';
  static const educationLoan = 'Education loan';
  static const selfFunded = 'Self funded';

  /// Canonical Dublin Phase 4 options (UI + storage values).
  static const canonicalOptions = <String>[
    familySupported,
    educationLoan,
    selfFunded,
  ];

  /// Maps legacy / market labels onto canonical values; returns null if unknown.
  static String? normalize(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    if (canonicalOptions.contains(text)) return text;
    // Legacy market label.
    if (text == 'Education loan (bank financed)') return educationLoan;
    return null;
  }

  /// Prefer new key; fall back to legacy [student_type].
  static String? fromSession(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) return null;
    return normalize(ProfileData.text(session[storageKey])) ??
        normalize(ProfileData.text(session[legacyStorageKey]));
  }
}
