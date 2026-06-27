import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/utils/dublin_macro_search.dart';
import 'package:true_circle/utils/target_search_areas.dart';

void main() {
  group('TargetSearchAreas', () {
    test('ALL_DUBLIN is exclusive in storage', () {
      expect(
        TargetSearchAreas.normalizeTokens([
          TargetSearchAreas.allDublinToken,
          'dublin4',
        ]),
        [TargetSearchAreas.allDublinToken],
      );
    });

    test('ALL_DUBLIN matches any listing location', () {
      final listing = SampleListingsDublin.items.first;
      expect(
        TargetSearchAreas.listingMatchesTargets(
          [TargetSearchAreas.allDublinToken],
          listing,
        ),
        isTrue,
      );
    });

    test('legacy detected_city hydrates target areas', () {
      expect(
        TargetSearchAreas.hydrateFromSession({
          'detected_city': 'Dublin 14 (Dundrum, Rathfarnham)',
        }),
        isNotEmpty,
      );
    });

    test('toggleSelection enforces ALL_DUBLIN exclusivity', () {
      expect(
        TargetSearchAreas.toggleSelection(['dublin1'], 'ALL_DUBLIN'),
        [TargetSearchAreas.allDublinToken],
      );
      expect(
        TargetSearchAreas.toggleSelection(
          [TargetSearchAreas.allDublinToken],
          'dublin2',
        ),
        ['dublin2'],
      );
    });

    test('DublinMacroSearch exact macro phrases', () {
      expect(DublinMacroSearch.isExactMacroPhrase('dublin'), isTrue);
      expect(DublinMacroSearch.isExactMacroPhrase('All of Dublin'), isTrue);
      expect(DublinMacroSearch.isExactMacroPhrase('Dublin 18'), isFalse);
      expect(DublinMacroSearch.isExactMacroPhrase('Ensuite in Dublin 6'), isFalse);
      expect(DublinMacroSearch.isExactMacroPhrase('Dundrum'), isFalse);
    });

    test('compactSummary truncates long selections', () {
      expect(
        TargetSearchAreas.compactSummary(
          ['dublin1', 'dublin2', 'dublin3'],
        ),
        'Dublin 1 (City Centre North), Dublin 2 (City Centre South)...',
      );
    });
  });
}
