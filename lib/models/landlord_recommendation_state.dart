import 'landlord_decision_summary.dart';
import 'move_in_timing.dart';
import 'seeker_onboarding_enums.dart';

/// Primary landlord action cue — stronger than match % in the queue.
enum LandlordRecommendationState {
  inviteReady(
    'Invite Ready',
    '✨',
    'Strong fit — ready to meet',
  ),
  timingConflict(
    'Timing Conflict',
    '📅',
    'Move-in windows need a chat',
  ),
  affordabilityReview(
    'Affordability Review',
    '💶',
    'Income ratio is below target',
  ),
  guarantorReview(
    'Guarantor Review',
    '🤝',
    'Guarantor status needs clarity',
  ),
  review(
    'Review',
    '👀',
    'Worth a closer look',
  ),
  notSuitable(
    'Not Suitable',
    '🚫',
    'Hard mismatch on key filters',
  );

  const LandlordRecommendationState(this.label, this.emoji, this.hint);
  final String label;
  final String emoji;
  final String hint;

  bool get isPositive => this == inviteReady;
  bool get isNegative => this == notSuitable;
  bool get isWarning =>
      this == timingConflict ||
      this == affordabilityReview ||
      this == guarantorReview ||
      this == review;
}

abstract final class LandlordRecommendationResolver {
  LandlordRecommendationResolver._();

  static LandlordRecommendationState resolve(LandlordDecisionSummary? d) {
    if (d == null) return LandlordRecommendationState.review;

    final hardPropertyFail =
        d.propertyRequirementLabel != 'Layout not specified' &&
            !d.propertyRequirementMatch;
    final veryLowAfford = d.hasAffordability &&
        d.affordabilityMultiplier < 2.0;
    final weakTiming = d.moveInQuality == TimingMatchQuality.weak;
    final affordReview = d.hasAffordability && !d.affordabilityMeetsTarget;
    final needsGuarantor =
        d.guarantorStatus == GuarantorStatus.no ||
            d.guarantorStatus == GuarantorStatus.notSureYet;
    // Guarantor only elevates when explicitly asked (students).
    final guarantorAsked = d.guarantorStatus != null;

    if (hardPropertyFail || veryLowAfford) {
      return LandlordRecommendationState.notSuitable;
    }
    if (weakTiming) return LandlordRecommendationState.timingConflict;
    if (affordReview) return LandlordRecommendationState.affordabilityReview;
    if (guarantorAsked && needsGuarantor) {
      return LandlordRecommendationState.guarantorReview;
    }

    final timingOk = d.moveInQuality.earnsTimingScore ||
        d.moveInQuality == TimingMatchQuality.none;
    final propertyOk = d.propertyRequirementMatch ||
        d.propertyRequirementLabel == 'Layout not specified';

    if (d.affordabilityMeetsTarget && timingOk && propertyOk) {
      return LandlordRecommendationState.inviteReady;
    }
    return LandlordRecommendationState.review;
  }
}
