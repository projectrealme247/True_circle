import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/config/market/dublin_commuter_hubs.dart';
import 'package:true_circle/config/market/dublin_macro_areas.dart';
import 'package:true_circle/models/seeker_onboarding_enums.dart';
import 'package:true_circle/services/commute_scoring_service.dart';
import 'package:true_circle/utils/accepted_district_recommendations.dart';
import 'package:true_circle/utils/district_inventory_stats.dart';
import 'package:true_circle/widgets/onboarding/seeker/seeker_recommended_areas_section.dart';

void main() {
  testWidgets('renders top recommendations and accepts macros only on tap',
      (tester) async {
    final inventory = DistrictInventorySnapshot.build([
      _rent('dublin1', 1500, beds: '1 bed'),
      _rent('dublin1', 1600, beds: '2 bed'),
      _rent('dublin1', 1400, beds: 'Studio'),
      _share('dublin1', 900),
      _rent('dublin8', 1300, beds: '1 bed'),
      _rent('dublin8', 1400, beds: '2 bed'),
      _rent('dublin8', 1500, beds: '2 bed'),
      _rent('dublin2', 1800, beds: '2 bed'),
      _rent('dublin2', 1900, beds: '2 bed'),
      _rent('dublin2', 1700, beds: '1 bed'),
      _rent('dublin15', 1600, beds: '3 bed'),
      _rent('dublin15', 1700, beds: '3 bed'),
      _rent('dublin15', 1800, beds: '4 bed'),
      _rent('dublin15', 1550, beds: '2 bed'),
      _rent('dublin15', 1650, beds: '3 bed'),
      _rent('dublin15', 1750, beds: '3 bed'),
      _rent('dublin15', 1850, beds: '4 bed'),
      _rent('dublin15', 1900, beds: '3 bed'),
    ]);

    final accepted = <DistrictRecommendationAcceptance>[];
    final selected = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 520,
            width: 400,
            child: SeekerRecommendedAreasSection(
              persona: SeekerPersona.professional,
              budgetMax: 2000,
              destinationHub: DublinCommuterHubs.tcd,
              commuteDestinationUnknown: false,
              transportMode: CommuteMethod.publicTransportWalking,
              maxTravelMinutes: 60,
              selectedTargetSearchAreas: selected,
              onToggleTargetSearchArea: (_) {},
              onAcceptRecommendations: accepted.add,
              inventoryOverride: inventory,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accept recommendations'), findsOneWidget);
    expect(find.textContaining('✓'), findsWidgets);
    expect(accepted, isEmpty);

    await tester.tap(find.text('Accept recommendations'));
    await tester.pumpAndSettle();

    expect(accepted, hasLength(1));
    expect(accepted.single.districts, isNotEmpty);
    expect(accepted.single.macros, isNotEmpty);
    for (final macro in accepted.single.macros) {
      expect(DublinMacroAreas.isMacroToken(macro), isTrue);
    }
    for (final row in accepted.single.districts) {
      expect(row.districtKey, isNotEmpty);
      expect(row.recommendationScore, greaterThan(0));
      expect(row.destinationHubId, DublinCommuterHubs.tcd.id);
      expect(row.maxTravelMinutes, 60);
    }
    expect(find.text('Accepted'), findsOneWidget);

    await tester.tap(find.text('Modify areas'));
    await tester.pumpAndSettle();
    expect(find.text('City Centre'), findsOneWidget);
    expect(find.text('North Dublin'), findsOneWidget);
  });

  testWidgets('does not rank without destination hub', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: SeekerRecommendedAreasSection(
              persona: SeekerPersona.student,
              budgetMax: 1200,
              destinationHub: null,
              commuteDestinationUnknown: false,
              transportMode: CommuteMethod.publicTransportWalking,
              maxTravelMinutes: 60,
              selectedTargetSearchAreas: const [],
              onToggleTargetSearchArea: (_) {},
              onAcceptRecommendations: (_) {},
              inventoryOverride: DistrictInventorySnapshot.build(const []),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Choose a primary destination to see recommended areas.'),
      findsOneWidget,
    );
    expect(find.text('Accept recommendations'), findsNothing);
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
