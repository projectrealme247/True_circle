import 'dart:math' as math;

import '../config/market/dublin_commuter_hubs.dart';
import '../config/market/dublin_transit_network.dart';
import '../utils/commute_profile.dart';
import '../utils/geo_math.dart';

export '../utils/geo_math.dart' show LatLng;

/// Seeker commute mode — persisted as snake_case on the profile row.
enum CommuteMethod {
  publicTransportWalking,
  driving;

  static const backendPublicTransportWalking = 'public_transport_walking';
  static const backendDriving = 'driving';

  static const displayPublicTransportWalking = 'Public Transport & Walking';
  static const displayDriving = 'Driving';

  static CommuteMethod fromBackend(String? raw) {
    switch (raw?.trim()) {
      case backendDriving:
        return CommuteMethod.driving;
      case backendPublicTransportWalking:
      default:
        return CommuteMethod.publicTransportWalking;
    }
  }

  static CommuteMethod fromDisplayLabel(String? label) {
    switch (label?.trim()) {
      case displayDriving:
        return CommuteMethod.driving;
      case displayPublicTransportWalking:
      default:
        return CommuteMethod.publicTransportWalking;
    }
  }

  String toBackend() {
    switch (this) {
      case CommuteMethod.driving:
        return backendDriving;
      case CommuteMethod.publicTransportWalking:
        return backendPublicTransportWalking;
    }
  }

  String toDisplayLabel() {
    switch (this) {
      case CommuteMethod.driving:
        return displayDriving;
      case CommuteMethod.publicTransportWalking:
        return displayPublicTransportWalking;
    }
  }
}

/// How dual-applicant households weight per-commuter compatibility scores.
enum DualCommutePriority { personA, personB, balanced }

/// Per-commuter score emitted by the multi-commute matrix.
class CommuteScoreResult {
  const CommuteScoreResult({
    required this.profileId,
    required this.profileLabel,
    required this.method,
    required this.hub,
    required this.minutes,
    this.parkingConflict = false,
  });

  final String profileId;
  final String profileLabel;
  final CommuteMethod method;
  final DublinCommuterHub hub;
  final int minutes;
  final bool parkingConflict;

  Map<String, dynamic> toMetadata() => {
        'profile_id': profileId,
        'profile_label': profileLabel,
        'commute_method': method.toBackend(),
        'commute_destination_hub_id': hub.id,
        'commute_destination': hub.label,
        'door_to_door_minutes': minutes,
        'parking_conflict': parkingConflict,
      };
}

/// Unified wrapper delivered to UI after parallel profile scoring.
class MultiCommuteScorePayload {
  const MultiCommuteScorePayload({
    required this.results,
    required this.worstCaseMinutes,
    this.commuterCompatibilityScores = const [],
    this.combinedCompatibilityScore,
  });

  final List<CommuteScoreResult> results;
  final int worstCaseMinutes;
  final List<double> commuterCompatibilityScores;
  final double? combinedCompatibilityScore;

  List<Map<String, dynamic>> toMetadataArray() =>
      results.map((result) => result.toMetadata()).toList(growable: false);

  bool meetsBudget(int? maximumCommuteBudgetMinutes) {
    if (maximumCommuteBudgetMinutes == null) return true;
    return worstCaseMinutes <= maximumCommuteBudgetMinutes;
  }
}

/// Path B time-over-distance matrix — returns door-to-door minutes only.
abstract final class CommuteScoringService {
  static const rushHourDrivingPenaltyMinutes = 8;

  /// Match-score deduction per minute a listing exceeds the seeker's commute budget.
  static const overBudgetPenaltyPerMinute = 2;

  static const parkingConflictWarning =
      '(⚠️ Parking Permit Required / No Host Parking)';

  /// Gradual compatibility penalty — never hard-excludes listings from the feed.
  static int overBudgetScorePenalty({
    required int doorToDoorMinutes,
    required int budgetMinutes,
  }) {
    final over = doorToDoorMinutes - budgetMinutes;
    if (over <= 0) return 0;
    return over * overBudgetPenaltyPerMinute;
  }

  /// 0–100 compatibility from door-to-door minutes vs per-commuter budget.
  static double commuteCompatibilityScore({
    required int doorToDoorMinutes,
    required int budgetMinutes,
  }) {
    if (budgetMinutes <= 0) return 100.0;
    final score = 100.0 - (doorToDoorMinutes / budgetMinutes) * 100.0;
    return score.clamp(0.0, 100.0);
  }

  /// Applies household priority when two commuter scores are available.
  static double resolveDualCommutePriorityScore({
    required double scoreA,
    required double scoreB,
    required DualCommutePriority priority,
  }) {
    switch (priority) {
      case DualCommutePriority.personA:
        return scoreA.clamp(0.0, 100.0);
      case DualCommutePriority.personB:
        return scoreB.clamp(0.0, 100.0);
      case DualCommutePriority.balanced:
        final gap = (scoreA - scoreB).abs();
        var combined = (scoreA + scoreB) / 2;
        if (gap > 30) {
          combined -= (gap - 30) * 0.5;
        }
        return combined.clamp(0.0, 100.0);
    }
  }

  static MultiCommuteScorePayload _attachCompatibilityScores({
    required MultiCommuteScorePayload payload,
    required List<CommuteProfileEntry> profiles,
    required DualCommutePriority priority,
    required int Function(CommuteProfileEntry profile, int index) budgetForProfile,
  }) {
    if (payload.results.isEmpty) return payload;

    final scores = <double>[];
    for (var i = 0; i < payload.results.length; i++) {
      final profile = i < profiles.length ? profiles[i] : profiles.last;
      final budget = budgetForProfile(profile, i);
      scores.add(
        commuteCompatibilityScore(
          doorToDoorMinutes: payload.results[i].minutes,
          budgetMinutes: budget,
        ),
      );
    }

    double? combined;
    if (scores.length >= 2) {
      combined = resolveDualCommutePriorityScore(
        scoreA: scores[0],
        scoreB: scores[1],
        priority: priority,
      );
    } else if (scores.isNotEmpty) {
      combined = scores.first;
    }

    return MultiCommuteScorePayload(
      results: payload.results,
      worstCaseMinutes: payload.worstCaseMinutes,
      commuterCompatibilityScores: scores,
      combinedCompatibilityScore: combined,
    );
  }

