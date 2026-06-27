import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/config/market/dublin_commuter_hubs.dart';
import 'package:true_circle/services/commute_scoring_service.dart';
import 'package:true_circle/utils/commute_profile.dart';
import 'package:true_circle/utils/geo_math.dart';

void main() {
  group('CommuteScoringService', () {
    const rathmines = LatLng(53.3205, -6.2660);
    const cherrywood = LatLng(53.2440, -6.1465);

    test('returns integer door-to-door minutes, never kilometres', () {
      final minutes = CommuteScoringService.calculateCommuteMinutes(
        rathmines,
        DublinCommuterHubs.tcd.location,
        CommuteMethod.publicTransportWalking,
      );

      expect(minutes, isA<int>());
      expect(minutes, greaterThan(0));
    });

    test('driving adds 8-minute rush-hour and parking friction penalty', () {
      final driving = CommuteScoringService.calculateCommuteMinutes(
        rathmines,
        DublinCommuterHubs.tcd.location,
        CommuteMethod.driving,
      );
      final baseDrive = GeoMath.drivingMinutes(
        GeoMath.haversineKm(rathmines, DublinCommuterHubs.tcd.location),
      );

      expect(driving, baseDrive + CommuteScoringService.rushHourDrivingPenaltyMinutes);
    });

    test('calculateMultiCommuteMinutesAsync scores profiles in parallel', () async {
      final payload = await CommuteScoringService.calculateMultiCommuteMinutesAsync(
        propertyLoc: rathmines,
        profiles: const [
          CommuteProfileEntry(
            id: 'primary',
            label: 'You',
            method: CommuteMethod.publicTransportWalking,
            hub: DublinCommuterHubs.grandCanalDock,
          ),
          CommuteProfileEntry(
            id: 'partner',
            label: 'Partner',
            method: CommuteMethod.driving,
            hub: DublinCommuterHubs.ucd,
          ),
        ],
        parkingAvailable: false,
      );

      expect(payload.results.length, 2);
      expect(payload.worstCaseMinutes, greaterThan(0));
      expect(payload.toMetadataArray().length, 2);
      expect(
        payload.results.firstWhere((r) => r.profileId == 'partner').parkingConflict,
        isTrue,
      );
    });

    test('closer properties score fewer minutes than distant ones', () async {
      const nearCity = LatLng(53.3380, -6.2600);

      final nearMinutes = CommuteScoringService.calculateCommuteMinutesToHub(
        nearCity,
        DublinCommuterHubs.tcd,
        CommuteMethod.publicTransportWalking,
      );
      final farMinutes = CommuteScoringService.calculateCommuteMinutesToHub(
        cherrywood,
        DublinCommuterHubs.tcd,
        CommuteMethod.publicTransportWalking,
      );

      expect(nearMinutes, lessThan(farMinutes));
    });

    test('resolveDualCommutePriorityScore applies balanced gap penalty', () {
      expect(
        CommuteScoringService.resolveDualCommutePriorityScore(
          scoreA: 90,
          scoreB: 90,
          priority: DualCommutePriority.balanced,
        ),
        90,
      );

      expect(
        CommuteScoringService.resolveDualCommutePriorityScore(
          scoreA: 90,
          scoreB: 40,
          priority: DualCommutePriority.balanced,
        ),
        55,
      );

      expect(
        CommuteScoringService.resolveDualCommutePriorityScore(
          scoreA: 80,
          scoreB: 20,
          priority: DualCommutePriority.personA,
        ),
        80,
      );

      expect(
        CommuteScoringService.resolveDualCommutePriorityScore(
          scoreA: 80,
          scoreB: 20,
          priority: DualCommutePriority.personB,
        ),
        20,
      );
    });

    test('calculateMultiCommuteMinutes attaches dual compatibility scores', () {
      final payload = CommuteScoringService.calculateMultiCommuteMinutes(
        propertyLoc: rathmines,
        profiles: const [
          CommuteProfileEntry(
            id: 'primary',
            label: 'You',
            method: CommuteMethod.publicTransportWalking,
            hub: DublinCommuterHubs.grandCanalDock,
            maxCommuteMinutes: 40,
          ),
          CommuteProfileEntry(
            id: 'partner',
            label: 'Partner',
            method: CommuteMethod.driving,
            hub: DublinCommuterHubs.ucd,
            maxCommuteMinutes: 50,
          ),
        ],
        dualCommutePriority: DualCommutePriority.balanced,
      );

      expect(payload.commuterCompatibilityScores.length, 2);
      expect(payload.combinedCompatibilityScore, isNotNull);
    });
  });

  group('DublinCommuterHubs', () {
    test('filterByQuery returns prefix matches for partial input', () {
      final matches = DublinCommuterHubs.filterByQuery('trinity');
      expect(matches, isNotEmpty);
      expect(matches.first.id, DublinCommuterHubs.tcd.id);
    });
  });
}
