import '../config/market/dublin_commuter_hubs.dart';
import '../config/market/dublin_macro_areas.dart';
import '../models/seeker_onboarding_enums.dart';
import '../services/commute_scoring_service.dart';
import 'district_commute_snapshot.dart';
import 'district_inventory_stats.dart';
import 'district_recommendation_ranker.dart';

/// Kind of explanation bullet (priority order for V1).
enum RecommendationReasonKind {
  commute,
  budget,
  persona,
  inventory,
}

/// Single display-ready reason line (deterministic template text).
class RecommendationReason {
  const RecommendationReason({
    required this.kind,
    required this.text,
  });

  final RecommendationReasonKind kind;

  /// Plain reason copy without a leading checkmark — UI may prefix `✓`.
  final String text;
}

/// Deterministic explanation for one [DistrictRecommendation].
class DistrictRecommendationExplanation {
  const DistrictRecommendationExplanation({
    required this.districtKey,
    required this.districtLabel,
    required this.reasons,
  });

  final String districtKey;

  /// Short district label for UI headers (e.g. `Dublin 1`).
  final String districtLabel;

  /// At most [DistrictRecommendationExplainer.maxReasons] reasons,
  /// ordered: commute → budget → persona → inventory.
  final List<RecommendationReason> reasons;

  /// Convenience: reason texts only.
  List<String> get reasonTexts =>
      [for (final reason in reasons) reason.text];
}

/// Context for explanation templates (persona + budget + destination).
class DistrictExplanationContext {
  const DistrictExplanationContext({
    required this.persona,
    required this.budgetMax,
    required this.destinationHub,
    required this.transportMode,
  });

  final SeekerPersona? persona;
  final int budgetMax;
  final DublinCommuterHub destinationHub;
  final CommuteMethod transportMode;

  factory DistrictExplanationContext.fromRequest(
    DistrictRecommendationRequest request,
  ) {
    return DistrictExplanationContext(
      persona: request.persona,
      budgetMax: request.budgetMax,
      destinationHub: request.destinationHub,
      transportMode: request.transportMode,
    );
  }
}

/// V1 recommendation explanation engine.
///
/// Pure, deterministic templates from ranking outputs. Does **not** change
/// scores, ranking, or onboarding. Same inputs → same explanation.
abstract final class DistrictRecommendationExplainer {
  static const maxReasons = 4;

  /// Shared-living share floor for student "Popular with students".
  static const studentSharedShareFloor = 0.25;

  /// Independent-place share floor for professional supply copy.
  static const professionalIndependentShareFloor = 0.40;

  /// Affordability share floor for "Within your budget".
  static const withinBudgetShareFloor = 0.50;

  /// Family bed floor (aligned with ranker V1).
  static const familyMinBeds = DistrictRecommendationRanker.familyMinBeds;

  static DistrictRecommendationExplanation explain({
    required DistrictRecommendation recommendation,
    required DistrictInventoryStats inventory,
    required DistrictCommuteEligibility commute,
    required DistrictExplanationContext context,
  }) {
    assert(recommendation.districtKey == inventory.districtKey);
    assert(recommendation.districtKey == commute.districtKey);

    final reasons = <RecommendationReason>[];

    final commuteReason = _commuteReason(commute: commute, context: context);
    if (commuteReason != null) reasons.add(commuteReason);

    final budgetReason = _budgetReason(
      inventory: inventory,
      budgetMax: context.budgetMax,
      affordabilityScore: recommendation.affordabilityScore,
    );
    if (budgetReason != null) reasons.add(budgetReason);

    final personaReason = _personaReason(
      persona: context.persona,
      inventory: inventory,
    );
    if (personaReason != null) reasons.add(personaReason);

    final inventoryReason = _inventoryReason(inventory.listingCount);
    if (inventoryReason != null) reasons.add(inventoryReason);

    return DistrictRecommendationExplanation(
      districtKey: recommendation.districtKey,
      districtLabel: DublinMacroAreas.labelFor(recommendation.districtKey),
      reasons: List.unmodifiable(reasons.take(maxReasons)),
    );
  }

  /// Explain each ranked district when inventory + commute rows are available.
  static List<DistrictRecommendationExplanation> explainAll({
    required List<DistrictRecommendation> recommendations,
    required DistrictInventorySnapshot inventory,
    required DistrictCommuteSnapshot commute,
    required DistrictExplanationContext context,
  }) {
    final out = <DistrictRecommendationExplanation>[];
    for (final recommendation in recommendations) {
      final stats = inventory[recommendation.districtKey];
      final eligibility = commute[recommendation.districtKey];
      if (stats == null || eligibility == null) continue;
      out.add(
        explain(
          recommendation: recommendation,
          inventory: stats,
          commute: eligibility,
          context: context,
        ),
      );
    }
    return List.unmodifiable(out);
  }
}

