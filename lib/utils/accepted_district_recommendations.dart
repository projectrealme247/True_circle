import '../config/market/dublin_commuter_hubs.dart';
import '../services/commute_scoring_service.dart';
import 'district_recommendation_ranker.dart';
import 'profile_data.dart';

/// Session / profile key for accepted district recommendation signals.
///
/// Orthogonal to [target_search_areas] (macros). Ranking must not read this
/// until an explicit soft-boost is approved.
const acceptedDistrictRecommendationsKey = 'accepted_district_recommendations';

/// One accepted district recommendation with score + commute context.
///
/// Preserves ranking fidelity that macro collapse would lose.
class AcceptedDistrictRecommendation {
  const AcceptedDistrictRecommendation({
    required this.districtKey,
    required this.recommendationScore,
    required this.destinationHubId,
    required this.destinationHubLabel,
    required this.transportMode,
    required this.maxTravelMinutes,
    required this.acceptedAt,
  });

  final String districtKey;

  /// [DistrictRecommendation.finalScore] at accept time (0–100).
  final double recommendationScore;

  final String destinationHubId;
  final String destinationHubLabel;
  final CommuteMethod transportMode;
  final int maxTravelMinutes;
  final DateTime acceptedAt;

  Map<String, dynamic> toJson() => {
        'district_key': districtKey,
        'recommendation_score': recommendationScore,
        'destination_hub_id': destinationHubId,
        'destination_hub_label': destinationHubLabel,
        'transport_mode': transportMode.toBackend(),
        'max_travel_minutes': maxTravelMinutes,
        'accepted_at': acceptedAt.toUtc().toIso8601String(),
      };

  static AcceptedDistrictRecommendation? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final districtKey = ProfileData.text(map['district_key']).trim().toLowerCase();
    if (districtKey.isEmpty) return null;

    final scoreRaw = map['recommendation_score'];
    final score = scoreRaw is num
        ? scoreRaw.toDouble()
        : double.tryParse(scoreRaw?.toString() ?? '');
    if (score == null) return null;

    final minutesRaw = map['max_travel_minutes'];
    final minutes = minutesRaw is num
        ? minutesRaw.round()
        : int.tryParse(minutesRaw?.toString() ?? '');
    if (minutes == null || minutes <= 0) return null;

    final acceptedAtRaw = ProfileData.text(map['accepted_at']);
    final acceptedAt = DateTime.tryParse(acceptedAtRaw)?.toUtc();
    if (acceptedAt == null) return null;

    final hubId = ProfileData.text(map['destination_hub_id']).trim();
    final hubLabel = ProfileData.text(map['destination_hub_label']).trim();
    if (hubId.isEmpty && hubLabel.isEmpty) return null;

    return AcceptedDistrictRecommendation(
      districtKey: districtKey,
      recommendationScore: score.clamp(0.0, 100.0),
      destinationHubId: hubId,
      destinationHubLabel: hubLabel,
      transportMode: CommuteMethod.fromBackend(
        ProfileData.text(map['transport_mode']),
      ),
      maxTravelMinutes: minutes,
      acceptedAt: acceptedAt,
    );
  }
}

/// Explicit Accept payload: district signals + macro compatibility tokens.
class DistrictRecommendationAcceptance {
  const DistrictRecommendationAcceptance({
    required this.districts,
    required this.macros,
  });

  final List<AcceptedDistrictRecommendation> districts;

  /// Covering macros for [target_search_areas] compatibility (unchanged path).
  final List<String> macros;

  bool get isEmpty => districts.isEmpty && macros.isEmpty;
}

/// Encode / decode helpers for profile + session maps.
abstract final class AcceptedDistrictRecommendations {
  /// Build accept rows from live ranker output + commute context.
  static DistrictRecommendationAcceptance fromRanked({
    required List<DistrictRecommendation> recommendations,
    required List<String> macros,
    required DublinCommuterHub destinationHub,
    required CommuteMethod transportMode,
    required int maxTravelMinutes,
    DateTime? acceptedAt,
  }) {
    final at = (acceptedAt ?? DateTime.now()).toUtc();
    final districts = [
      for (final row in recommendations)
        AcceptedDistrictRecommendation(
          districtKey: row.districtKey,
          recommendationScore: row.finalScore,
          destinationHubId: destinationHub.id,
          destinationHubLabel: destinationHub.label,
          transportMode: transportMode,
          maxTravelMinutes: maxTravelMinutes,
          acceptedAt: at,
        ),
    ];
    return DistrictRecommendationAcceptance(
      districts: List.unmodifiable(districts),
      macros: List.unmodifiable(macros),
    );
  }

  static List<AcceptedDistrictRecommendation> hydrateFromSession(
    Map<String, dynamic>? session,
  ) {
    if (session == null) return const [];
    final raw = session[acceptedDistrictRecommendationsKey];
    if (raw is! List) return const [];
    final out = <AcceptedDistrictRecommendation>[];
    for (final entry in raw) {
      final parsed = AcceptedDistrictRecommendation.fromJson(entry);
      if (parsed != null) out.add(parsed);
    }
    return List.unmodifiable(out);
  }

  /// Profile / session fields to merge on save (does not touch macros).
  static Map<String, dynamic> payloadFields(
    List<AcceptedDistrictRecommendation> districts,
  ) {
    return {
      acceptedDistrictRecommendationsKey: [
        for (final row in districts) row.toJson(),
      ],
    };
  }

  /// Ordered district keys (highest score first) for future soft ranking.
  static List<String> districtKeys(
    List<AcceptedDistrictRecommendation> districts,
  ) {
    final sorted = [...districts]
      ..sort((a, b) {
        final byScore = b.recommendationScore.compareTo(a.recommendationScore);
        if (byScore != 0) return byScore;
        return a.districtKey.compareTo(b.districtKey);
      });
    return [for (final row in sorted) row.districtKey];
  }
}
