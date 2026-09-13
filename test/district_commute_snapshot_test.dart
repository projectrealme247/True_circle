import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/config/market/dublin_commuter_hubs.dart';
import 'package:true_circle/config/market/dublin_districts.dart';
import 'package:true_circle/services/commute_scoring_service.dart';
import 'package:true_circle/utils/district_commute_snapshot.dart';

void main() {
  group('DistrictCommuteSnapshot.build', () {
    test('scores all catalog districts for a hub and marks eligibility', () {
      final snapshot = DistrictCommuteSnapshot.build(
        destinationHub: DublinCommuterHubs.tcd,
        transportMode: CommuteMethod.publicTransportWalking,
        maxTravelMinutes: 60,
      );

      expect(snapshot.scoredDistrictCount, dublinAreaOptions.length);
      expect(snapshot.unresolvedDistrictKeys, isEmpty);
      expect(snapshot.destinationHub.id, 'tcd');
      expect(
        snapshot.transportMode,
        CommuteMethod.publicTransportWalking,
      );
      expect(snapshot.maxTravelMinutes, 60);

      final cityCentre = snapshot['dublin1'];
      expect(cityCentre, isNotNull);
      expect(cityCentre!.estimatedMinutes, greaterThan(0));
      expect(cityCentre.destinationHubId, 'tcd');
      expect(cityCentre.commuteScore, inInclusiveRange(0, 100));

      final eligibleKeys = snapshot.eligibleDistricts.map((e) => e.districtKey);
      expect(eligibleKeys, contains('dublin1'));
      expect(
        snapshot.eligibleDistrictCount,
        lessThanOrEqualTo(snapshot.scoredDistrictCount),
      );
    });

    test('driving mode produces minutes and stores transport mode', () {
      final snapshot = DistrictCommuteSnapshot.build(
        destinationHub: DublinCommuterHubs.sandyford,
        transportMode: CommuteMethod.driving,
        maxTravelMinutes: 45,
        districtKeys: const ['dublin18', 'dublin15'],
      );

      expect(snapshot.byDistrict.keys, unorderedEquals(['dublin18', 'dublin15']));
      expect(snapshot['dublin18']!.transportMode, CommuteMethod.driving);
      expect(snapshot['dublin18']!.maxTravelMinutes, 45);
      expect(
        snapshot['dublin18']!.eligible,
        snapshot['dublin18']!.estimatedMinutes <= 45,
      );
    });

    test('unknown district keys are unresolved', () {
      final snapshot = DistrictCommuteSnapshot.build(
        destinationHub: DublinCommuterHubs.ifscDocklands,
        transportMode: CommuteMethod.driving,
        maxTravelMinutes: 30,
        districtKeys: const ['dublin2', 'not_a_district'],
      );

      expect(snapshot.byDistrict.containsKey('dublin2'), isTrue);
      expect(snapshot.unresolvedDistrictKeys, contains('not_a_district'));
    });
  });
}
