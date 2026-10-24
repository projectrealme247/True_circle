import '../models/marketplace_space.dart';
import 'application_service.dart';
import 'auth_service.dart';
import 'listing_applications_supabase_service.dart';

/// Map-based API — remote-first when authenticated, local for demo/offline.
abstract final class ListingApplicationsService {
  static const seekerLoadErrorMessage =
      'Could not load your applications. Try again.';
  static const listingLoadErrorMessage =
      'Could not load applicants. Try again.';
  static const detailLoadErrorMessage =
      'Could not check your application. Try again.';

  static Future<List<Map<String, dynamic>>> loadAll() async {
    await applicationService.ensureLoaded();
    return applicationService.allRows();
  }

  /// Seeker Applications tab. A failed remote read throws.
  /// Signed-out and demo sessions keep the local store.
  static Future<List<Map<String, dynamic>>> refreshForCurrentSeeker() async {
    if (ListingApplicationsSupabaseService.isReady) {
      final remote = await ListingApplicationsSupabaseService
          .fetchForCurrentApplicant();
      final userId = AuthService.currentUser?.id?.trim() ?? '';
      return applicationService.replaceSeekerCacheWithRemote(
        userId: userId,
        remoteRows: remote,
      );
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
    final row = await forListingUser(
      listingId: listingId,
      applicantUserId: applicantUserId,
    );
    return row != null;
  }

  /// Host applicant list. A failed remote read throws.
  /// Signed-out and demo sessions keep the local store.
  static Future<List<Map<String, dynamic>>> forListing(String listingId) async {
    if (ListingApplicationsSupabaseService.isReady) {
      final remote =
          await ListingApplicationsSupabaseService.fetchForListing(listingId);
      return applicationService.replaceListingCacheWithRemote(
        listingId: listingId,
        remoteRows: remote,
      );
    }

    await applicationService.ensureLoaded();
    return applicationService.rowsForListing(listingId);
  }

  static Future<Map<String, dynamic>?> byId(String applicationId) async {
    await applicationService.ensureLoaded();
    return applicationService.rowById(applicationId);
  }

  /// Listing-detail apply state. A failed remote read throws.
  /// A successful empty result removes the stale local row.
  static Future<Map<String, dynamic>?> forListingUser({
    required String listingId,
    required String applicantUserId,
  }) async {
    if (ListingApplicationsSupabaseService.isReady) {
      final remote = await ListingApplicationsSupabaseService.fetchForListingUser(
        listingId: listingId,
        applicantUserId: applicantUserId,
      );
      if (remote == null) {
        await applicationService.forgetListingUser(
          listingId: listingId,
          userId: applicantUserId,
        );
        return null;
      }
      return applicationService.cacheRemoteRow(remote);
    }

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
