import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/high_signal_match.dart';
import '../services/auth_service.dart';

/// Data-layer access to seeker profile signals used by host dashboards.
abstract final class TenantProfileRepository {
  /// High-signal applicant matches for a listing (transit + lifestyle composite).
  static Future<List<HighSignalMatch>> getHighSignalMatches(
    String targetListingId,
  ) async {
    if (!AuthService.isAuthenticated) return const [];
    if (targetListingId.trim().isEmpty) return const [];

    try {
      final response = await AuthService.client
          .rpc(
            'get_high_signal_matches',
            params: {'target_listing_id': targetListingId},
          )
          .timeout(const Duration(seconds: 20));

      if (response is! List) return const [];

      final matches = <HighSignalMatch>[];
      for (final row in response) {
        if (row is! Map) continue;
        final parsed = HighSignalMatch.tryParse(Map<String, dynamic>.from(row));
        if (parsed != null) matches.add(parsed);
      }
      return matches;
    } on PostgrestException catch (e) {
      debugPrint('TenantProfileRepository RPC failed: ${e.message}');
      rethrow;
    } on TimeoutException {
      debugPrint('TenantProfileRepository RPC timed out.');
      rethrow;
    }
  }
}
