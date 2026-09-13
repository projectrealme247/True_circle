import 'applicant_trust_tier.dart';
import 'landlord_recommendation_state.dart';

/// Entire place vs shared living — drives Col 2 / Col 3 decision models.
enum ListingType {
  entirePlace('Entire Place', '🏡'),
  sharedLiving('Shared Living', '🔑');

  const ListingType(this.label, this.emoji);
  final String label;
  final String emoji;

  bool get isShared => this == sharedLiving;
}

/// Col 3 verdict chip — the decision cue (not match %).
enum DecisionVerdict {
  recommended('RECOMMENDED'),
  needsReview('NEEDS REVIEW'),
  viewingInvited('VIEWING INVITED'),
  notSuitable('NOT SUITABLE');

  const DecisionVerdict(this.label);
  final String label;

  /// Section eyebrow above the why-prose block.
  String get whySectionTitle => switch (this) {
        DecisionVerdict.recommended => 'Why recommended',
        DecisionVerdict.needsReview => 'Why review',
        DecisionVerdict.viewingInvited => 'Why invited',
        DecisionVerdict.notSuitable => 'Why not suitable',
      };
}

/// Host listing row for Col 1 (listings rail).
class Listing {
  const Listing({
    required this.id,
    required this.title,
    required this.type,
    required this.applicantCount,
    this.subtitle,
    this.inviteReadyCount = 0,
    this.reviewCount = 0,
    this.notSuitableCount = 0,
    this.applicants = const [],
  });

  final String id;
  final String title;
  final String? subtitle;
  final ListingType type;
  final int applicantCount;
  final int inviteReadyCount;
  final int reviewCount;
  final int notSuitableCount;

  /// Applicants for this listing — consumed by TriageCol / DecisionCol.
  final List<Applicant> applicants;
}

/// Lightweight applicant model for the landlord decision engine (mock-first).
class Applicant {
  const Applicant({
    required this.id,
    required this.name,
    required this.trustTier,
    required this.recommendation,
    required this.affordabilityMultiplier,
    required this.moveInLabel,
    required this.propertyLabel,
    required this.propertyMatch,
    this.matchPercent = 0,
    this.viewingInvited = false,
    this.affordabilityMeetsTarget = true,
    this.householdLabel,
    this.hasPets = false,
    this.leaseLabel,
    this.lifestylePercent,
    this.foodCompatible,
    this.smokingCompatible,
    this.languages = const [],
    this.commuteLabel,
    this.employmentVerified = false,
    this.incomeVerified = false,
    this.guarantorLabel,
    this.stabilityBullet,
  });

  final String id;
  final String name;
  final ApplicantTrustTier trustTier;
  /// Used by triage queue only — never shown in DecisionCol.
  final int matchPercent;
  final LandlordRecommendationState recommendation;
  final bool viewingInvited;

  final double affordabilityMultiplier;
  final bool affordabilityMeetsTarget;
  final String moveInLabel;
  final String propertyLabel;
  final bool propertyMatch;

  /// Entire Place
  final String? householdLabel;
  final bool hasPets;
  final String? leaseLabel;

  /// Shared Living
  final int? lifestylePercent;
  final bool? foodCompatible;
  final bool? smokingCompatible;
  final List<String> languages;
  final String? commuteLabel;

  final bool employmentVerified;
  final bool incomeVerified;
  final String? guarantorLabel;

  /// Human-readable Why Recommended stability bullet (Entire Place).
  final String? stabilityBullet;

  DecisionVerdict get verdict {
    if (viewingInvited) return DecisionVerdict.viewingInvited;
    if (recommendation == LandlordRecommendationState.notSuitable) {
      return DecisionVerdict.notSuitable;
    }
    if (recommendation == LandlordRecommendationState.inviteReady) {
      return DecisionVerdict.recommended;
    }
    return DecisionVerdict.needsReview;
  }
}