  /// Total door-to-door commute time in minutes (never kilometres).
  static int calculateCommuteMinutes(
    LatLng propertyLoc,
    LatLng destinationHub,
    CommuteMethod method,
  ) {
    switch (method) {
      case CommuteMethod.publicTransportWalking:
        return _publicTransportDoorToDoorMinutes(propertyLoc, destinationHub);
      case CommuteMethod.driving:
        return _drivingDoorToDoorMinutes(propertyLoc, destinationHub);
    }
  }

  /// Convenience overload when the hub registry node is already resolved.
  static int calculateCommuteMinutesToHub(
    LatLng propertyLoc,
    DublinCommuterHub hub,
    CommuteMethod method,
  ) =>
      calculateCommuteMinutes(propertyLoc, hub.location, method);

  /// Independent parallel scoring per commuter profile (async isolate-friendly).
  static Future<MultiCommuteScorePayload> calculateMultiCommuteMinutesAsync({
    required LatLng propertyLoc,
    required List<CommuteProfileEntry> profiles,
    bool parkingAvailable = true,
    DualCommutePriority dualCommutePriority = DualCommutePriority.balanced,
    int Function(CommuteProfileEntry profile, int index)? budgetForProfile,
  }) async {
    if (profiles.isEmpty) {
      return const MultiCommuteScorePayload(results: [], worstCaseMinutes: 0);
    }

    final resolveBudget = budgetForProfile ??
        (profile, index) => profile.maxCommuteMinutes ?? 45;

    final tasks = profiles.map((profile) {
      return Future<CommuteScoreResult>(() {
        final minutes = calculateCommuteMinutesToHub(
          propertyLoc,
          profile.hub,
          profile.method,
        );
        final parkingConflict =
            profile.method == CommuteMethod.driving && !parkingAvailable;
        return CommuteScoreResult(
          profileId: profile.id,
          profileLabel: profile.label,
          method: profile.method,
          hub: profile.hub,
          minutes: minutes,
          parkingConflict: parkingConflict,
        );
      });
    });

    final results = await Future.wait(tasks);
    final worst = results.map((result) => result.minutes).reduce(math.max);
    return _attachCompatibilityScores(
      payload: MultiCommuteScorePayload(results: results, worstCaseMinutes: worst),
      profiles: profiles,
      priority: dualCommutePriority,
      budgetForProfile: resolveBudget,
    );
  }

  /// Sync multi-commute scoring with dual-applicant priority resolution.
  static MultiCommuteScorePayload calculateMultiCommuteMinutes({
    required LatLng propertyLoc,
    required List<CommuteProfileEntry> profiles,
    bool parkingAvailable = true,
    DualCommutePriority dualCommutePriority = DualCommutePriority.balanced,
    int Function(CommuteProfileEntry profile, int index)? budgetForProfile,
  }) {
    if (profiles.isEmpty) {
      return const MultiCommuteScorePayload(results: [], worstCaseMinutes: 0);
    }

    final resolveBudget = budgetForProfile ??
        (profile, index) => profile.maxCommuteMinutes ?? 45;

    final results = profiles.map((profile) {
      final minutes = calculateCommuteMinutesToHub(
        propertyLoc,
        profile.hub,
        profile.method,
      );
      final parkingConflict =
          profile.method == CommuteMethod.driving && !parkingAvailable;
      return CommuteScoreResult(
        profileId: profile.id,
        profileLabel: profile.label,
        method: profile.method,
        hub: profile.hub,
        minutes: minutes,
        parkingConflict: parkingConflict,
      );
    }).toList(growable: false);

    final worst = results.map((result) => result.minutes).reduce(math.max);
    return _attachCompatibilityScores(
      payload: MultiCommuteScorePayload(results: results, worstCaseMinutes: worst),
      profiles: profiles,
      priority: dualCommutePriority,
      budgetForProfile: resolveBudget,
    );
  }

  static int _publicTransportDoorToDoorMinutes(
    LatLng propertyLoc,
    LatLng destinationHub,
  ) {
    final nearestStop = DublinTransitNetwork.nearestTo(propertyLoc);
    final walkMinutes =
        DublinTransitNetwork.walkMinutesFromProperty(propertyLoc, nearestStop);

    final hub = DublinCommuterHubs.resolveFromProfile({
      'destination_latitude': destinationHub.latitude,
      'destination_longitude': destinationHub.longitude,
    });
    final hubAnchor = hub != null
        ? DublinTransitNetwork.byId(hub.anchorStationId)
        : DublinTransitNetwork.nearestTo(destinationHub);

    final anchor = hubAnchor ?? DublinTransitNetwork.nearestTo(destinationHub);
    final lineMinutes =
        DublinTransitNetwork.lineTravelMinutes(nearestStop, anchor);

    return math.max(1, walkMinutes + lineMinutes);
  }

  static int _drivingDoorToDoorMinutes(
    LatLng propertyLoc,
    LatLng destinationHub,
  ) {
    final km = GeoMath.haversineKm(propertyLoc, destinationHub);
    final driveMinutes = GeoMath.drivingMinutes(km);
    return math.max(1, driveMinutes + rushHourDrivingPenaltyMinutes);
  }
}
