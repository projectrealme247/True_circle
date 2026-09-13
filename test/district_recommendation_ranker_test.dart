import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/config/market/dublin_commuter_hubs.dart';
import 'package:true_circle/models/seeker_onboarding_enums.dart';
import 'package:true_circle/services/commute_scoring_service.dart';
import 'package:true_circle/utils/district_commute_snapshot.dart';
import 'package:true_circle/utils/district_inventory_stats.dart';
import 'package:true_circle/utils/district_recommendation_ranker.dart';

void main() {
  group('DistrictRecommendationRanker.rank', () {
    test('returns ordered eligible districts with component scores', () {
      final inventory = DistrictInventorySnapshot.build([
        _rent('dublin1', 1800, beds: '1 bed'),
        _rent('dublin1', 2000, beds: '2 bed'),
        _rent('dublin1', 1600, beds: 'Studio'),
        _share('dublin1', 900),
        _rent('dublin4', 2500, beds: '2 bed'),
        _rent('dublin4', 2700, beds: '3 bed'),
        _rent('dublin15', 1400, beds: '2 bed'),
        _rent('dublin15', 1500, beds: '3 bed'),
        _rent('dublin15', 1550, beds: '3 bed'),
        _rent('dublin15', 1600, beds: '4 bed'),
        _rent('dublin15', 1450, beds: '2 bed'),
        _rent('dublin15', 1700, beds: '3 bed'),
        _rent('dublin15', 1800, beds: '3 bed'),
        _rent('dublin15', 1900, beds: '4 bed'),
      ]);

      final commute = DistrictCommuteSnapshot.build(
        destinationHub: DublinCommuterHubs.tcd,
        transportMode: CommuteMethod.publicTransportWalking,
        maxTravelMinutes: 90,
      );

      final ranked = DistrictRecommendationRanker.rank(
        request: DistrictRecommendationRequest(
          persona: SeekerPersona.professional,
          budgetMax: 2000,
          destinationHub: DublinCommuterHubs.tcd,
          transportMode: CommuteMethod.publicTransportWalking,
          maxTravelMinutes: 90,
        ),
        inventory: inventory,
        commute: commute,
      );

      expect(ranked, isNotEmpty);
      expect(ranked.first.finalScore, greaterThanOrEqualTo(ranked.last.finalScore));

      for (final row in ranked) {
        expect(row.commuteScore, inInclusiveRange(0, 100));
        expect(row.affordabilityScore, inInclusiveRange(0, 100));
        expect(row.inventoryScore, inInclusiveRange(0, 100));
        expect(row.personaScore, inInclusiveRange(0, 100));
        expect(row.finalScore, inInclusiveRange(0, 100));
        expect(row.estimatedMinutes, greaterThan(0));
        expect(
          commute[row.districtKey]!.eligible,
          isTrue,
        );
      }

      // ignore: avoid_print
      print(
        'example ranked: ${[
          for (final r in ranked.take(5))
            '${r.districtKey}=${r.finalScore.toStringAsFixed(1)}'
                '(c${r.commuteScore.toStringAsFixed(0)}'
                ' a${r.affordabilityScore.toStringAsFixed(0)}'
                ' i${r.inventoryScore.toStringAsFixed(0)}'
                ' p${r.personaScore.toStringAsFixed(0)}'
                ' ${r.estimatedMinutes}m)',
        ]}',
      );
    });

    test('student persona prefers shared-living heavy districts when eligible', () {
      final inventory = DistrictInventorySnapshot.build([
        _share('dublin8', 850),
        _share('dublin8', 900),
        _share('dublin8', 950),
        _rent('dublin8', 1100, beds: '1 bed'),
        // Independent-only and within budget so both stay eligible.
        _rent('dublin2', 1100, beds: '2 bed'),
        _rent('dublin2', 1150, beds: '2 bed'),
        _rent('dublin2', 1200, beds: '2 bed'),
      ]);

      final commute = DistrictCommuteSnapshot.build(
        destinationHub: DublinCommuterHubs.tcd,
        transportMode: CommuteMethod.publicTransportWalking,
        maxTravelMinutes: 60,
        districtKeys: const ['dublin8', 'dublin2'],
      );

      final ranked = DistrictRecommendationRanker.rank(
        request: DistrictRecommendationRequest(
          persona: SeekerPersona.student,
          budgetMax: 1200,
          destinationHub: DublinCommuterHubs.tcd,
          transportMode: CommuteMethod.publicTransportWalking,
          maxTravelMinutes: 60,
        ),
        inventory: inventory,
        commute: commute,
      );

      expect(ranked.map((r) => r.districtKey), containsAll(['dublin8', 'dublin2']));
      final d8 = ranked.firstWhere((r) => r.districtKey == 'dublin8');
      final d2 = ranked.firstWhere((r) => r.districtKey == 'dublin2');
      expect(d8.personaScore, greaterThan(d2.personaScore));
    });

    test('drops districts with rents but zero affordability', () {
      final inventory = DistrictInventorySnapshot.build([
        _rent('dublin4', 5000, beds: '3 bed'),
        _rent('dublin4', 5200, beds: '3 bed'),
        _rent('dublin1', 1500, beds: '1 bed'),
      ]);

      final commute = DistrictCommuteSnapshot.build(
        destinationHub: DublinCommuterHubs.tcd,
        transportMode: CommuteMethod.driving,
        maxTravelMinutes: 90,
        districtKeys: const ['dublin4', 'dublin1'],
      );

      final ranked = DistrictRecommendationRanker.rank(
        request: DistrictRecommendationRequest(
          persona: SeekerPersona.professional,
          budgetMax: 1800,
          destinationHub: DublinCommuterHubs.tcd,
          transportMode: CommuteMethod.driving,
          maxTravelMinutes: 90,
        ),
        inventory: inventory,
        commute: commute,
      );

      expect(ranked.map((r) => r.districtKey), isNot(contains('dublin4')));
      expect(ranked.map((r) => r.districtKey), contains('dublin1'));
    });

    test('professional personaScore ignores commute differences', () {
      final inventory = DistrictInventorySnapshot.build([
        _rent('dublin1', 1600, beds: '1 bed'),
        _rent('dublin1', 1700, beds: '2 bed'),
        _rent('dublin1', 1800, beds: '2 bed'),
        _rent('dublin8', 1600, beds: '1 bed'),
        _rent('dublin8', 1700, beds: '2 bed'),
        _rent('dublin8', 1800, beds: '2 bed'),
      ]);

      final near = DistrictCommuteSnapshot.build(
        destinationHub: DublinCommuterHubs.tcd,
        transportMode: CommuteMethod.publicTransportWalking,
        maxTravelMinutes: 90,
        districtKeys: const ['dublin1', 'dublin8'],
      );
      final farHub = DistrictCommuteSnapshot.build(
        destinationHub: DublinCommuterHubs.maynooth,
        transportMode: CommuteMethod.publicTransportWalking,
        maxTravelMinutes: 120,
        districtKeys: const ['dublin1', 'dublin8'],
      );

      DistrictRecommendation rowFor(
        DistrictCommuteSnapshot commute,
        String key,
      ) {
        final ranked = DistrictRecommendationRanker.rank(
          request: DistrictRecommendationRequest(
            persona: SeekerPersona.professional,
            budgetMax: 2000,
            destinationHub: commute.destinationHub,
            transportMode: CommuteMethod.publicTransportWalking,
            maxTravelMinutes: commute.maxTravelMinutes,
          ),
          inventory: inventory,
          commute: commute,
        );
        return ranked.firstWhere((r) => r.districtKey == key);
      }

      final d1Near = rowFor(near, 'dublin1');
      final d1Far = rowFor(farHub, 'dublin1');

      expect(d1Near.commuteScore, isNot(equals(d1Far.commuteScore)));
      expect(d1Near.personaScore, closeTo(d1Far.personaScore, 0.001));
    });
  });
}

Map<String, dynamic> _rent(String areaKey, int price, {required String beds}) {
  return {
    'listing_area_key': areaKey,
    'price': '$price/month',
    'bedrooms': beds,
    'type': 'Rent',
    'listing_type': 'Rent',
  };
}

Map<String, dynamic> _share(String areaKey, int price) {
  return {
    'listing_area_key': areaKey,
    'price': '$price/month',
    'bedrooms': '1 bed',
    'type': 'Share',
    'listing_type': 'Share',
  };
}
