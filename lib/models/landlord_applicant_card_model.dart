import '../utils/rental_date_format.dart';
import 'applicant_application_status.dart';
import 'applicant_trust_tier.dart';
import 'independent_places_applicant_stream.dart';
import 'shared_living_applicant_stream.dart';

/// Unified applicant card for the landlord pipeline workspace.
class LandlordApplicantCardModel {
  const LandlordApplicantCardModel({
    required this.applicationId,
    required this.seekerName,
    required this.status,
    required this.trustTier,
    required this.matchPercent,
    required this.matchBreakdownLabel,
    required this.verificationLabel,
    required this.affordabilityMultiplier,
    required this.bioPitch,
    required this.languages,
    required this.sourceRow,
    required this.isSharedLiving,
    this.budgetLabel,
    this.commuteLabel,
    this.moveInLabel,
  });

  final String applicationId;
  final String seekerName;
  final ApplicantApplicationStatus status;
  final ApplicantTrustTier trustTier;
  final int matchPercent;
  final String matchBreakdownLabel;
  final String verificationLabel;
  final double affordabilityMultiplier;
  final String bioPitch;
  final List<String> languages;
  final Object sourceRow;
  final bool isSharedLiving;
  final String? budgetLabel;
  final String? commuteLabel;
  final String? moveInLabel;

  String get trustTabLabel => switch (trustTier) {
        ApplicantTrustTier.sound => 'Sound (Vouched & Secured)',
        ApplicantTrustTier.grand => 'Grand (Verified Intent)',
        ApplicantTrustTier.justLanded => 'Just Landed (Casual / Inbound)',
      };

  String get statusLabel => switch (status) {
        ApplicantApplicationStatus.pending => 'Pending',
        ApplicantApplicationStatus.viewingScheduled => 'Viewing Scheduled',
        ApplicantApplicationStatus.accepted => 'Accepted',
        ApplicantApplicationStatus.declined => 'Declined',
      };

  String get affordabilityLabel =>
      '${affordabilityMultiplier.toStringAsFixed(1)}x Affordability Multiplier';

  /// Prominent headline beside the match wheel — sequenced by listing category.
  String get primaryBreakdownHeadline => isSharedLiving
      ? 'Lifestyle compatibility, roommate rhythm alignment, and shared kitchen culture scored against your household.'
      : 'Financial security confirmed · $verificationLabel · employment stability verified for lease term.';

  /// Secondary baseline detail below the primary headline.
  String get secondaryBreakdownDetail => isSharedLiving
      ? 'Financial verification baseline: $verificationLabel'
      : 'Lifestyle fit: kitchen culture, language overlap, and household rhythm scored as a secondary compatibility layer.';

  static List<LandlordApplicantCardModel> fromSharedStream(
    SharedLivingApplicantStream stream,
  ) {
    return [
      for (final row in stream.flattenedApplicants) fromSharedRow(row),
    ];
  }

  static List<LandlordApplicantCardModel> fromIndependentStream(
    IndependentPlacesApplicantStream stream,
  ) {
    return [
      for (final row in stream.flattenedApplicants) fromIndependentRow(row),
    ];
  }

  static LandlordApplicantCardModel fromSharedRow(SharedLivingApplicantRow row) {
    final matchPercent = row.overallMatchScore ?? row.lifestyleMatchScorePercent;
    final multiplier = row.affordabilityMultiplier ?? _defaultMultiplier(row.trustTier);

    return LandlordApplicantCardModel(
      applicationId: row.applicationId,
      seekerName: row.seekerName,
      status: row.status,
      trustTier: row.trustTier,
      matchPercent: matchPercent,
      matchBreakdownLabel: 'Overall match: $matchPercent%',
      verificationLabel: _verificationForShared(row),
      affordabilityMultiplier: multiplier,
      bioPitch: row.customBioPitch,
      languages: row.seekerLanguages,
      sourceRow: row,
      isSharedLiving: true,
      commuteLabel: _commuteLabel(row.verifiedTransitDurationSeconds),
      moveInLabel: null,
    );
  }

  static LandlordApplicantCardModel fromIndependentRow(
    IndependentPlacesApplicantRow row,
  ) {
    final matchPercent = row.overallMatchScore ?? row.compatibilityScore;
    final multiplier = row.affordabilityMultiplier ?? _defaultMultiplier(row.trustTier);

    return LandlordApplicantCardModel(
      applicationId: row.applicationId,
      seekerName: row.seekerName,
      status: row.status,
      trustTier: row.trustTier,
      matchPercent: matchPercent,
      matchBreakdownLabel: 'Overall match: $matchPercent%',
      verificationLabel: _verificationForIndependent(row),
      affordabilityMultiplier: multiplier,
      bioPitch:
          'Lease fit: ${row.leaseTermMatch ? "aligned" : "review"} · '
          'Timeline: ${row.moveInTimelineMatch ? "aligned" : "review"}',
      languages: const [],
      sourceRow: row,
      isSharedLiving: false,
      budgetLabel: multiplier > 0
          ? '${multiplier.toStringAsFixed(1)}× rent affordability'
          : null,
      commuteLabel: _commuteLabel(row.verifiedTransitDurationSeconds),
      moveInLabel: row.earliestMoveInDate?.trim().isNotEmpty == true
          ? 'Move-in ${RentalDateFormat.formatRentalAvailabilityDate(row.earliestMoveInDate)}'
          : null,
    );
  }

  static String? _commuteLabel(int? transitSeconds) {
    if (transitSeconds == null || transitSeconds <= 0) return null;
    final minutes = (transitSeconds / 60).round();
    return '$minutes min commute';
  }

  static double _defaultMultiplier(ApplicantTrustTier tier) => switch (tier) {
        ApplicantTrustTier.sound => 3.5,
        ApplicantTrustTier.grand => 3.0,
        ApplicantTrustTier.justLanded => 2.5,
      };

  static String _verificationForShared(SharedLivingApplicantRow row) {
    return switch (row.trustTier) {
      ApplicantTrustTier.sound =>
        'Confirmed employment contract · salary >3.5× rent target',
      ApplicantTrustTier.grand => 'Verified via institutional .ac.ie domain OTP',
      ApplicantTrustTier.justLanded =>
        'Verified bank loan disbursal letter on file',
    };
  }

  static String _verificationForIndependent(IndependentPlacesApplicantRow row) {
    if (row.employmentVerified && row.corporateDocumentVerified) {
      return 'Dual verified · employment + corporate documentation';
    }
    if (row.employmentVerified) {
      return 'Employment verified via Open Banking track';
    }
    return 'Trust tier: ${row.trustTier.displayToken}';
  }
}

/// Trust-tier filter for segmented tabs.
enum LandlordTrustFilter {
  all,
  sound,
  grand,
  justLanded;

  String get label => switch (this) {
        LandlordTrustFilter.all => 'All Matches',
        LandlordTrustFilter.sound => 'Sound (Vouched & Secured)',
        LandlordTrustFilter.grand => 'Grand (Verified Intent)',
        LandlordTrustFilter.justLanded => 'Just Landed (Casual / Inbound)',
      };

  bool matches(ApplicantTrustTier tier) => switch (this) {
        LandlordTrustFilter.all => true,
        LandlordTrustFilter.sound => tier == ApplicantTrustTier.sound,
        LandlordTrustFilter.grand => tier == ApplicantTrustTier.grand,
        LandlordTrustFilter.justLanded => tier == ApplicantTrustTier.justLanded,
      };
}
