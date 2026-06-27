import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

import '../models/listing_creation_category.dart';
import '../models/listing_creation_draft.dart';
import '../models/listing_creation_field_keys.dart';
import '../services/eircode_geocoding_service.dart';
import '../services/listing_creation_payload_builder.dart';
import '../services/listing_creation_submission_gate.dart';
import '../services/listing_creation_supabase_service.dart';
import '../services/listing_creation_validation_service.dart';
import '../services/trust_service.dart';

export '../services/listing_creation_submission_gate.dart'
    show ListingCreationSubmissionGate;
export '../services/listing_creation_supabase_service.dart'
    show
        ListingCreationErrorCode,
        ListingCreationTransactionException;
export '../services/eircode_geocoding_service.dart'
    show EircodeValidationException;

/// Injectable Supabase insert for tests and alternate backends.
typedef ListingCreationInsertFn = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> localPayload,
);

/// Phase C Step 2 — listing creation validation + Supabase transaction controller.
abstract final class ListingCreationController {
  /// True while [publish] is in-flight (blocks duplicate submissions).
  static bool get isSubmitting => ListingCreationSubmissionGate.isSubmitting;

  @visibleForTesting
  static void resetSubmissionStateForTests() {
    ListingCreationSubmissionGate.resetForTests();
  }

  /// Category toggle with defensive wipe of opposite-space cached fields.
  static ListingCreationDraft onCategoryChanged(
    ListingCreationDraft current,
    ListingCreationCategory next,
  ) {
    return current.withCategory(next);
  }

  /// Validates draft fields before geocoding or insert.
  static Map<String, String> validate(ListingCreationDraft draft) {
    return ListingCreationValidationService.validate(draft);
  }

  /// Resolves Eircode → coordinates and returns an updated draft.
  static Future<ListingCreationDraft> resolveEircode(
    ListingCreationDraft draft, {
    Future<List<Location>> Function(String query)? geocodeForTests,
  }) async {
    final fieldErrors = validate(draft);
    if (fieldErrors.containsKey(ListingCreationFieldKeys.eircode)) {
      throw ListingCreationTransactionException(
        fieldErrors[ListingCreationFieldKeys.eircode]!,
        code: ListingCreationErrorCode.eircode,
        fieldErrors: fieldErrors,
      );
    }

    try {
      final coords = await EircodeGeocodingService.resolveCoordinates(
        draft.eircode,
        geocode: geocodeForTests,
      );
      return draft.withCoordinates(
        latitude: coords.latitude,
        longitude: coords.longitude,
      );
    } on EircodeValidationException catch (e) {
      throw ListingCreationTransactionException(
        e.message,
        code: ListingCreationErrorCode.eircode,
        fieldErrors: {ListingCreationFieldKeys.eircode: e.message},
      );
    }
  }

  /// Builds a sanitized local listing map (no deprecated kitchen utility keys).
  static Map<String, dynamic> buildLocalPayload(ListingCreationDraft draft) {
    return ListingCreationPayloadBuilder.toLocalListingMap(draft);
  }

  /// End-to-end publish: validate → geocode → trust stamp → Supabase insert.
  static Future<ListingCreationPublishResult> publish(
    ListingCreationDraft draft, {
    Future<List<Location>> Function(String query)? geocodeForTests,
    ListingCreationInsertFn? insertOverride,
  }) {
    return ListingCreationSubmissionGate.run(() async {
      final fieldErrors = validate(draft);
      if (fieldErrors.isNotEmpty) {
        throw ListingCreationTransactionException(
          'Fix the highlighted fields before publishing.',
          code: ListingCreationErrorCode.validation,
          fieldErrors: fieldErrors,
        );
      }

      var resolved = draft.hasResolvedCoordinates
          ? draft
          : await resolveEircode(draft, geocodeForTests: geocodeForTests);

      final local = buildLocalPayload(resolved);
      final stamped = Map<String, dynamic>.from(local);
      TrustService.stampListingTrust(stamped);

      final inserted = insertOverride != null
          ? await insertOverride(stamped)
          : await ListingCreationSupabaseService.insertListing(stamped);

      return ListingCreationPublishResult(
        listingId: inserted['id']?.toString() ?? '',
        supabaseRow: inserted,
        localListing: stamped,
      );
    });
  }
}

class ListingCreationPublishResult {
  const ListingCreationPublishResult({
    required this.listingId,
    required this.supabaseRow,
    required this.localListing,
  });

  final String listingId;
  final Map<String, dynamic> supabaseRow;
  final Map<String, dynamic> localListing;
}
