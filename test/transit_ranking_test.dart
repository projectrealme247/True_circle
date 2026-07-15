import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/proximity_display_chip.dart';
import 'package:true_circle/services/overpass_amenities_service.dart';
import 'package:true_circle/utils/proximity_display_builder.dart';
import 'package:true_circle/utils/transit_ranking.dart';

void main() {
  group('TransitRanking', () {
    test('prefers shorter walk over higher transit type', () {
      expect(
        TransitRanking.shouldPreferPrimary(
          candidateWalkMin: 2,
          candidateDistanceM: 160,
          candidateLine: 'DART · Clontarf Road',
          currentWalkMin: 22,
          currentDistanceM: 1760,
          currentLine: 'Luas · The Point',
        ),
        isTrue,
      );
    });

    test('prefers nearer bus over distant Luas', () {
      expect(
        TransitRanking.compare(
          walkMinA: 8,
          walkMinB: 28,
          distanceMetersA: 640,
          distanceMetersB: 2240,
          lineA: 'Dublin Bus · Hollywood',
          lineB: 'Luas Red Line · Tallaght',
        ),
        lessThan(0),
      );
    });

    test('type tie-break applies only when walk and distance match', () {
      expect(
        TransitRanking.compare(
          walkMinA: 10,
          walkMinB: 10,
          distanceMetersA: 800,
          distanceMetersB: 800,
          lineA: 'DART · Station',
          lineB: 'Luas · Stop',
        ),
        lessThan(0),
      );
    });
  });

  group('ProximityDisplayBuilder transit order', () {
    test('Clontarf: walk-time order bus, DART, then Luas', () {
      const input = ProximityDisplayInput(
        transportLine: 'Luas · The Point',
        transportWalkMin: 22,
        extraTransit: [
          NearbyExtraTransit(line: 'DART · Clontarf Road', walkMin: 2),
          NearbyExtraTransit(line: 'Dublin Bus · Clontarf Station', walkMin: 1),
        ],
      );

      final transit = ProximityDisplayBuilder.build(input)
          .where((c) => c.tier == ProximityDisplayTier.tier1)
          .take(3)
          .map((c) => c.label)
          .toList();

      expect(transit.first, contains('Dublin Bus'));
      expect(transit[1], contains('DART'));
      expect(transit.last, contains('Luas'));
    });

    test('Hollywoodrath: nearby bus ranks above distant Luas primary', () {
      const input = ProximityDisplayInput(
        transportLine: 'Luas Red Line · Tallaght',
        transportWalkMin: 35,
        extraTransit: [
          NearbyExtraTransit(line: 'Dublin Bus · Blanchardstown', walkMin: 9),
        ],
      );

      final transit = ProximityDisplayBuilder.build(input)
          .where((c) => c.icon == Icons.train_outlined)
          .toList();

      expect(transit, hasLength(2));
      expect(transit.first.label, contains('Dublin Bus'));
      expect(transit.last.label, contains('Luas'));
    });
  });
}
