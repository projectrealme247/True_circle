import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'listing_creation_payload_builder.dart';

/// Atomic Supabase insert for Phase C listing creation.
abstract final class ListingCreationSupabaseService {
  static const _table = 'listings';

  static bool get canWrite => AuthService.isAuthenticated;

  /// Inserts a validated listing row. Throws [ListingCreationTransactionException]
  /// on failure so callers can surface errors without corrupting local state.
  static Future<Map<String, dynamic>> insertListing(
    Map<String, dynamic> localPayload,
  ) async {
    if (!canWrite) {
      throw ListingCreationTransactionException(
        'Sign in to publish a listing.',
        code: ListingCreationErrorCode.unauthenticated,
      );
    }

    final userId = AuthService.currentUser?.id;
    final row = ListingCreationPayloadBuilder.toSupabaseRow(
      localPayload,
      userId: userId,
    );

    try {
      final response = await AuthService.client
          .from(_table)
          .insert(row)
          .select()
          .single()
          .timeout(const Duration(seconds: 30));

      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('ListingCreationSupabaseService insert failed: ${e.message}');
      throw ListingCreationTransactionException(
        _messageFromPostgrest(e),
        code: ListingCreationErrorCode.database,
        cause: e,
      );
    } on ListingCreationTransactionException {
      rethrow;
    } catch (e) {
      debugPrint('ListingCreationSupabaseService insert error: $e');
      final isTimeout = e is TimeoutException;
      throw ListingCreationTransactionException(
        isTimeout
            ? 'Publishing timed out. Check your connection and try again.'
            : 'Could not publish your listing. Try again shortly.',
        code: isTimeout
            ? ListingCreationErrorCode.timeout
            : ListingCreationErrorCode.network,
        cause: e,
      );
    }
  }

  static String _messageFromPostgrest(PostgrestException e) {
    final message = e.message.trim();
    if (message.isEmpty) {
      return 'The database rejected this listing. Review your details and try again.';
    }
    if (message.toLowerCase().contains('location_geom')) {
      return 'Location could not be saved. Re-check your Eircode.';
    }
    return message;
  }
}

enum ListingCreationErrorCode {
  validation,
  eircode,
  unauthenticated,
  database,
  network,
  timeout,
  duplicateSubmission,
}

class ListingCreationTransactionException implements Exception {
  ListingCreationTransactionException(
    this.message, {
    required this.code,
    this.fieldErrors = const {},
    this.cause,
  });

  final String message;
  final ListingCreationErrorCode code;
  final Map<String, String> fieldErrors;
  final Object? cause;

  @override
  String toString() => message;
}
