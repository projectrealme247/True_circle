import 'applicant_application_status.dart';
import 'applicant_profile_metrics.dart';
import 'independent_places_match_metrics.dart';
import 'shared_living_match_metrics.dart';

/// Inbound seeker row for a single listing application.
class ListingApplicantRecord {
  const ListingApplicantRecord({
    required this.applicationId,
    required this.listingId,
    required this.applicantUserId,
    required this.status,
    required this.compatibilityScore,
    required this.createdAt,
    required this.seekerName,
    required this.pitchNarrative,
    required this.profileMetrics,
    required this.dashboardSortScore,
    this.updatedAt,
    this.sharedLivingMatch,
    this.independentPlacesMatch,
    this.rawPayload = const {},
  });

  final String applicationId;
  final String listingId;
  final String applicantUserId;
  final ApplicantApplicationStatus status;
  final int compatibilityScore;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String seekerName;
  final String pitchNarrative;
  final ApplicantProfileMetrics profileMetrics;
  final int dashboardSortScore;
  final SharedLivingMatchMetrics? sharedLivingMatch;
  final IndependentPlacesMatchMetrics? independentPlacesMatch;
  final Map<String, dynamic> rawPayload;

  Map<String, dynamic> toMap() => {
        'application_id': applicationId,
        'listing_id': listingId,
        'applicant_user_id': applicantUserId,
        'status': status.storageToken,
        'compatibility_score': compatibilityScore,
        'created_at': createdAt.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        'seeker_name': seekerName,
        'pitch_narrative': pitchNarrative,
        'profile_metrics': profileMetrics.toMap(),
        'dashboard_sort_score': dashboardSortScore,
        if (sharedLivingMatch != null)
          'shared_living_match': sharedLivingMatch!.toMap(),
        if (independentPlacesMatch != null)
          'independent_places_match': independentPlacesMatch!.toMap(),
      };
}
