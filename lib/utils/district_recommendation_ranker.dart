import '../config/market/dublin_commuter_hubs.dart';
import '../models/seeker_onboarding_enums.dart';
import '../services/commute_scoring_service.dart';
import 'district_commute_snapshot.dart';
import 'district_inventory_stats.dart';

/// Ranked district recommendation (scores only — no copy, no UI).
class DistrictRecommendation {
  const DistrictRecommendation({
    required this.districtKey,
    required this.finalScore,
    required this.commuteScore,
    required this.affordabilityScore,
    required this.inventoryScore,
    required this.personaScore,
    required this.estimatedMinutes,
  });

  final String districtKey;
  final double finalScore;
  final double commuteScore;
  final double affordabilityScore;
  final double inventoryScore;
  final double personaScore;
  final int estimatedMinutes;
}

/// Soft ranking inputs already available from seeker onboarding / session.
class DistrictRecommendationRequest {
  const DistrictRecommendationRequest({
    required this.persona,
    required this.budgetMax,
    required this.destinationHub,
    required this.transportMode,
    required this.maxTravelMinutes,
  });

  final SeekerPersona? persona;
  final int budgetMax;
  final DublinCommuterHub destinationHub;
  final CommuteMethod transportMode;
  final int maxTravelMinutes;
}

/// V1 district recommendation ranker.
///
/// Combines [DistrictCommuteSnapshot] + [DistrictInventorySnapshot] into an
/// ordered soft ranking. Does **not** hard-filter browse / homepage results.
abstract final class DistrictRecommendationRanker {
  /// Weights sum to 1.0 — commute-led V1.
  static const commuteWeight = 0.40;
  static const affordabilityWeight = 0.25;
  static const inventoryWeight = 0.15;
  static const personaWeight = 0.20;

  /// Soft inventory availability bands (scores only — not hard thresholds).
  static const inventoryHighScore = 100.0;
  static const inventoryMediumScore = 65.0;
  static const inventoryLimitedScore = 35.0;
  static const inventoryEmptyScore = 10.0;

  /// Family "larger home" bed floor for V1.
  static const familyMinBeds = 3;

  /// Rank eligible districts. Empty when no commute-eligible districts remain.
  static List<DistrictRecommendation> rank({
    required DistrictRecommendationRequest request,
    required DistrictInventorySnapshot inventory,
    DistrictCommuteSnapshot? commute,
  }) {
    final commuteSnapshot = commute ??
        DistrictCommuteSnapshot.build(
          destinationHub: request.destinationHub,
          transportMode: request.transportMode,
          maxTravelMinutes: request.maxTravelMinutes,
        );

    final ranked = <DistrictRecommendation>[];

    for (final eligibility in commuteSnapshot.eligibleDistricts) {
      final stats = inventory[eligibility.districtKey];
      if (stats == null || stats.listingCount <= 0) {
        continue;
      }

      final affordability = _affordabilityScore(
        stats: stats,
        budgetMax: request.budgetMax,
      );
      // Soft drop only when we have rent data and nothing is affordable.
      if (affordability.hardEmptyAffordability) {
        continue;
      }

      final inventoryScore = _inventoryScore(stats.listingCount);
      final personaScore = _personaScore(
        persona: request.persona,
        stats: stats,
        affordabilityScore: affordability.score,
        commuteScore: eligibility.commuteScore,
      );

      final finalScore = (eligibility.commuteScore * commuteWeight) +
          (affordability.score * affordabilityWeight) +
          (inventoryScore * inventoryWeight) +
          (personaScore * personaWeight);

      ranked.add(
        DistrictRecommendation(
          districtKey: eligibility.districtKey,
          finalScore: finalScore.clamp(0.0, 100.0),
          commuteScore: eligibility.commuteScore,
          affordabilityScore: affordability.score,
          inventoryScore: inventoryScore,
          personaScore: personaScore,
          estimatedMinutes: eligibility.estimatedMinutes,
        ),
      );
    }

    ranked.sort((a, b) {
      final byScore = b.finalScore.compareTo(a.finalScore);
      if (byScore != 0) return byScore;
      final byMinutes = a.estimatedMinutes.compareTo(b.estimatedMinutes);
      if (byMinutes != 0) return byMinutes;
      return a.districtKey.compareTo(b.districtKey);
    });

    return List.unmodifiable(ranked);
  }
}

class _AffordabilityResult {
  const _AffordabilityResult({
    required this.score,
    required this.hardEmptyAffordability,
  });

  final double score;
  final bool hardEmptyAffordability;
}

