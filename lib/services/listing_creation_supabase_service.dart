import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'listing_creation_payload_builder.dart';
import 'listing_creation_validation_service.dart';
import 'listing_image_storage_service.dart';

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

    _assertRemotePublishAllowed(localPayload);

    final userId = AuthService.currentUser?.id;
    final row = ListingCreationPayloadBuilder.toSupabaseRow(
      localPayload,
      userId: userId,
    )
      ..removeWhere((key, _) => key == 'id')
      ..remove('image_urls');

    try {
      final response = await AuthService.client
          .from(_table)
          .insert(row)
          .select()
          .single()
          .timeout(const Duration(seconds: 30));

      final inserted = _requireUuidRow(response);
      return _attachUploadedImages(inserted, localPayload);
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

  static Future<Map<String, dynamic>> updateListing(
    String listingId,
    Map<String, dynamic> localPayload,
  ) async {
    if (!canWrite) {
      throw ListingCreationTransactionException(
        'Sign in to publish a listing.',
        code: ListingCreationErrorCode.unauthenticated,
      );
    }
    if (!ListingCreationPayloadBuilder.isUuid(listingId)) {
      throw ListingCreationTransactionException(
        'This listing cannot be updated remotely until it has a UUID id.',
        code: ListingCreationErrorCode.invalidRemoteId,
      );
    }

    _assertRemotePublishAllowed(localPayload);

    final userId = AuthService.currentUser?.id;
    final row = ListingCreationPayloadBuilder.toSupabaseRow(
      localPayload,
      userId: userId,
    )
      ..remove('id')
      ..remove('image_urls');

    try {
      final response = await AuthService.client
          .from(_table)
          .update(row)
          .eq('id', listingId)
          .select()
          .single()
          .timeout(const Duration(seconds: 30));

      final updated = _requireUuidRow(response);
      return _attachUploadedImages(updated, localPayload);
    } on PostgrestException catch (e) {
      debugPrint('ListingCreationSupabaseService update failed: ${e.message}');
      throw ListingCreationTransactionException(
        _messageFromPostgrest(e),
        code: ListingCreationErrorCode.database,
        cause: e,
      );
    } on ListingCreationTransactionException {
      rethrow;
    } catch (e) {
      debugPrint('ListingCreationSupabaseService update error: $e');
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

  static void _assertRemotePublishAllowed(Map<String, dynamic> localPayload) {
    final fieldErrors =
        ListingCreationValidationService.validateRemotePublishPayload(
      localPayload,
    );
    if (fieldErrors.isNotEmpty) {
      throw ListingCreationTransactionException(
        fieldErrors.values.first,
        code: ListingCreationErrorCode.validation,
        fieldErrors: fieldErrors,
      );
    }
  }

  static Map<String, dynamic> _requireUuidRow(dynamic response) {
    final mapped = ListingCreationPayloadBuilder.fromSupabaseRow(
      Map<String, dynamic>.from(response as Map),
    );
    final id = mapped['id']?.toString();
    if (!ListingCreationPayloadBuilder.isUuid(id)) {
      throw ListingCreationTransactionException(
        'Remote listing did not return a UUID id.',
        code: ListingCreationErrorCode.invalidRemoteId,
      );
    }
    return mapped;
  }

  static Future<Map<String, dynamic>> _attachUploadedImages(
    Map<String, dynamic> remoteListing,
    Map<String, dynamic> localPayload,
  ) async {
    final listingId = remoteListing['id']?.toString() ?? '';
    final List<String> urls;
    try {
      urls = await ListingImageStorageService.uploadListingImages(
        listingId: listingId,
        images: localPayload['images'],
      );
    } on ListingImageUploadException catch (e) {
      throw ListingCreationTransactionException(
        e.message,
        code: ListingCreationErrorCode.network,
        cause: e.cause ?? e,
      );
    }
    if (urls.isEmpty) return remoteListing;

    try {
      final response = await AuthService.client
          .from(_table)
          .update({'image_urls': urls})
          .eq('id', listingId)
          .select()
          .single()
          .timeout(const Duration(seconds: 30));
      return _requireUuidRow(response);
    } on PostgrestException catch (e) {
      debugPrint(
        'ListingCreationSupabaseService image_urls update failed: ${e.message}',
      );
      throw ListingCreationTransactionException(
        'Listing was saved but photos could not be stored. Try editing the listing.',
        code: ListingCreationErrorCode.database,
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
  invalidRemoteId,
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
