import 'applicant_trust_tier.dart';
import 'move_in_timing.dart';
import 'seeker_onboarding_enums.dart';

/// Decision-first landlord metrics — ordered for invite / decline, not profile browsing.
class LandlordDecisionSummary {
  const LandlordDecisionSummary({
    required this.isSharedLiving,
    required this.affordabilityMultiplier,
    required this.affordabilityVerified,
    required this.moveInQuality,
    required this.moveInWindowLabel,
    required this.propertyRequirementMatch,
    required this.propertyRequirementLabel,
    required this.trustTier,
    required this.idVerified,
    required this.employmentVerified,
    required this.incomeVerified,
    required this.peerReferenceAvailable,
    this.familyAdults,
    this.familyChildren,
    this.groupSize,
    this.isCouple,
    this.householdHasPets = false,
    this.preferredLeaseMonths,
    this.leaseTermMatch = false,
    this.guarantorStatus,
    this.foodCompatible,
    this.smokingCompatible,
    this.languageOverlap = const [],
    this.lifestyleMatchPercent,
    this.commuteLabel,
  });

  final bool isSharedLiving;

  /// Income ÷ rent when calculable; `0` means unknown (not a ratio).
  /// Raw € never included.
  final double affordabilityMultiplier;
  final bool affordabilityVerified;

  /// True when a positive multiplier was calculated (not a missing-data sentinel).
  bool get hasAffordability => affordabilityMultiplier > 0;

  final TimingMatchQuality moveInQuality;
  final String moveInWindowLabel;

  final bool propertyRequirementMatch;
  final String propertyRequirementLabel;

  final ApplicantTrustTier trustTier;
  final bool idVerified;
  final bool employmentVerified;
  final bool incomeVerified;
  final bool peerReferenceAvailable;

  /// Landlord-facing verification — contact unlock only (not trust_tier).
  bool get isVerifiedUser => idVerified;

  final int? familyAdults;
  final int? familyChildren;
  final int? groupSize;
  final bool? isCouple;
  final bool householdHasPets;
  final int? preferredLeaseMonths;
  final bool leaseTermMatch;
  final GuarantorStatus? guarantorStatus;

  final bool? foodCompatible;
  final bool? smokingCompatible;
  final List<String> languageOverlap;
  final int? lifestyleMatchPercent;
  final String? commuteLabel;

  /// Ratio only — Phase 1 never appends verification language.
  String get affordabilityLabel {
    if (!hasAffordability) return 'Unknown';
    return '${affordabilityMultiplier.toStringAsFixed(1)}× rent';
  }

  /// Phase 1 income provenance — self-declared net income only.
  String get incomeSourceLabel => 'Self-declared';

  /// Meaningful only when [hasAffordability] is true; unknown is never a fail.
  bool get affordabilityMeetsTarget =>
      hasAffordability && affordabilityMultiplier >= 3.0;

  String get moveInCompatibilityLabel {
    if (moveInQuality == TimingMatchQuality.none && moveInWindowLabel.isEmpty) {
      return 'Timing unknown';
    }
    if (moveInQuality == TimingMatchQuality.none) {
      return moveInWindowLabel;
    }
    final window = moveInWindowLabel.isEmpty ? '' : ' · $moveInWindowLabel';
    return '${moveInQuality.label}$window';
  }

  String get householdCompositionLabel {
    if (isSharedLiving) {
      final size = groupSize ?? 1;
      return size <= 1 ? '1 occupant' : '$size housemates seeking';
    }
    final adults = familyAdults ?? groupSize ?? 1;
    final children = familyChildren ?? 0;
    final couple = isCouple == true ? ' · Couple' : '';
    if (children > 0) {
      return '$adults adult${adults == 1 ? '' : 's'} · $children child${children == 1 ? '' : 'ren'}$couple';
    }
    return '$adults adult${adults == 1 ? '' : 's'}$couple';
  }

  String get guarantorLabel => switch (guarantorStatus) {
        GuarantorStatus.yes => 'Guarantor available',
        GuarantorStatus.no => 'No guarantor',
        GuarantorStatus.notSureYet => 'Guarantor unsure',
        null => 'Guarantor not asked',
      };

  List<String> get verificationChipLabels => [
        if (isVerifiedUser) ApplicantTrustTier.verifiedUserLabel,
        if (employmentVerified) 'Employment',
        if (peerReferenceAvailable) 'Peer ref',
      ];
}
