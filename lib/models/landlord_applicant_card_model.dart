import '../services/application_service.dart';
import '../utils/application_pitch_text.dart';
import '../utils/rental_date_format.dart';
import 'applicant_application_status.dart';
import 'applicant_trust_tier.dart';
import 'independent_places_applicant_stream.dart';
import 'landlord_decision_summary.dart';
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
    this.decision,
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
  final LandlordDecisionSummary? decision;

  String get trustTabLabel => trustTier.landlordBadgeLabel;

  bool get isVerifiedUser =>
      decision?.isVerifiedUser ?? false;

  String get listingId {
    final row = sourceRow;
    if (row is SharedLivingApplicantRow) return row.listingId;
    if (row is IndependentPlacesApplicantRow) return row.listingId;
    return '';
  }

  String get applicantUserId {
    final row = sourceRow;
    if (row is SharedLivingApplicantRow) return row.applicantUserId;
    if (row is IndependentPlacesApplicantRow) return row.applicantUserId;
    return '';
  }

  String get statusLabel => switch (status) {
        ApplicantApplicationStatus.pending => 'Pending',
        ApplicantApplicationStatus.viewingInvitationSent =>
          'Viewing Invitation Sent',
        ApplicantApplicationStatus.viewingScheduled => 'Viewing Scheduled',
        ApplicantApplicationStatus.accepted => 'Accepted',
        ApplicantApplicationStatus.declined => 'Declined',
      };

  bool get hasAffordability =>
      decision?.hasAffordability ?? affordabilityMultiplier > 0;

  String get affordabilityLabel {
    if (!hasAffordability) return 'Unknown';
    return decision?.affordabilityLabel ??
        '${affordabilityMultiplier.toStringAsFixed(1)}× rent';
  }

  String get incomeSourceLabel =>
      decision?.incomeSourceLabel ?? 'Self-declared';

  /// Prominent headline beside the match wheel — sequenced by listing category.
  String get primaryBreakdownHeadline => isSharedLiving
      ? 'Lifestyle compatibility, roommate rhythm alignment, and shared kitchen culture scored against your household.'
      : 'Lease and timeline fit · $verificationLabel. Affordability uses self-declared income separately.';

  /// Secondary baseline detail below the primary headline.
  String get secondaryBreakdownDetail => isSharedLiving
      ? 'Contact and employment-status signals: $verificationLabel'
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
    final multiplier = _resolveMultiplier(
      decisionMultiplier: row.decision?.affordabilityMultiplier,
      rowMultiplier: row.affordabilityMultiplier,
    );

    return LandlordApplicantCardModel(
      applicationId: row.applicationId,
      seekerName: row.seekerName,
      status: row.status,
      trustTier: row.trustTier,
      matchPercent: matchPercent,
      matchBreakdownLabel: 'Overall match: $matchPercent%',
      verificationLabel: _verificationForShared(row),
      affordabilityMultiplier: multiplier,
      bioPitch: row.customBioPitch.isNotEmpty
          ? row.customBioPitch
          : 'No personal introduction yet.',
      languages: row.seekerLanguages,
      sourceRow: row,
      isSharedLiving: true,
      budgetLabel: multiplier > 0
          ? '${multiplier.toStringAsFixed(1)}× rent'
          : null,
      commuteLabel: row.decision?.commuteLabel ??
          _commuteLabel(row.verifiedTransitDurationSeconds),
      moveInLabel: row.decision?.moveInCompatibilityLabel,
      decision: row.decision,
    );
  }

  static LandlordApplicantCardModel fromIndependentRow(
    IndependentPlacesApplicantRow row,
  ) {
    final matchPercent = row.overallMatchScore ?? row.compatibilityScore;
    final multiplier = _resolveMultiplier(
      decisionMultiplier: row.decision?.affordabilityMultiplier,
      rowMultiplier: row.affordabilityMultiplier,
    );

    final pitch = ApplicationPitchText.fromApplicationRow(
      applicationService.rowById(row.applicationId),
    );

    return LandlordApplicantCardModel(
      applicationId: row.applicationId,
      seekerName: row.seekerName,
      status: row.status,
      trustTier: row.trustTier,
      matchPercent: matchPercent,
      matchBreakdownLabel: 'Overall match: $matchPercent%',
      verificationLabel: _verificationForIndependent(row),
      affordabilityMultiplier: multiplier,
      bioPitch: pitch.isNotEmpty
          ? pitch
          : 'No personal introduction yet.',
      languages: const [],
      sourceRow: row,
      isSharedLiving: false,
      budgetLabel: multiplier > 0
          ? '${multiplier.toStringAsFixed(1)}× rent'
          : null,
      commuteLabel: row.decision?.commuteLabel ??
          _commuteLabel(row.verifiedTransitDurationSeconds),
      moveInLabel: row.decision?.moveInCompatibilityLabel ??
          (row.earliestMoveInDate?.trim().isNotEmpty == true
              ? 'Move-in ${RentalDateFormat.formatRentalAvailabilityDate(row.earliestMoveInDate)}'
              : null),
      decision: row.decision,
    );
  }

  static String? _commuteLabel(int? transitSeconds) {
    if (transitSeconds == null || transitSeconds <= 0) return null;
    final minutes = (transitSeconds / 60).round();
    return '$minutes min commute';
  }

  /// Prefer a positive calculated multiplier; never invent trust-tier values.
  static double _resolveMultiplier({
    required double? decisionMultiplier,
    required double? rowMultiplier,
  }) {
    if (decisionMultiplier != null && decisionMultiplier > 0) {
      return decisionMultiplier;
    }
    if (rowMultiplier != null && rowMultiplier > 0) {
      return rowMultiplier;
    }
    return 0;
  }

  static String _verificationForShared(SharedLivingApplicantRow row) {
    final chips = row.decision?.verificationChipLabels;
    if (chips != null && chips.isNotEmpty) return chips.join(' · ');
    if (row.decision?.isVerifiedUser == true) {
      return ApplicantTrustTier.verifiedUserLabel;
    }
    return 'Verification pending';
  }

  static String _verificationForIndependent(IndependentPlacesApplicantRow row) {
    final chips = row.decision?.verificationChipLabels;
    if (chips != null && chips.isNotEmpty) return chips.join(' · ');
    if (row.decision?.isVerifiedUser == true) {
      return ApplicantTrustTier.verifiedUserLabel;
    }
    if (row.employmentVerified && row.corporateDocumentVerified) {
      return 'Employment document on file';
    }
    if (row.employmentVerified) {
      return 'Employment status confirmed';
    }
    return 'Verification pending';
  }
}

/// Applicant filter for segmented tabs (verified vs pending — no tier names).
enum LandlordTrustFilter {
  all,
  verified,
  pending;

  String get label => switch (this) {
        LandlordTrustFilter.all => 'All Matches',
        LandlordTrustFilter.verified => ApplicantTrustTier.verifiedUserLabel,
        LandlordTrustFilter.pending => 'Verification pending',
      };

  /// @deprecated Prefer [matchesVerified]. Tier alone is not a contact unlock.
  bool matches(ApplicantTrustTier tier) => switch (this) {
        LandlordTrustFilter.all => true,
        // Cannot derive contact unlock from JL/G/S — treat as pending.
        LandlordTrustFilter.verified => false,
        LandlordTrustFilter.pending => true,
      };

  bool matchesVerified(bool isVerifiedUser) => switch (this) {
        LandlordTrustFilter.all => true,
        LandlordTrustFilter.verified => isVerifiedUser,
        LandlordTrustFilter.pending => !isVerifiedUser,
      };
}
