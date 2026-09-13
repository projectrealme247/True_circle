import '../models/independent_places_applicant_stream.dart';
import '../models/listing_creation_category.dart';
import '../models/listing_creation_field_keys.dart';
import '../models/shared_living_applicant_stream.dart';
import '../utils/landlord_dashboard_helpers.dart';
import '../utils/profile_data.dart';
import 'applicant_stream_payload_builder.dart';
import 'listing_applications_service.dart';

/// Builds host applicant streams from local [ListingApplicationsService] rows.
abstract final class LocalApplicantStreamService {
  static Future<List<Map<String, dynamic>>> rowsForListing(String listingId) {
    return ListingApplicationsService.forListing(listingId);
  }

  static Map<String, dynamic> listingWithCategory(
    Map<String, dynamic> listing,
    ListingCreationCategory category,
  ) {
    return {
      ...listing,
      ListingCreationFieldKeys.marketplaceCategory: category.storageToken,
    };
  }

  static Map<String, Map<String, dynamic>> trustProfilesFromRows(
    List<Map<String, dynamic>> rows,
  ) {
    final profiles = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final userId = ProfileData.text(row['applicant_user_id']).isNotEmpty
          ? ProfileData.text(row['applicant_user_id'])
          : ProfileData.text(row['user_id']);
      if (userId.isEmpty) continue;
      final payload = row['payload'];
      if (payload is Map) {
        profiles[userId] = Map<String, dynamic>.from(payload);
      }
    }
    return profiles;
  }

  static SharedLivingApplicantStream sharedStream({
    required Map<String, dynamic> listing,
    required List<Map<String, dynamic>> applicationRows,
  }) {
    return ApplicantStreamPayloadBuilder.buildSharedLivingStream(
      listing: listingWithCategory(
        listing,
        ListingCreationCategory.sharedLiving,
      ),
      applicationRows: applicationRows,
      trustProfilesByUserId: trustProfilesFromRows(applicationRows),
    );
  }

  static IndependentPlacesApplicantStream independentStream({
    required Map<String, dynamic> listing,
    required List<Map<String, dynamic>> applicationRows,
  }) {
    return ApplicantStreamPayloadBuilder.buildIndependentPlacesStream(
      listing: listingWithCategory(
        listing,
        ListingCreationCategory.independentPlaces,
      ),
      applicationRows: applicationRows,
      trustProfilesByUserId: trustProfilesFromRows(applicationRows),
    );
  }

  /// Seeded applicants only when this listing has no real applications.
  static bool useSeededFallback({
    required String listingId,
    required bool hasRealApplications,
  }) {
    return !hasRealApplications &&
        LandlordDashboardHelpers.isMockListing(listingId);
  }
}
