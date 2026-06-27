import '../services/listing_creation_supabase_service.dart';

/// Prevents concurrent listing publish mutations (double-tap guard).
abstract final class ListingCreationSubmissionGate {
  static bool _isSubmitting = false;

  static bool get isSubmitting => _isSubmitting;

  /// Test-only reset — call via [ListingCreationController.resetSubmissionStateForTests].
  static void resetForTests() {
    _isSubmitting = false;
  }

  static Future<T> run<T>(Future<T> Function() action) async {
    if (_isSubmitting) {
      throw ListingCreationTransactionException(
        'A listing is already being published. Please wait.',
        code: ListingCreationErrorCode.duplicateSubmission,
      );
    }

    _isSubmitting = true;
    try {
      return await action();
    } finally {
      _isSubmitting = false;
    }
  }
}
