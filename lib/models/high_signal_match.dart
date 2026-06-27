import '../utils/numeric_bounds.dart';
import '../utils/profile_data.dart';

/// Row returned by Supabase `get_high_signal_matches` for a listing.
class HighSignalMatch {
  const HighSignalMatch({
    required this.applicationId,
    required this.applicantUserId,
    required this.overallMatchScore,
    this.verifiedTransitDurationSeconds,
  });

  final String applicationId;
  final String applicantUserId;
  final int overallMatchScore;
  final int? verifiedTransitDurationSeconds;

  static HighSignalMatch? tryParse(Map<String, dynamic> raw) {
    final applicationId = ProfileData.text(
      raw['application_id'] ?? raw['id'],
    );
    final applicantUserId = ProfileData.text(raw['applicant_user_id']);
    if (applicationId.isEmpty && applicantUserId.isEmpty) return null;

    final scoreRaw = raw['overall_match_score'];
    final score = NumericBounds.clampPercentInt(
      scoreRaw is num
          ? scoreRaw.round()
          : int.tryParse(ProfileData.text(scoreRaw)) ?? 0,
    );

    final transitRaw = raw['verified_transit_duration_seconds'];
    final transitSeconds = transitRaw is num
        ? transitRaw.round()
        : int.tryParse(ProfileData.text(transitRaw));

    return HighSignalMatch(
      applicationId: applicationId,
      applicantUserId: applicantUserId,
      overallMatchScore: score,
      verifiedTransitDurationSeconds:
          transitSeconds != null && transitSeconds > 0 ? transitSeconds : null,
    );
  }

  static Map<String, HighSignalMatch> indexByApplicationId(
    Iterable<HighSignalMatch> matches,
  ) {
    final indexed = <String, HighSignalMatch>{};
    for (final match in matches) {
      if (match.applicationId.isNotEmpty) {
        indexed[match.applicationId] = match;
      }
    }
    return indexed;
  }

  static Map<String, HighSignalMatch> indexByApplicantUserId(
    Iterable<HighSignalMatch> matches,
  ) {
    final indexed = <String, HighSignalMatch>{};
    for (final match in matches) {
      if (match.applicantUserId.isNotEmpty) {
        indexed[match.applicantUserId] = match;
      }
    }
    return indexed;
  }
}
