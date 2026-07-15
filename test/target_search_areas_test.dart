import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/config/market/dublin_macro_areas.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/utils/dublin_macro_search.dart';
import 'package:true_circle/utils/listing_search_intent.dart';
import 'package:true_circle/utils/target_search_areas.dart';

void main() {
  group('TargetSearchAreas', () {
    test('ALL_DUBLIN is exclusive in storage', () {
      expect(
        TargetSearchAreas.normalizeMacroTokens([
          TargetSearchAreas.allDublinToken,
          DublinMacroAreas.southDublin,
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

    test('toggleMacroSelection enforces ALL_DUBLIN exclusivity', () {
      expect(
        TargetSearchAreas.toggleMacroSelection(
          [DublinMacroAreas.cityCentre],
          TargetSearchAreas.allDublinToken,
        ),
        [TargetSearchAreas.allDublinToken],
      );
      expect(
        TargetSearchAreas.toggleMacroSelection(
          [TargetSearchAreas.allDublinToken],
          DublinMacroAreas.southDublin,
        ),
        [DublinMacroAreas.southDublin],
      );
      expect(
        TargetSearchAreas.toggleMacroSelection(
          [DublinMacroAreas.cityCentre],
          DublinMacroAreas.southDublin,
        ),
        [DublinMacroAreas.cityCentre, DublinMacroAreas.southDublin],
      );
      expect(
        TargetSearchAreas.toggleMacroSelection(
          [DublinMacroAreas.cityCentre, DublinMacroAreas.southDublin],
          DublinMacroAreas.cityCentre,
        ),
        [DublinMacroAreas.southDublin],
      );
      expect(
        TargetSearchAreas.toggleMacroSelection(
          [DublinMacroAreas.southDublin],
          DublinMacroAreas.southDublin,
        ),
        [TargetSearchAreas.allDublinToken],
      );
    });

    test('toggleSelection routes district keys to refinements', () {
      expect(
        TargetSearchAreas.toggleSelection(['dublin1'], TargetSearchAreas.allDublinToken),
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

    test('union of City Centre + South Dublin resolves combined districts', () {
      final resolved = TargetSearchAreas.resolveSearch(
        macroTokens: [
          DublinMacroAreas.cityCentre,
          DublinMacroAreas.southDublin,
        ],
        refinementTokens: const [],
      );
      expect(resolved.isAllDublin, isFalse);
      expect(resolved.districtKeys, contains('dublin1'));
      expect(resolved.districtKeys, contains('dublin4'));
      expect(resolved.districtKeys, contains('dublin6'));
      expect(resolved.localityTerms, contains('sandyford'));
    });

    test('locality-only listings match South Dublin without postcode', () {
      final sandyfordListing = SampleListingsDublin.items.firstWhere(
        (l) => (l['location'] as String? ?? '').toLowerCase().contains('sandyford'),
      );
      final dunLaoghaireListing = SampleListingsDublin.items.firstWhere(
        (l) => (l['location'] as String? ?? '').toLowerCase().contains('laoghaire'),
      );

      final southOnly = TargetSearchAreas.resolveSearch(
        macroTokens: [DublinMacroAreas.southDublin],
        refinementTokens: const [],
      );

      expect(
        TargetSearchAreas.listingMatchesResolved(southOnly, sandyfordListing),
        isTrue,
      );
      expect(
        TargetSearchAreas.listingMatchesResolved(southOnly, dunLaoghaireListing),
        isTrue,
      );
    });

    test('withoutPill clears area refinements with city pill', () {
      final filters = ListingSearchFilters(
        targetSearchAreas: [DublinMacroAreas.southDublin],
        targetSearchAreaRefinements: const ['dublin4'],
      );
      final cleared = filters.withoutPill('city');
      expect(cleared.targetSearchAreas, isEmpty);
      expect(cleared.targetSearchAreaRefinements, isEmpty);
    });

    test('withoutPill clears refinements only for area_refinement pill', () {
      final filters = ListingSearchFilters(
        targetSearchAreas: [DublinMacroAreas.southDublin],
        targetSearchAreaRefinements: const ['dublin4'],
      );
      final cleared = filters.withoutPill('area_refinement');
      expect(cleared.targetSearchAreas, [DublinMacroAreas.southDublin]);
      expect(cleared.targetSearchAreaRefinements, isEmpty);
    });

    test('DublinMacroSearch exact macro phrases', () {
      expect(DublinMacroSearch.isExactMacroPhrase('dublin'), isTrue);
      expect(DublinMacroSearch.isExactMacroPhrase('All of Dublin'), isTrue);
      expect(DublinMacroSearch.isExactMacroPhrase('Dublin 18'), isFalse);
      expect(DublinMacroSearch.isExactMacroPhrase('Ensuite in Dublin 6'), isFalse);
      expect(DublinMacroSearch.isExactMacroPhrase('Dundrum'), isFalse);
    });

    test('displaySummary shows macro labels', () {
      expect(
        TargetSearchAreas.displaySummary([DublinMacroAreas.southDublin]),
        'South Dublin',
      );
      expect(
        TargetSearchAreas.displaySummary([
          DublinMacroAreas.cityCentre,
          DublinMacroAreas.southDublin,
        ]),
        'City Centre, South Dublin',
      );
    });
  });
}
