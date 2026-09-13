import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/config/market/dublin_commuter_hubs.dart';
import 'package:true_circle/services/commute_scoring_service.dart';
import 'package:true_circle/utils/accepted_district_recommendations.dart';
import 'package:true_circle/utils/district_recommendation_ranker.dart';
import 'package:true_circle/utils/viewer_profile.dart';

void main() {
  group('AcceptedDistrictRecommendations', () {
    test('round-trips district fidelity fields', () {
      final acceptance = AcceptedDistrictRecommendations.fromRanked(
        recommendations: const [
          DistrictRecommendation(
            districtKey: 'dublin1',
            finalScore: 78.4,
            commuteScore: 72,
            affordabilityScore: 100,
            inventoryScore: 65,
            personaScore: 74,
            estimatedMinutes: 25,
          ),
          DistrictRecommendation(
            districtKey: 'dublin8',
            finalScore: 71.2,
            commuteScore: 68,
            affordabilityScore: 90,
            inventoryScore: 65,
            personaScore: 70,
            estimatedMinutes: 30,
          ),
        ],
        macros: const ['MACRO_CITY_CENTRE'],
        destinationHub: DublinCommuterHubs.tcd,
        transportMode: CommuteMethod.publicTransportWalking,
        maxTravelMinutes: 60,
        acceptedAt: DateTime.utc(2026, 7, 18, 14, 0),
      );

      expect(acceptance.districts, hasLength(2));
      expect(acceptance.macros, ['MACRO_CITY_CENTRE']);

      final payload =
          AcceptedDistrictRecommendations.payloadFields(acceptance.districts);
      final hydrated = AcceptedDistrictRecommendations.hydrateFromSession({
        ...payload,
      });

      expect(hydrated, hasLength(2));
      expect(hydrated.first.districtKey, 'dublin1');
      expect(hydrated.first.recommendationScore, closeTo(78.4, 0.001));
      expect(hydrated.first.destinationHubId, DublinCommuterHubs.tcd.id);
      expect(hydrated.first.destinationHubLabel, DublinCommuterHubs.tcd.label);
      expect(
        hydrated.first.transportMode,
        CommuteMethod.publicTransportWalking,
      );
      expect(hydrated.first.maxTravelMinutes, 60);
      expect(
        hydrated.first.acceptedAt.toUtc(),
        DateTime.utc(2026, 7, 18, 14, 0),
      );

      expect(
        AcceptedDistrictRecommendations.districtKeys(hydrated),
        ['dublin1', 'dublin8'],
      );
    });

    test('ViewerProfile hydrates accepted districts without affecting macros', () {
      final profile = ViewerProfile.fromSession({
        'detected_city': 'Dublin',
        'budget_max': 2000,
        'target_search_areas': ['MACRO_CITY_CENTRE'],
        acceptedDistrictRecommendationsKey: [
          {
            'district_key': 'dublin1',
            'recommendation_score': 80,
            'destination_hub_id': DublinCommuterHubs.tcd.id,
            'destination_hub_label': DublinCommuterHubs.tcd.label,
            'transport_mode': 'public_transport_walking',
            'max_travel_minutes': 60,
            'accepted_at': '2026-07-18T14:00:00.000Z',
          },
        ],
      });

      expect(profile, isNotNull);
      expect(profile!.targetSearchAreas, contains('MACRO_CITY_CENTRE'));
      expect(profile.acceptedDistrictRecommendations, hasLength(1));
      expect(
        profile.acceptedDistrictRecommendations.first.districtKey,
        'dublin1',
      );
    });
  });
}
