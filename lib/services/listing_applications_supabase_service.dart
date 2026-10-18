import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/marketplace_space.dart';
import '../utils/numeric_bounds.dart';
import 'auth_service.dart';

/// Remote create/read for `listing_applications`.
abstract final class ListingApplicationsSupabaseService {
  static const table = 'listing_applications';

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool get isReady {
    try {
      return Supabase.instance.isInitialized && AuthService.isAuthenticated;
    } catch (_) {
      return false;
    }
  }

  static bool isRemoteId(String applicationId) =>
      _uuidPattern.hasMatch(applicationId.trim());

  /// Host (or applicant) rows for a listing — RLS filters visibility.
  static Future<List<Map<String, dynamic>>> fetchForListing(
    String listingId,
  ) async {
    if (listingId.trim().isEmpty) return const [];

    final response = await AuthService.client
        .from(table)
        .select()
        .eq('listing_id', listingId)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 20));

    return [
      for (final row in response as List)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  /// Signed-in seeker's applications. RLS still limits rows to this user.
  static Future<List<Map<String, dynamic>>> fetchForCurrentApplicant() async {
    final applicantUserId = AuthService.currentUser?.id?.trim() ?? '';
    if (applicantUserId.isEmpty) {
      throw StateError('Authenticated Supabase user id is required.');
    }

    final response = await AuthService.client
        .from(table)
        .select()
        .eq('applicant_user_id', applicantUserId)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 20));

    return [
      for (final row in response as List)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  /// Inserts one application (DB UUID). Returns existing row if already applied.
  static Future<Map<String, dynamic>> submit({
    required String listingId,
    required Map<String, dynamic> session,
    required MarketplaceSpace space,
    required int compatibilityScore,
  }) async {
    if (listingId.trim().isEmpty) {
      throw ArgumentError.value(listingId, 'listingId', 'must not be empty');
    }

    final applicantUserId = AuthService.currentUser?.id?.trim() ?? '';
    if (applicantUserId.isEmpty) {
      throw StateError('Authenticated Supabase user id is required.');
    }

    final existing = await fetchForListingUser(
      listingId: listingId,
      applicantUserId: applicantUserId,
    );
    if (existing != null) return existing;

    final insertRow = <String, dynamic>{
      'listing_id': listingId,
      'applicant_user_id': applicantUserId,
      'space': space.storageToken,
      'status': 'pending',
      'compatibility_score': NumericBounds.clampPercentInt(compatibilityScore),
      'payload': Map<String, dynamic>.from(session),
    };

    try {
      final response = await AuthService.client
          .from(table)
          .insert(insertRow)
          .select()
          .single()
          .timeout(const Duration(seconds: 20));
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      // Unique (listing_id, applicant_user_id) — return the existing row.
      if (e.code == '23505') {
        final raced = await fetchForListingUser(
          listingId: listingId,
          applicantUserId: applicantUserId,
        );
        if (raced != null) return raced;
      }
      debugPrint(
        'ListingApplicationsSupabaseService submit failed: ${e.message}',
      );
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> fetchForListingUser({
    required String listingId,
    required String applicantUserId,
  }) async {
    if (listingId.isEmpty || applicantUserId.isEmpty) return null;

    final row = await AuthService.client
        .from(table)
        .select()
        .eq('listing_id', listingId)
        .eq('applicant_user_id', applicantUserId)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));

    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }
}
