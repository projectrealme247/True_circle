import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/config/market/dublin_districts.dart';
import 'package:true_circle/config/market/dublin_macro_areas.dart';
import 'package:true_circle/config/market/dublin_market_config.dart';
import 'package:true_circle/utils/target_search_areas.dart';
import 'package:true_circle/widgets/home/home_area_quick_filters.dart';

void main() {
  group('area UI consistency', () {
    test('homepage presets match primary filter hierarchy', () {
      final presets = HomeAreaQuickFilter.presets;
      final primary = TargetSearchAreas.primaryFilterOptions;

      expect(presets.map((p) => p.id).toList(), primary.map((e) => e.$1).toList());
      expect(
        presets.map((p) => p.label).toList(),
        primary.map((e) => e.$2).toList(),
      );
      expect(
        presets.map((p) => p.label).toList(),
        [
          'All Dublin',
          'City Centre',
          'North Dublin',
          'South Dublin',
          'West Dublin',
        ],
      );
    });

    test('primary macros come only from DublinMacroAreas.primaryOptions', () {
      final primary = TargetSearchAreas.primaryFilterOptions;
      expect(primary.first.$1, TargetSearchAreas.allDublinToken);
      expect(
        primary.skip(1).toList(),
        DublinMacroAreas.primaryOptions,
      );
    });

    test('City Centre membership is shared for resolve + UI', () {
      expect(
        DublinMacroAreas.districtKeysFor(DublinMacroAreas.cityCentre),
        ['dublin1', 'dublin2', 'dublin7', 'dublin8'],
      );
      expect(
        TargetSearchAreas.primaryFilterOptions.any(
          (e) =>
              e.$1 == DublinMacroAreas.cityCentre && e.$2 == 'City Centre',
        ),
        isTrue,
      );
    });

    test('refine options share keys with listing-creation district catalog', () {
      final refine = TargetSearchAreas.postcodeRefinementOptions;
      final catalog = DublinMarketConfig.instance.areaOptions;

      expect(
        refine.map((e) => e.$1).toList(),
        catalog.map((e) => e.$1).toList(),
      );
      expect(
        refine.map((e) => e.$1).toList(),
        dublinAreaOptions.map((e) => e.$1).toList(),
      );

      // Refine uses short labels; listing creation uses full catalog labels.
      expect(refine.firstWhere((e) => e.$1 == 'dublin15').$2, 'Dublin 15');
      expect(
        catalog.firstWhere((e) => e.$1 == 'dublin15').$2,
        'Dublin 15 (Blanchardstown, Castleknock)',
      );
    });

    test('districtRefinementOptions is the refine SOT helper', () {
      expect(
        TargetSearchAreas.postcodeRefinementOptions,
        DublinMacroAreas.districtRefinementOptions,
      );
    });
  });
}
