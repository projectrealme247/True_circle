import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/config/market/dublin_commuter_hubs.dart';
import 'package:true_circle/models/seeker_onboarding_enums.dart';
import 'package:true_circle/services/commute_scoring_service.dart';
import 'package:true_circle/widgets/onboarding/seeker/seeker_onboarding_destination_screen.dart';

void main() {
  Widget harness({
    required SeekerPersona persona,
    required bool partnerCommuteEnabled,
    required bool destinationEnteredIsMine,
    required Size viewport,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: viewport),
        child: Scaffold(
          body: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: SeekerOnboardingDestinationScreen(
              persona: persona,
              commuteMethod: CommuteMethod.publicTransportWalking,
              onCommuteMethodChanged: (_) {},
              selectedHub: null,
              maxCommuteMinutes: 60,
              onHubSelected: (_) {},
              onHubCleared: () {},
              onCommuteMinutesChanged: (_) {},
              partnerCommuteEnabled: partnerCommuteEnabled,
              destinationEnteredIsMine: destinationEnteredIsMine,
              onDestinationEnteredIsMineChanged: (_) {},
              guarantorStatus: GuarantorStatus.notSureYet,
              onGuarantorChanged: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  Future<void> setSurface(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('legacy dual / family destination controls are removed',
      (tester) async {
    await setSurface(tester, const Size(420, 1100));
    await tester.pumpWidget(
      harness(
        persona: SeekerPersona.family,
        partnerCommuteEnabled: true,
        destinationEnteredIsMine: true,
        viewport: const Size(420, 1100),
      ),
    );

    expect(find.text('Where do you need to be most weekdays?'), findsOneWidget);
    expect(find.text('Whose destination are you entering?'), findsOneWidget);
    expect(find.text('Primary Destination (My Destination)'), findsOneWidget);
    expect(find.text("Partner's Destination"), findsNothing);
    expect(find.text('Choose Primary Destination'), findsNothing);
    expect(find.text('Workplace'), findsNothing);
    expect(find.text('School'), findsNothing);
    expect(find.text('Both'), findsNothing);
    expect(find.text('Balanced'), findsNothing);
  });

  testWidgets('partner labeling only when enabled', (tester) async {
    await setSurface(tester, const Size(420, 1100));
    await tester.pumpWidget(
      harness(
        persona: SeekerPersona.professional,
        partnerCommuteEnabled: false,
        destinationEnteredIsMine: true,
        viewport: const Size(420, 1100),
      ),
    );
    expect(find.text('Whose destination are you entering?'), findsNothing);
    expect(find.text('Primary Destination'), findsOneWidget);

    await tester.pumpWidget(
      harness(
        persona: SeekerPersona.professional,
        partnerCommuteEnabled: true,
        destinationEnteredIsMine: false,
        viewport: const Size(420, 1100),
      ),
    );
    expect(find.text('Whose destination are you entering?'), findsOneWidget);
    expect(
      find.text("Primary Destination (Partner's Destination)"),
      findsOneWidget,
    );
  });

  testWidgets('destination presets omit Not sure yet; custom field remains',
      (tester) async {
    await setSurface(tester, const Size(420, 1100));
    await tester.pumpWidget(
      harness(
        persona: SeekerPersona.professional,
        partnerCommuteEnabled: false,
        destinationEnteredIsMine: true,
        viewport: const Size(420, 1100),
      ),
    );

    expect(find.text('Not sure yet'), findsNothing);
    expect(
      find.text('Neighbourhood, campus, or workplace…'),
      findsOneWidget,
    );
    expect(find.text('💼 IFSC'), findsOneWidget);
  });

  test('student and professional/family presets match V3 lists', () {
    final student = DublinCommuterHubs.seekerOnboardingPresetsForPersona(
      SeekerPersona.student,
    );
    expect(
      student.map((p) => p.hub.id),
      [
        'tcd',
        'ucd',
        'dcu',
        'tu_dublin',
        'maynooth',
        'nci',
        'rcsi',
      ],
    );

    for (final persona in [
      SeekerPersona.professional,
      SeekerPersona.family,
    ]) {
      final presets =
          DublinCommuterHubs.seekerOnboardingPresetsForPersona(persona);
      expect(
        presets.map((p) => p.hub.id),
        [
          'ifsc_docklands',
          'silicon_docks',
          'st_stephens_green',
          'sandyford',
          'cherrywood_business_park',
          'blanchardstown_business_park',
          'dublin_airport',
        ],
      );
    }
  });

  testWidgets('no overflow at 720 with partner labeling', (tester) async {
    await setSurface(tester, const Size(420, 720));
    await tester.pumpWidget(
      harness(
        persona: SeekerPersona.student,
        partnerCommuteEnabled: true,
        destinationEnteredIsMine: true,
        viewport: const Size(420, 720),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
