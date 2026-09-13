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
            if (report['created_at'] != null) 'created_at': report['created_at'],
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

  static bool get _supabaseReadyForWrite {
    try {
      return Supabase.instance.isInitialized && canWrite;
    } catch (_) {
      return false;
    }
  }

  /// Inserts a listing row; returns app-shaped map or null when skipped/failed.
  static Future<Map<String, dynamic>?> tryInsertListing(
    Map<String, dynamic> local,
  ) async {
    if (!canWrite) return null;

    try {
      final row = _toSupabaseRow(local);
      final response = await AuthService.client
          .from(_table)
          .insert(row)
          .select()
          .single();

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
