import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/config/market/dublin_commuter_hubs.dart';
import 'package:true_circle/utils/seeker_destination_validity.dart';
import 'package:true_circle/widgets/gamified_form_wizard.dart';

void main() {
  group('isSeekerDestinationValid', () {
    test('Scenario 1 — no destination → invalid', () {
      expect(
        isSeekerDestinationValid(
          commuteDestinationUnknown: false,
          hub: null,
        ),
        isFalse,
      );
    });

    test('Scenario 2 — typed text only (null hub) → invalid', () {
      // Unresolved custom query never sets a hub until a suggestion is picked.
      expect(
        isSeekerDestinationValid(
          commuteDestinationUnknown: false,
          hub: null,
        ),
        isFalse,
      );
    });

    test('Scenario 3 — preset selected → valid', () {
      expect(
        isSeekerDestinationValid(
          commuteDestinationUnknown: false,
          hub: DublinCommuterHubs.tcd,
        ),
        isTrue,
      );
    });

    test('Scenario 4 — custom destination hub resolved → valid', () {
      final custom = DublinCommuterHubs.fromGeocoded(
        label: 'Mayor Square, Dublin',
        latitude: 53.3492,
        longitude: -6.2433,
      );
      expect(
        isSeekerDestinationValid(
          commuteDestinationUnknown: false,
          hub: custom,
        ),
        isTrue,
      );
    });

    test('legacy commute_destination_unknown → invalid even with hub', () {
      expect(
        isSeekerDestinationValid(
          commuteDestinationUnknown: true,
          hub: DublinCommuterHubs.nci,
        ),
        isFalse,
      );
    });
  });

  group('GamifiedFormNavBar submitEnabled', () {
    testWidgets('Save disabled when submitEnabled is false', (tester) async {
      var submitted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GamifiedFormNavBar(
              showBack: true,
              showSubmit: true,
              submitEnabled: false,
              submitLabel: 'Save & find matches',
              onBack: () {},
              onSubmit: () => submitted = true,
            ),
          ),
        ),
      );

      final save = find.text('Save & find matches');
      expect(save, findsOneWidget);
      await tester.tap(save);
      await tester.pump();
      expect(submitted, isFalse);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save & find matches'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Save enabled when submitEnabled is true', (tester) async {
      var submitted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GamifiedFormNavBar(
              showBack: true,
              showSubmit: true,
              submitEnabled: true,
              submitLabel: 'Save & find matches',
              onBack: () {},
              onSubmit: () => submitted = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Save & find matches'));
      await tester.pump();
      expect(submitted, isTrue);
    });

    testWidgets('Back stays enabled when submit is gated', (tester) async {
      var wentBack = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GamifiedFormNavBar(
              showBack: true,
              showSubmit: true,
              submitEnabled: false,
              submitLabel: 'Save & find matches',
              onBack: () => wentBack = true,
              onSubmit: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('← Back'));
      await tester.pump();
      expect(wentBack, isTrue);
    });
  });
}
