import 'applicant_application_status.dart';
import 'applicant_trust_tier.dart';
import 'applicant_trust_tier_block.dart';

/// Single row in the shared-living applicant stream table.
class SharedLivingApplicantRow {
  const SharedLivingApplicantRow({
    required this.applicationId,
    required this.listingId,
    required this.applicantUserId,
    required this.seekerName,
    required this.status,
    required this.trustTier,
    required this.lifestyleMatchScorePercent,
    required this.languageAlignmentOverlap,
    required this.seekerLanguages,
    required this.listingLanguages,
    required this.kitchenCultureAligned,
    required this.customBioPitch,
    this.listingKitchenCulture,
    this.compatibilityScore = 0,
    this.overallMatchScore,
    this.verifiedTransitDurationSeconds,
    this.affordabilityMultiplier,
    this.createdAt,
  });

  final String applicationId;
  final String listingId;
  final String applicantUserId;
  final String seekerName;
  final ApplicantApplicationStatus status;
  final ApplicantTrustTier trustTier;
  final int lifestyleMatchScorePercent;
  final List<String> languageAlignmentOverlap;
  final List<String> seekerLanguages;
  final List<String> listingLanguages;
  final bool kitchenCultureAligned;
  final String? listingKitchenCulture;
  final String customBioPitch;
  final int compatibilityScore;
  final int? overallMatchScore;
  final int? verifiedTransitDurationSeconds;
  final double? affordabilityMultiplier;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        'application_id': applicationId,
        'listing_id': listingId,
        'applicant_user_id': applicantUserId,
        'seeker_name': seekerName,
        'status': status.storageToken,
        'trust_tier': trustTier.displayToken,
        'lifestyle_match_score_percent': lifestyleMatchScorePercent,
        'language_alignment_overlap': languageAlignmentOverlap,
        'seeker_languages': seekerLanguages,
        'listing_languages': listingLanguages,
        'kitchen_culture_aligned': kitchenCultureAligned,
        if (listingKitchenCulture != null)
          'listing_kitchen_culture': listingKitchenCulture,
        'custom_bio_pitch': customBioPitch,
        'compatibility_score': compatibilityScore,
        if (overallMatchScore != null) 'overall_match_score': overallMatchScore,
        if (verifiedTransitDurationSeconds != null)
          'verified_transit_duration_seconds': verifiedTransitDurationSeconds,
        if (affordabilityMultiplier != null)
          'affordability_multiplier': affordabilityMultiplier,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

/// Shared-living stream grouped by trust tier blocks.
class SharedLivingApplicantStream {
  const SharedLivingApplicantStream({
    required this.listingId,
    required this.marketplaceCategory,
    required this.blocks,
    required this.totalCount,
    this.displayLabel = categoryDisplayLabel,
  });

  static const categoryDisplayLabel = 'Room in a Shared Flat / House';
  static const categoryToken = 'shared_living';

  final String listingId;
  final String marketplaceCategory;
  final String displayLabel;
  final List<ApplicantTrustTierBlock<SharedLivingApplicantRow>> blocks;
  final int totalCount;

  List<SharedLivingApplicantRow> get flattenedApplicants => [
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