_AffordabilityResult _affordabilityScore({
  required DistrictInventoryStats stats,
  required int budgetMax,
}) {
  if (budgetMax <= 0) {
    return const _AffordabilityResult(
      score: 50,
      hardEmptyAffordability: false,
    );
  }

  final share = stats.shareAtOrBelowBudget(budgetMax);
  final median = stats.medianRent;

  if (share == null && median == null) {
    // No rent signal — neutral, do not reject.
    return const _AffordabilityResult(
      score: 50,
      hardEmptyAffordability: false,
    );
  }

  if (share != null && share <= 0 && stats.parsedRents.isNotEmpty) {
    return const _AffordabilityResult(
      score: 0,
      hardEmptyAffordability: true,
    );
  }

  var score = 50.0;
  if (share != null) {
    score = share * 100.0;
  }

  if (median != null) {
    final medianRatio = median / budgetMax;
    final medianComponent = medianRatio <= 1.0
        ? 100.0
        : (medianRatio <= 1.15
            ? 70.0
            : (medianRatio <= 1.35 ? 40.0 : 15.0));
    score = share == null ? medianComponent : (score * 0.65 + medianComponent * 0.35);
  }

  return _AffordabilityResult(
    score: score.clamp(0.0, 100.0),
    hardEmptyAffordability: false,
  );
}

/// Soft availability bands from listing depth (no hard cutoffs for browse).
double _inventoryScore(int listingCount) {
  if (listingCount <= 0) return DistrictRecommendationRanker.inventoryEmptyScore;
  if (listingCount >= 8) return DistrictRecommendationRanker.inventoryHighScore;
  if (listingCount >= 3) {
    return DistrictRecommendationRanker.inventoryMediumScore;
  }
  return DistrictRecommendationRanker.inventoryLimitedScore;
}

double _personaScore({
  required SeekerPersona? persona,
  required DistrictInventoryStats stats,
  required double affordabilityScore,
  required double commuteScore,
}) {
  final resolved = persona == SeekerPersona.relocating
      ? SeekerPersona.professional
      : persona;

  return switch (resolved) {
    SeekerPersona.student => _studentPersonaScore(stats, affordabilityScore),
    SeekerPersona.professional => _professionalPersonaScore(stats),
    SeekerPersona.family => _familyPersonaScore(stats),
    SeekerPersona.relocating || null =>
      (affordabilityScore + commuteScore) / 2.0,
  };
}

double _studentPersonaScore(
  DistrictInventoryStats stats,
  double affordabilityScore,
) {
  final sharedShare = stats.sharedLivingShare;
  final sharedComponent = (sharedShare * 100.0).clamp(0.0, 100.0);
  // Prefer shared supply; still reward affordability.
  return sharedComponent * 0.55 + affordabilityScore * 0.45;
}

/// Professional persona — inventory / housing only (no commute signals).
///
/// Commute stays exclusively in the global commute component (40%).
double _professionalPersonaScore(DistrictInventoryStats stats) {
  final independentComponent =
      (stats.independentPlaceShare * 100.0).clamp(0.0, 100.0);
  final inventoryComponent = _inventoryScore(stats.listingCount);
  final suitabilityComponent = _professionalHousingSuitability(stats);

  return independentComponent * 0.55 +
      inventoryComponent * 0.25 +
      suitabilityComponent * 0.20;
}

/// Studio / 1–2 bed share — typical independent-place sizing for professionals.
double _professionalHousingSuitability(DistrictInventoryStats stats) {
  if (stats.listingCount <= 0) return 0;
  var suitableBeds = 0;
  for (final entry in stats.bedroomHistogram.entries) {
    if (entry.key >= 0 && entry.key <= 2) {
      suitableBeds += entry.value;
    }
  }
  return ((suitableBeds / stats.listingCount) * 100.0).clamp(0.0, 100.0);
}

double _familyPersonaScore(DistrictInventoryStats stats) {
  if (stats.listingCount <= 0) return 0;
  final largerHomes =
      stats.listingsWithAtLeastBeds(DistrictRecommendationRanker.familyMinBeds);
  final largerShare = largerHomes / stats.listingCount;
  final largerComponent = (largerShare * 100.0).clamp(0.0, 100.0);

  // Bedroom diversity bonus: more distinct bed buckets → slight lift.
  final diversity = stats.bedroomHistogram.length.clamp(0, 4) / 4.0;
  final diversityComponent = diversity * 100.0;

  return largerComponent * 0.75 + diversityComponent * 0.25;
}
