import 'listing_creation_category.dart';
import 'listing_applicant_record.dart';

/// Category-aware applicant queue for host manage flows.
class ListingApplicantDashboard {
  const ListingApplicantDashboard({
    required this.listingId,
    required this.category,
    required this.applicants,
    required this.totalCount,
    required this.pendingCount,
  });

  final String listingId;
  final ListingCreationCategory category;
  final List<ListingApplicantRecord> applicants;
  final int totalCount;
  final int pendingCount;

  Map<String, dynamic> toMap() => {
        'listing_id': listingId,
        'marketplace_category': category.storageToken,
        'total_count': totalCount,
        'pending_count': pendingCount,
        'applicants': applicants.map((a) => a.toMap()).toList(),
      };
}
