import 'applicant_trust_tier.dart';

/// GDPR-safe seeker profile metrics for host applicant review.
class ApplicantProfileMetrics {
  const ApplicantProfileMetrics({
    required this.trustTier,
    required this.trustStage,
    required this.employmentVerified,
    required this.financialVerified,
    required this.profileCompletenessPercent,
    this.verificationTrack,
    this.overallMatchScore,
    this.verifiedTransitDurationSeconds,
  });

  final ApplicantTrustTier trustTier;
  final int trustStage;
  final bool employmentVerified;
  final bool financialVerified;
  final int profileCompletenessPercent;
  final String? verificationTrack;
  final int? overallMatchScore;
  final int? verifiedTransitDurationSeconds;

  Map<String, dynamic> toMap() => {
        'trust_tier': trustTier.displayToken,
        'trust_stage': trustStage,
        'employment_verified': employmentVerified,
        'financial_verified': financialVerified,
        'profile_completeness_percent': profileCompletenessPercent,
        if (verificationTrack != null) 'verification_track': verificationTrack,
        if (overallMatchScore != null) 'overall_match_score': overallMatchScore,
        if (verifiedTransitDurationSeconds != null)
          'verified_transit_duration_seconds': verifiedTransitDurationSeconds,
      };
}
