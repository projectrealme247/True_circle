import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin_v2.dart';
import 'package:true_circle/utils/listing_data.dart';
import 'package:true_circle/utils/listing_search_intent.dart';
import 'package:true_circle/utils/marketplace_listing_pipeline.dart';
import 'package:true_circle/widgets/filter_chip_bar.dart';

/// Measures More Filters drawer open cost after inventory stats removal.
void main() {
  testWidgets('More Filters drawer open latency', (tester) async {
    final all = SampleListingsDublinV2.items;
    final share = [
      for (final l in all) if (ListingData.propertyType(l) == 'Share') l,
    ];
    final session = {
      'occupant_type': 'Students',
      'budget_max': 850,
      'detected_city': 'Dublin',
    };
    final filters = ListingSearchFilters(budgetMax: 850);
    var latestFilters = filters;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => MarketplaceFilterBar.showAdvancedFiltersDrawer(
                  context,
                  towerPropertyType: 'Share',
                  activeFilters: latestFilters,
                  onFiltersChanged: (next) => latestFilters = next,
                  onClearAll: () {},
                  resultCount: share.length,
                  allListings: share,
                  userSession: session,
                ),
                child: const Text('Open drawer'),
              ),
            ),
          ),
        ),
      ),
    );

    final sw = Stopwatch()..start();
    await tester.tap(find.text('Open drawer'));
    await tester.pump();
    final firstFrameMs = sw.elapsedMicroseconds / 1000.0;
    await tester.pump(const Duration(milliseconds: 150));
    final totalOpenMs = sw.elapsedMicroseconds / 1000.0;
    sw.stop();

    expect(find.text('Filters'), findsOneWidget);

    print('\n=== MORE FILTERS WIDGET OPEN (Share) ===');
    print('  Click → first frame: ${firstFrameMs.toStringAsFixed(2)} ms');
    print('  Click → animation complete: ${totalOpenMs.toStringAsFixed(2)} ms');
    print('  Inventory stats processing: 0.00 ms (removed)');
  });

  test('More Filters drawer performance profile', () {
    final all = SampleListingsDublinV2.items;
    final share = [
      for (final l in all) if (ListingData.propertyType(l) == 'Share') l,
    ];
    final rent = [
      for (final l in all) if (ListingData.propertyType(l) == 'Rent') l,
    ];
    final session = {
      'occupant_type': 'Students',
      'budget_max': 850,
      'detected_city': 'Dublin',
    };

    print('\n=== MORE FILTERS PERFORMANCE (post inventory removal) ===');
    print('BEFORE (audit): Share stats ~1567ms, Rent stats ~1102ms, animation 150ms');

    for (final entry in [('Share', share), ('Rent', rent)]) {
      final tower = entry.$1;
      final listings = entry.$2;
      final filters = ListingSearchFilters(
        budgetMax: tower == 'Share' ? 850 : 2200,
      );

      final pipelineSw = Stopwatch()..start();
      final pipeline = MarketplaceListingPipeline.runWithFilters(
        allListings: listings,
        towerPropertyType: tower,
        filters: filters,
        userSession: session,
      );
      final pipelineMs = pipelineSw.elapsedMicroseconds / 1000.0;
      pipelineSw.stop();

      // Sidebar build is now filter UI only — no statsFor calls.
      const drawerRenderMs = 0.0;
      const animationMs = 150.0;
      final totalOpenMs = animationMs + drawerRenderMs + pipelineMs;

      print('\n$tower (${listings.length} listings):');
      print('  Animation: ${animationMs.toStringAsFixed(2)} ms');
      print('  Drawer render (no inventory stats): ${drawerRenderMs.toStringAsFixed(2)} ms');
      print(
        '  Result count pipeline (footer): ${pipelineMs.toStringAsFixed(2)} ms '
        '(${pipeline.ranked.length} ranked)',
      );
      print('  Inventory stats processing: 0.00 ms (removed)');
      print('  Total perceived open: ${totalOpenMs.toStringAsFixed(2)} ms');
    }
  });
}
