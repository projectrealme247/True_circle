import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'listing_creation_payload_builder.dart';

/// Persists listings to Supabase `public.listings` with local shape round-trip.
abstract final class ListingsSupabaseService {
  static const _table = 'listings';

  static bool get canWrite => AuthService.isAuthenticated;

  /// Best-effort insert into `listing_reports` for admin review sync.
  /// Returns the inserted row, or null when unauthenticated / table missing / failed.
  static Future<Map<String, dynamic>?> tryInsertListingReport(
    Map<String, dynamic> report,
  ) async {
    if (!_supabaseReadyForWrite) return null;

    try {
      final response = await AuthService.client
          .from('listing_reports')
          .insert({
            'report_type': report['report_type'] ?? 'listing',
            'listing_id': report['listing_id'],
            'reporter_id': report['reporter_id'],
            'reason': report['reason'],
            'details': report['details'] ?? '',
            'status': report['status'] ?? 'open',
            if (report['created_at'] != null)
              'created_at': report['created_at'],
          })
          .select()
          .maybeSingle();

      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('ListingsSupabaseService report insert failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('ListingsSupabaseService report insert error: $e');
      return null;
    }
  }

  static bool get _supabaseReadyForRead {
    try {
      return Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  static bool get _supabaseReadyForWrite {
    try {
      return Supabase.instance.isInitialized && canWrite;
    } catch (_) {
      return false;
    }
  }

  /// Public read of active rows. Throws when Supabase is unavailable or the query fails.
  static Future<List<Map<String, dynamic>>> fetchActiveListings() async {
    if (!_supabaseReadyForRead) {
      throw StateError('Supabase is required to load listings.');
    }

    final response =
        await AuthService.client.from(_table).select().eq('is_active', true);
    if (response is! List) {
      throw StateError('Unexpected listings response.');
    }

    return [
      for (final row in response)
        if (row is Map) _mapFetchedRow(Map<String, dynamic>.from(row)),
    ];
  }

  /// Public read of one active listing by primary key.
  ///
  /// Returns null when [id] is empty or no active row exists.
  /// Throws when Supabase is unavailable or the query fails.
  static Future<Map<String, dynamic>?> fetchListingById(String id) async {
    final listingId = id.trim();
    if (listingId.isEmpty) return null;
    if (!_supabaseReadyForRead) {
      throw StateError('Supabase is required to load listings.');
    }

    final response = await AuthService.client
        .from(_table)
        .select()
        .eq('id', listingId)
        .eq('is_active', true)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));

    if (response == null) return null;
    return _mapFetchedRow(Map<String, dynamic>.from(response));
  }

  /// Public read of published rows. Empty when Supabase is unavailable.
  static Future<List<Map<String, dynamic>>> tryFetchListings() async {
    try {
      return await fetchActiveListings();
    } catch (_) {
      return const [];
    }
  }

  /// Listings owned by the signed-in host (`listings.user_id = auth.uid()`).
  ///
  /// Throws when the query fails. Returns an empty list when the host has
  /// no remote listings.
  static Future<List<Map<String, dynamic>>> fetchOwnedByCurrentUser() async {
    if (!_supabaseReadyForWrite) {
      throw StateError('Supabase auth is required to load host listings.');
    }

    final userId = AuthService.currentUser?.id?.trim() ?? '';
    if (userId.isEmpty) {
      throw StateError('Authenticated Supabase user id is required.');
    }

    final response = await AuthService.client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 20));

    return [
      for (final row in response as List)
        if (row is Map) mapOwnedListingRow(Map<String, dynamic>.from(row)),
    ];
  }

  /// Marks an owned listing inactive. The row stays in the database.
  ///
  /// Returns false when [listingId] is not a remote UUID (local/demo id).
  /// Throws when the signed-in host cannot update the row.
  static Future<bool> deactivateOwnedListing(String listingId) async {
    if (!ListingCreationPayloadBuilder.isUuid(listingId)) return false;
    if (!_supabaseReadyForWrite) {
      throw StateError('Supabase auth is required to deactivate a listing.');
    }

    final response = await AuthService.client
        .from(_table)
        .update({'is_active': false})
        .eq('id', listingId)
        .select('id')
        .timeout(const Duration(seconds: 20));

    if (response.isEmpty) {
      throw StateError('Listing could not be deactivated.');
    }
    return true;
  }

  /// App-shaped listing whose `id` is the database UUID.
  static Map<String, dynamic> mapOwnedListingRow(Map<String, dynamic> row) {
    final mapped = _mapFetchedRow(row);
    final id = row['id']?.toString().trim() ?? '';
    final userId = row['user_id']?.toString().trim() ?? '';
    final category = row['marketplace_category']?.toString().trim() ?? '';
    if (id.isNotEmpty) mapped['id'] = id;
    if (userId.isNotEmpty) {
      mapped['user_id'] = userId;
      mapped['owner_user_id'] = userId;
    }
    if (category.isNotEmpty) mapped['marketplace_category'] = category;
    return mapped;
  }

  static Map<String, dynamic> _mapFetchedRow(Map<String, dynamic> row) {
    final mapped = ListingCreationPayloadBuilder.fromSupabaseRow(row);
    final published = mapped['published_at']?.toString().trim() ?? '';
    if (published.isEmpty) {
      final created = row['created_at']?.toString().trim() ?? '';
      if (created.isNotEmpty) {
        mapped['published_at'] = created;
      }
    }
    return mapped;
  }

  /// Inserts a listing row; returns app-shaped map or null when skipped/failed.
  static Future<Map<String, dynamic>?> tryInsertListing(
    Map<String, dynamic> local,
  ) async {
    if (!canWrite) return null;

    try {
      final row = _toSupabaseRow(local);
      final response =
          await AuthService.client.from(_table).insert(row).select().single();

      return ListingCreationPayloadBuilder.fromSupabaseRow(
        Map<String, dynamic>.from(response),
      );
    } on PostgrestException catch (e) {
      debugPrint('ListingsSupabaseService insert failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('ListingsSupabaseService insert error: $e');
      return null;
    }
  }

  /// Updates an owned listing row; returns app-shaped map or null when skipped/failed.
  static Future<Map<String, dynamic>?> tryUpdateListing(
    String listingId,
    Map<String, dynamic> local,
  ) async {
    if (!canWrite || listingId.trim().isEmpty) return null;

    try {
      final row = _toSupabaseRow(local);
      final response = await AuthService.client
          .from(_table)
          .update(row)
          .eq('id', listingId)
          .select()
          .single();

      return ListingCreationPayloadBuilder.fromSupabaseRow(
        Map<String, dynamic>.from(response),
      );
    } on PostgrestException catch (e) {
      debugPrint('ListingsSupabaseService update failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('ListingsSupabaseService update error: $e');
      return null;
    }
  }

  static Map<String, dynamic> _toSupabaseRow(Map<String, dynamic> local) {
    return ListingCreationPayloadBuilder.toSupabaseRow(
      local,
      userId: AuthService.currentUser?.id,
    );
  }
}
