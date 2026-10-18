import 'package:flutter/foundation.dart';

import '../models/marketplace_space.dart';
import 'application_service.dart';
import 'auth_service.dart';
import 'listing_applications_supabase_service.dart';

/// Map-based API — remote-first when authenticated, local for demo/offline.
abstract final class ListingApplicationsService {
  static Future<List<Map<String, dynamic>>> loadAll() async {
    await applicationService.ensureLoaded();
    return applicationService.allRows();
  }

  /// Seeker Applications tab: remote rows for the signed-in user.
  /// Local cache remains the demo/offline fallback.
  static Future<List<Map<String, dynamic>>> refreshForCurrentSeeker() async {
    if (ListingApplicationsSupabaseService.isReady) {
      try {
        final remote = await ListingApplicationsSupabaseService
            .fetchForCurrentApplicant();
        final userId = AuthService.currentUser?.id?.trim() ?? '';
        return applicationService.replaceSeekerCacheWithRemote(
          userId: userId,
          remoteRows: remote,
        );
      } catch (e) {
        debugPrint(
          'ListingApplicationsService remote seeker refresh failed, using local: $e',
        );
      }
    }

    await applicationService.ensureLoaded();
    final userId = AuthService.identityUserId();
    return [
      for (final row in applicationService.allRows())
        if ((row['applicant_user_id'] ?? row['user_id'])?.toString() == userId)
          row,
    ];
  }

  static Future<bool> hasApplied({
    required String listingId,
    required String applicantUserId,
  }) async {
    await applicationService.ensureLoaded();
    return applicationService.hasApplied(
      listingId: listingId,
      userId: applicantUserId,
    );
  }

  /// Host dashboard read: remote applications when authenticated.
  static Future<List<Map<String, dynamic>>> forListing(String listingId) async {
    if (ListingApplicationsSupabaseService.isReady) {
      try {
        final remote =
            await ListingApplicationsSupabaseService.fetchForListing(listingId);
        return applicationService.replaceListingCacheWithRemote(
          listingId: listingId,
          remoteRows: remote,
        );
      } catch (e) {
        debugPrint(
          'ListingApplicationsService remote forListing failed, using local: $e',
        );
      }
    }

    await applicationService.ensureLoaded();
    return applicationService.rowsForListing(listingId);
  }

  static Future<Map<String, dynamic>?> byId(String applicationId) async {
    await applicationService.ensureLoaded();
    return applicationService.rowById(applicationId);
  }

  static Future<Map<String, dynamic>?> forListingUser({
    required String listingId,
    required String applicantUserId,
  }) async {
    await applicationService.ensureLoaded();
    return applicationService.rowForListingUser(
      listingId: listingId,
      userId: applicantUserId,
    );
  }

  /// Authenticated apply inserts into Supabase. A failed insert is surfaced
  /// to the caller and is not stored locally.
  ///
  /// Signed-out, demo, and offline sessions (Supabase not ready) still use
  /// the local application store.
  static Future<Map<String, dynamic>> submit({
    required String listingId,
    required Map<String, dynamic> session,
    required MarketplaceSpace space,
    required int compatibilityScore,
  }) async {
    if (ListingApplicationsSupabaseService.isReady) {
      final remote = await ListingApplicationsSupabaseService.submit(
        listingId: listingId,
        session: session,
        space: space,
        compatibilityScore: compatibilityScore,
      );
      return applicationService.cacheRemoteRow(remote);
    }

    return applicationService.submitWithDetails(
      listingId: listingId,
      session: session,
      space: space,
      compatibilityScore: compatibilityScore,
    );
  }
}
