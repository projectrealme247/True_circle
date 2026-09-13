import 'applicant_application_status.dart';
import 'applicant_trust_tier.dart';
import 'applicant_trust_tier_block.dart';
import 'landlord_decision_summary.dart';

/// Single row in the independent-places applicant stream table.
class IndependentPlacesApplicantRow {
  const IndependentPlacesApplicantRow({
    required this.applicationId,
    required this.listingId,
    required this.applicantUserId,
    required this.seekerName,
    required this.status,
    required this.trustTier,
    required this.moveInTimelineMatch,
    required this.leaseTermMatch,
    required this.employmentVerified,
    required this.corporateDocumentVerified,
    this.timelineVarianceDays,
    this.preferredLeaseMonths,
    this.earliestMoveInDate,
    this.compatibilityScore = 0,
    this.overallMatchScore,
    this.verifiedTransitDurationSeconds,
    this.affordabilityMultiplier,
    this.decision,
    this.createdAt,
  });

  final String applicationId;
  final String listingId;
  final String applicantUserId;
  final String seekerName;
  final ApplicantApplicationStatus status;
  final ApplicantTrustTier trustTier;
  final bool moveInTimelineMatch;
  final bool leaseTermMatch;
  final bool employmentVerified;
  final bool corporateDocumentVerified;
  final int? timelineVarianceDays;
  final int? preferredLeaseMonths;
  final String? earliestMoveInDate;
  final int compatibilityScore;
  final int? overallMatchScore;
  final int? verifiedTransitDurationSeconds;
  final double? affordabilityMultiplier;
  final LandlordDecisionSummary? decision;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        'application_id': applicationId,
        'listing_id': listingId,
        'applicant_user_id': applicantUserId,
        'seeker_name': seekerName,
        'status': status.storageToken,
        'trust_tier': trustTier.displayToken,
        'move_in_timeline_match': moveInTimelineMatch,
        'lease_term_match': leaseTermMatch,
        'employment_verified': employmentVerified,
        'corporate_document_verified': corporateDocumentVerified,
        if (timelineVarianceDays != null)
          'timeline_variance_days': timelineVarianceDays,
        if (preferredLeaseMonths != null)
          'preferred_lease_months': preferredLeaseMonths,
        if (earliestMoveInDate != null)
          'earliest_move_in_date': earliestMoveInDate,
        'compatibility_score': compatibilityScore,
        if (overallMatchScore != null) 'overall_match_score': overallMatchScore,
        if (verifiedTransitDurationSeconds != null)
          'verified_transit_duration_seconds': verifiedTransitDurationSeconds,
        if (affordabilityMultiplier != null &&
            !affordabilityMultiplier!.isInfinite &&
            !affordabilityMultiplier!.isNaN)
          'affordability_multiplier': affordabilityMultiplier,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

/// Independent-places stream grouped by trust tier blocks.
class IndependentPlacesApplicantStream {
  const IndependentPlacesApplicantStream({
    required this.listingId,
    required this.marketplaceCategory,
    required this.blocks,
    required this.totalCount,
    this.displayLabel = categoryDisplayLabel,
  });

  static const categoryDisplayLabel = 'Entire Place (Independent Flat/House)';
  static const categoryToken = 'independent_places';

  final String listingId;
  final String marketplaceCategory;
  final String displayLabel;
  final List<ApplicantTrustTierBlock<IndependentPlacesApplicantRow>> blocks;
  final int totalCount;

  List<IndependentPlacesApplicantRow> get flattenedApplicants => [
        for (final block in blocks) ...block.applicants,
      ];

  Map<String, dynamic> toMap() => {
        'listing_id': listingId,
        'marketplace_category': marketplaceCategory,
        'display_label': displayLabel,
        'total_count': totalCount,
        'blocks': blocks.map((b) => b.toMap((r) => r.toMap())).toList(),
      };
}