RecommendationReason? _commuteReason({
  required DistrictCommuteEligibility commute,
  required DistrictExplanationContext context,
}) {
  final minutes = commute.estimatedMinutes;
  if (minutes <= 0) return null;

  final low = _minuteBandLow(minutes);
  final high = low + 20;
  final hub = _shortHubLabel(
    commute.destinationHubLabel.isNotEmpty
        ? commute.destinationHubLabel
        : context.destinationHub.label,
  );
  final mode = context.transportMode;

  final text = switch (mode) {
    CommuteMethod.publicTransportWalking =>
      '~$low–$high mins by public transport to $hub',
    CommuteMethod.driving => '~$low–$high mins by car to $hub',
  };

  return RecommendationReason(
    kind: RecommendationReasonKind.commute,
    text: text,
  );
}

RecommendationReason? _budgetReason({
  required DistrictInventoryStats inventory,
  required int budgetMax,
  required double affordabilityScore,
}) {
  if (budgetMax <= 0) return null;

  final share = inventory.shareAtOrBelowBudget(budgetMax);
  final median = inventory.medianRent;
  final minRent = inventory.parsedRents.isEmpty
      ? null
      : inventory.parsedRents.reduce((a, b) => a < b ? a : b);

  final withinBudget = (share != null && share >= DistrictRecommendationExplainer.withinBudgetShareFloor) ||
      (median != null && median <= budgetMax) ||
      affordabilityScore >= 70;

  if (withinBudget) {
    return RecommendationReason(
      kind: RecommendationReasonKind.budget,
      text: 'Within your ${_formatEuro(budgetMax)} budget',
    );
  }

  if (minRent != null) {
    return RecommendationReason(
      kind: RecommendationReasonKind.budget,
      text: 'Listings available from ${_formatEuro(minRent)}/mo',
    );
  }

  if (median != null) {
    return RecommendationReason(
      kind: RecommendationReasonKind.budget,
      text: 'Median around ${_formatEuro(median.round())}/mo',
    );
  }

  return null;
}

RecommendationReason? _personaReason({
  required SeekerPersona? persona,
  required DistrictInventoryStats inventory,
}) {
  final resolved = persona == SeekerPersona.relocating
      ? SeekerPersona.professional
      : persona;

  return switch (resolved) {
    SeekerPersona.student => _studentPersonaReason(inventory),
    SeekerPersona.professional => _professionalPersonaReason(inventory),
    SeekerPersona.family => _familyPersonaReason(inventory),
    SeekerPersona.relocating || null => null,
  };
}

RecommendationReason? _studentPersonaReason(DistrictInventoryStats inventory) {
  if (inventory.sharedLivingShare >=
      DistrictRecommendationExplainer.studentSharedShareFloor) {
    return const RecommendationReason(
      kind: RecommendationReasonKind.persona,
      text: 'Popular with students',
    );
  }
  if (inventory.sharedLivingCount > 0) {
    return const RecommendationReason(
      kind: RecommendationReasonKind.persona,
      text: 'Shared living available',
    );
  }
  return null;
}

RecommendationReason? _professionalPersonaReason(
  DistrictInventoryStats inventory,
) {
  if (inventory.independentPlaceShare >=
      DistrictRecommendationExplainer.professionalIndependentShareFloor) {
    return const RecommendationReason(
      kind: RecommendationReasonKind.persona,
      text: 'Strong independent-place supply',
    );
  }
  if (inventory.independentPlaceCount > 0) {
    return const RecommendationReason(
      kind: RecommendationReasonKind.persona,
      text: 'Independent places available',
    );
  }
  return null;
}

RecommendationReason? _familyPersonaReason(DistrictInventoryStats inventory) {
  final larger = inventory.listingsWithAtLeastBeds(
    DistrictRecommendationExplainer.familyMinBeds,
  );
  if (larger > 0) {
    return const RecommendationReason(
      kind: RecommendationReasonKind.persona,
      text: 'Family-sized homes available',
    );
  }
  return null;
}

RecommendationReason? _inventoryReason(int listingCount) {
  if (listingCount <= 0) return null;
  final noun = listingCount == 1 ? 'listing' : 'listings';
  return RecommendationReason(
    kind: RecommendationReasonKind.inventory,
    text: '$listingCount active $noun',
  );
}

/// ±10-style band anchored on estimated minutes (stepped to 5).
int _minuteBandLow(int estimatedMinutes) {
  final raw = estimatedMinutes - 10;
  final stepped = (raw / 5).floor() * 5;
  return stepped < 5 ? 5 : stepped;
}

String _shortHubLabel(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) return 'destination';

  final paren = RegExp(r'\(([A-Za-z0-9]+)\)').firstMatch(trimmed);
  if (paren != null) return paren.group(1)!;

  if (trimmed.contains('/')) {
    return trimmed.split('/').first.trim();
  }

  // Keep labels short for chips; drop trailing parenthetical prose if any.
  final beforeParen = trimmed.split('(').first.trim();
  return beforeParen.isEmpty ? trimmed : beforeParen;
}

String _formatEuro(int amount) {
  final digits = amount.abs().toString();
  final buf = StringBuffer(amount < 0 ? '-€' : '€');
  for (var i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    if (i > 0 && fromEnd % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}
