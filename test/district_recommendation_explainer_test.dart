import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/config/market/dublin_commuter_hubs.dart';
import 'package:true_circle/models/seeker_onboarding_enums.dart';
import 'package:true_circle/services/commute_scoring_service.dart';
import 'package:true_circle/utils/district_commute_snapshot.dart';
import 'package:true_circle/utils/district_inventory_stats.dart';
import 'package:true_circle/utils/district_recommendation_explainer.dart';
import 'package:true_circle/utils/district_recommendation_ranker.dart';

void main() {
  group('DistrictRecommendationExplainer', () {
    test('student explanation is deterministic and ordered', () {
      final inventory = DistrictInventoryStats(
        districtKey: 'dublin1',
        listingCount: 8,
        medianRent: 1200,
        averageRent: 1250,
        bedroomHistogram: const {0: 2, 1: 4, 2: 2},
        unknownBedroomCount: 0,
        sharedLivingCount: 5,
        independentPlaceCount: 3,
        parsedRents: const [900, 950, 1000, 1100, 1200, 1400, 1500, 1600],
      );

      final commute = DistrictCommuteEligibility(
        districtKey: 'dublin1',
        estimatedMinutes: 25,
        eligible: true,
        commuteScore: 72,
        destinationHubId: DublinCommuterHubs.tcd.id,
        destinationHubLabel: DublinCommuterHubs.tcd.label,
        transportMode: CommuteMethod.publicTransportWalking,
        maxTravelMinutes: 60,
      );

      final recommendation = DistrictRecommendation(
        districtKey: 'dublin1',
        finalScore: 78,
        commuteScore: 72,
        affordabilityScore: 90,
        inventoryScore: 100,
        personaScore: 80,
        estimatedMinutes: 25,
      );

      final context = DistrictExplanationContext(
        persona: SeekerPersona.student,
        budgetMax: 1500,
        destinationHub: DublinCommuterHubs.tcd,
        transportMode: CommuteMethod.publicTransportWalking,
      );

      final a = DistrictRecommendationExplainer.explain(
        recommendation: recommendation,
        inventory: inventory,
        commute: commute,
        context: context,
      );
      final b = DistrictRecommendationExplainer.explain(
        recommendation: recommendation,
        inventory: inventory,
        commute: commute,
        context: context,
      );

      expect(a.reasonTexts, equals(b.reasonTexts));
      expect(a.reasons.length, lessThanOrEqualTo(4));
      expect(a.reasons.map((r) => r.kind).toList(), [
        RecommendationReasonKind.commute,
        RecommendationReasonKind.budget,
        RecommendationReasonKind.persona,
        RecommendationReasonKind.inventory,
      ]);
      expect(
        a.reasonTexts,
        [
          '~15–35 mins by public transport to TCD',
          'Within your €1,500 budget',
          'Popular with students',
          '8 active listings',
        ],
      );

      // ignore: avoid_print
      print('student example: ${a.districtLabel} → ${a.reasonTexts}');
    });

    test('professional explanation matches template shape', () {
      final inventory = DistrictInventoryStats(
        districtKey: 'dublin1',
        listingCount: 11,
        medianRent: 1800,
        averageRent: 1850,
        bedroomHistogram: const {1: 4, 2: 7},
        unknownBedroomCount: 0,
        sharedLivingCount: 1,
        independentPlaceCount: 10,
        parsedRents: const [
          1500, 1600, 1700, 1800, 1900, 2000, 2100, 1700, 1750, 1850, 1950,
        ],
      );

      final commute = DistrictCommuteEligibility(
        districtKey: 'dublin1',
        estimatedMinutes: 30,
        eligible: true,
        commuteScore: 70,
        destinationHubId: DublinCommuterHubs.ifscDocklands.id,
        destinationHubLabel: DublinCommuterHubs.ifscDocklands.label,
        transportMode: CommuteMethod.publicTransportWalking,
        maxTravelMinutes: 60,
      );

      final explanation = DistrictRecommendationExplainer.explain(
        recommendation: DistrictRecommendation(
          districtKey: 'dublin1',
          finalScore: 80,
          commuteScore: 70,
          affordabilityScore: 85,
          inventoryScore: 100,
          personaScore: 75,
          estimatedMinutes: 30,
        ),
        inventory: inventory,
        commute: commute,
        context: DistrictExplanationContext(
          persona: SeekerPersona.professional,
          budgetMax: 2000,
          destinationHub: DublinCommuterHubs.ifscDocklands,
          transportMode: CommuteMethod.publicTransportWalking,
        ),
      );

      expect(
        explanation.reasonTexts,
        [
          '~20–40 mins by public transport to IFSC',
          'Within your €2,000 budget',
          'Strong independent-place supply',
          '11 active listings',
        ],
      );

      // ignore: avoid_print
      print('professional example: ${explanation.reasonTexts}');
    });

    test('family explanation uses family-sized homes copy', () {
      final inventory = DistrictInventoryStats(
        districtKey: 'dublin15',
        listingCount: 6,
        medianRent: 2200,
        averageRent: 2300,
        bedroomHistogram: const {2: 1, 3: 3, 4: 2},
        unknownBedroomCount: 0,
        sharedLivingCount: 0,
        independentPlaceCount: 6,
        parsedRents: const [1800, 2000, 2200, 2400, 2600, 2800],
      );

      final commute = DistrictCommuteEligibility(
        districtKey: 'dublin15',
        estimatedMinutes: 40,
        eligible: true,
        commuteScore: 55,
        destinationHubId: DublinCommuterHubs.ifscDocklands.id,
        destinationHubLabel: DublinCommuterHubs.ifscDocklands.label,
        transportMode: CommuteMethod.driving,
        maxTravelMinutes: 60,
      );

      final explanation = DistrictRecommendationExplainer.explain(
        recommendation: DistrictRecommendation(
          districtKey: 'dublin15',
          finalScore: 70,
          commuteScore: 55,
          affordabilityScore: 80,
          inventoryScore: 65,
          personaScore: 70,
          estimatedMinutes: 40,
        ),
        inventory: inventory,
        commute: commute,
        context: DistrictExplanationContext(
          persona: SeekerPersona.family,
          budgetMax: 3000,
          destinationHub: DublinCommuterHubs.ifscDocklands,
          transportMode: CommuteMethod.driving,
        ),
      );

      expect(explanation.reasons.length, 4);
      expect(explanation.reasons[0].kind, RecommendationReasonKind.commute);
      expect(explanation.reasons[1].text, 'Within your €3,000 budget');
      expect(explanation.reasons[2].text, 'Family-sized homes available');
      expect(explanation.reasons[3].text, '6 active listings');

      // ignore: avoid_print
      print('family example: ${explanation.reasonTexts}');
    });

    test('uses from-price when not within budget but rents exist', () {
      final inventory = DistrictInventoryStats(
        districtKey: 'dublin4',
        listingCount: 3,
        medianRent: 2800,
        averageRent: 2900,
        bedroomHistogram: const {2: 3},
        unknownBedroomCount: 0,
        sharedLivingCount: 0,
        independentPlaceCount: 3,
        parsedRents: const [2500, 2800, 3200],
      );

      final explanation = DistrictRecommendationExplainer.explain(
        recommendation: DistrictRecommendation(
          districtKey: 'dublin4',
          finalScore: 50,
          commuteScore: 60,
          affordabilityScore: 30,
          inventoryScore: 65,
          personaScore: 40,
          estimatedMinutes: 20,
        ),
        inventory: inventory,
        commute: DistrictCommuteEligibility(
          districtKey: 'dublin4',
          estimatedMinutes: 20,
          eligible: true,
          commuteScore: 60,
          destinationHubId: DublinCommuterHubs.tcd.id,
          destinationHubLabel: DublinCommuterHubs.tcd.label,
          transportMode: CommuteMethod.publicTransportWalking,
          maxTravelMinutes: 60,
        ),
        context: DistrictExplanationContext(
          persona: SeekerPersona.professional,
          budgetMax: 1800,
          destinationHub: DublinCommuterHubs.tcd,
          transportMode: CommuteMethod.publicTransportWalking,
        ),
      );

      expect(
        explanation.reasonTexts,
        contains('Listings available from €2,500/mo'),
      );
    });
  });
}
