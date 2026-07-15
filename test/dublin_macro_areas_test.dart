import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/config/market/dublin_districts.dart';
import 'package:true_circle/config/market/dublin_macro_areas.dart';

void main() {
  group('DublinMacroAreas', () {
    test('city centre maps to Dublin 1,2,7,8', () {
      expect(
        DublinMacroAreas.districtKeysFor(DublinMacroAreas.cityCentre),
        ['dublin1', 'dublin2', 'dublin7', 'dublin8'],
      );
      expect(DublinMacroAreas.localityTermsFor(DublinMacroAreas.cityCentre), isEmpty);
    });

    test('north dublin maps to postcodes and north localities', () {
      expect(
        DublinMacroAreas.districtKeysFor(DublinMacroAreas.northDublin),
        containsAll([
          'dublin3',
          'dublin5',
          'dublin9',
          'dublin11',
          'dublin13',
          'dublin17',
        ]),
      );
      expect(
        DublinMacroAreas.localityTermsFor(DublinMacroAreas.northDublin),
        containsAll(['swords', 'malahide', 'portmarnock', 'howth']),
      );
    });

    test('south dublin maps to postcodes and south localities', () {
      expect(
        DublinMacroAreas.districtKeysFor(DublinMacroAreas.southDublin),
        containsAll([
          'dublin4',
          'dublin6',
          'dublin6w',
          'dublin12',
          'dublin14',
          'dublin16',
          'dublin18',
        ]),
      );
      expect(
        DublinMacroAreas.localityTermsFor(DublinMacroAreas.southDublin),
        containsAll([
          'blackrock',
          'dún laoghaire',
          'dun laoghaire',
          'sandyford',
          'dalkey',
          'killiney',
        ]),
      );
    });

    test('west dublin maps to postcodes and west localities', () {
      expect(
        DublinMacroAreas.districtKeysFor(DublinMacroAreas.westDublin),
        ['dublin10', 'dublin15', 'dublin20', 'dublin22', 'dublin24'],
      );
      expect(
        DublinMacroAreas.localityTermsFor(DublinMacroAreas.westDublin),
        containsAll(['lucan', 'clondalkin', 'tallaght', 'blanchardstown']),
      );
    });

    test('resolveMacros unions multiple macro regions', () {
      final resolved = DublinMacroAreas.resolveMacros([
        DublinMacroAreas.cityCentre,
        DublinMacroAreas.southDublin,
      ]);
      expect(resolved.districtKeys, contains('dublin1'));
      expect(resolved.districtKeys, contains('dublin4'));
      expect(resolved.districtKeys, contains('dublin6'));
      expect(resolved.localityTerms, contains('sandyford'));
    });

    test('isMacroToken and isDistrictKey discriminate tokens', () {
      expect(DublinMacroAreas.isMacroToken(DublinMacroAreas.southDublin), isTrue);
      expect(DublinMacroAreas.isMacroToken('dublin4'), isFalse);
      expect(DublinMacroAreas.isDistrictKey('dublin4'), isTrue);
      expect(DublinMacroAreas.isDistrictKey(DublinMacroAreas.southDublin), isFalse);
    });

    test('every catalog district belongs to at least one macro', () {
      final assigned = <String>{};
      for (final macro in DublinMacroAreas.allMacroTokens) {
        assigned.addAll(DublinMacroAreas.districtKeysFor(macro));
      }

      for (final (districtKey, _) in dublinAreaOptions) {
        expect(
          assigned,
          contains(districtKey),
          reason: '$districtKey is not assigned to any macro',
        );
      }
      expect(assigned.length, dublinAreaOptions.length);
    });

    test('dublin17 resolves under North Dublin', () {
      expect(
        DublinMacroAreas.districtKeysFor(DublinMacroAreas.northDublin),
        contains('dublin17'),
      );
      final resolved =
          DublinMacroAreas.resolveMacros([DublinMacroAreas.northDublin]);
      expect(resolved.districtKeys, contains('dublin17'));
    });

    test('dublin18 resolves under South Dublin', () {
      expect(
        DublinMacroAreas.districtKeysFor(DublinMacroAreas.southDublin),
        contains('dublin18'),
      );
      final resolved =
          DublinMacroAreas.resolveMacros([DublinMacroAreas.southDublin]);
      expect(resolved.districtKeys, contains('dublin18'));
    });
  });
}
