import '../models/marketplace_space.dart';
import 'application_service.dart';

/// Legacy map-based API — delegates to [ApplicationService].
abstract final class ListingApplicationsService {
  static Future<List<Map<String, dynamic>>> loadAll() async {
    await applicationService.ensureLoaded();
    return applicationService.allRows();
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

  static Future<List<Map<String, dynamic>>> forListing(String listingId) async {
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

  static Future<Map<String, dynamic>> submit({
    required String listingId,
    required Map<String, dynamic> session,
    required MarketplaceSpace space,
    required int compatibilityScore,
  }) {
    return applicationService.submitWithDetails(
      listingId: listingId,
      session: session,
      space: space,
      compatibilityScore: compatibilityScore,
    );
  }
}
