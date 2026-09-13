import '../config/market/dublin_commuter_hubs.dart';
import '../config/market/dublin_districts.dart';
import '../config/market/dublin_macro_areas.dart';
import '../services/commute_scoring_service.dart';

/// Per-district commute eligibility vs a seeker destination (soft signal only).
///
/// Minutes are a **centroid approximation**, not listing-accurate door-to-door.
class DistrictCommuteEligibility {
  const DistrictCommuteEligibility({
    required this.districtKey,
    required this.estimatedMinutes,
    required this.eligible,
    required this.commuteScore,
    required this.destinationHubId,
    required this.destinationHubLabel,
    required this.transportMode,
    required this.maxTravelMinutes,
  });

  final String districtKey;

  /// Door-to-door minutes from district centroid → destination hub.
  final int estimatedMinutes;

  /// True when [estimatedMinutes] ≤ [maxTravelMinutes].
  final bool eligible;

  /// 0–100 compatibility from [CommuteScoringService.commuteCompatibilityScore].
  final double commuteScore;

  final String destinationHubId;
  final String destinationHubLabel;
  final CommuteMethod transportMode;
  final int maxTravelMinutes;
}

/// In-memory district commute matrix for one destination + mode + budget.
///
/// Sits beside [DistrictInventorySnapshot]. Rebuild when destination inputs
/// change. Not a ranking layer and not a browse hard filter.
class DistrictCommuteSnapshot {
  const DistrictCommuteSnapshot({
    required this.byDistrict,
    required this.destinationHub,
    required this.transportMode,
    required this.maxTravelMinutes,
    required this.unresolvedDistrictKeys,
    required this.builtAt,
  });

  final Map<String, DistrictCommuteEligibility> byDistrict;
  final DublinCommuterHub destinationHub;
  final CommuteMethod transportMode;
  final int maxTravelMinutes;

  /// Known district keys that could not be scored (missing centroid).
  final List<String> unresolvedDistrictKeys;

  final DateTime builtAt;

  DistrictCommuteEligibility? operator [](String districtKey) =>
      byDistrict[districtKey];

  Iterable<String> get districtKeys => byDistrict.keys;

  Iterable<DistrictCommuteEligibility> get eligibleDistricts =>
      byDistrict.values.where((entry) => entry.eligible);

  int get scoredDistrictCount => byDistrict.length;

  int get eligibleDistrictCount =>
      byDistrict.values.where((entry) => entry.eligible).length;

  /// Scores every canonical Dublin district against [destinationHub].
  ///
  /// Complexity: O(D) with D = district catalog size (~24). Pure local math.
  static DistrictCommuteSnapshot build({
    required DublinCommuterHub destinationHub,
    required CommuteMethod transportMode,
    required int maxTravelMinutes,
    Iterable<String>? districtKeys,
    DateTime? builtAt,
  }) {
    final keys = districtKeys ??
        [
          for (final (key, _) in dublinAreaOptions) key,
        ];

    final byDistrict = <String, DistrictCommuteEligibility>{};
    final unresolved = <String>[];
    final budget = maxTravelMinutes <= 0 ? 1 : maxTravelMinutes;

    for (final rawKey in keys) {
      final key = rawKey.trim().toLowerCase();
      if (key.isEmpty || !DublinMacroAreas.isDistrictKey(key)) {
        unresolved.add(rawKey);
        continue;
      }

      final label = dublinDistrictLabelForKey(key) ?? key;
      final centroid = dublinDistrictCentroidFromLabel(label);
      if (centroid == null) {
        unresolved.add(key);
        continue;
      }

      final minutes = CommuteScoringService.calculateCommuteMinutesToHub(
        LatLng(centroid.lat, centroid.lon),
        destinationHub,
        transportMode,
      );
      final score = CommuteScoringService.commuteCompatibilityScore(
        doorToDoorMinutes: minutes,
        budgetMinutes: budget,
      );

      byDistrict[key] = DistrictCommuteEligibility(
        districtKey: key,
        estimatedMinutes: minutes,
        eligible: minutes <= maxTravelMinutes,
        commuteScore: score,
        destinationHubId: destinationHub.id,
        destinationHubLabel: destinationHub.label,
        transportMode: transportMode,
        maxTravelMinutes: maxTravelMinutes,
      );
    }

    return DistrictCommuteSnapshot(
      byDistrict: Map.unmodifiable(byDistrict),
      destinationHub: destinationHub,
      transportMode: transportMode,
      maxTravelMinutes: maxTravelMinutes,
      unresolvedDistrictKeys: List.unmodifiable(unresolved),
      builtAt: builtAt ?? DateTime.now(),
    );
  }
}
