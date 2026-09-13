import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/config/market/dublin_commuter_hubs.dart';
import 'package:true_circle/models/seeker_onboarding_enums.dart';
import 'package:true_circle/services/commute_scoring_service.dart';
import 'package:true_circle/utils/contextual_passport_snapshot.dart';
import 'package:true_circle/utils/seeker_destination_validity.dart';
import 'package:true_circle/widgets/onboarding/seeker/seeker_onboarding_destination_screen.dart';

void main() {
  group('destination owner switch reset', () {
    testWidgets('My → Partner clears hub and remounts search field',
        (tester) async {
      DublinCommuterHub? hub = DublinCommuterHubs.tcd;
      var mine = true;
      var resetToken = 0;

      Future<void> pump() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 420,
                height: 1100,
                child: SeekerOnboardingDestinationScreen(
                  persona: SeekerPersona.professional,
                  commuteMethod: CommuteMethod.publicTransportWalking,
                  onCommuteMethodChanged: (_) {},
                  selectedHub: hub,
                  maxCommuteMinutes: 60,
                  onHubSelected: (selected) => hub = selected,
                  onHubCleared: () => hub = null,
                  onCommuteMinutesChanged: (_) {},
                  partnerCommuteEnabled: true,
                  destinationEnteredIsMine: mine,
                  onDestinationEnteredIsMineChanged: (nextMine) {
                    if (nextMine == mine) return;
                    mine = nextMine;
                    hub = null;
                    resetToken++;
                  },
                  guarantorStatus: null,
                  onGuarantorChanged: (_) {},
                  destinationFieldResetToken: resetToken,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pump();
      expect(find.text('Primary Destination (My Destination)'), findsOneWidget);
      expect(hub?.id, 'tcd');
      expect(
        isSeekerDestinationValid(
          commuteDestinationUnknown: false,
          hub: hub,
        ),
        isTrue,
      );

      await tester.tap(find.text("My Partner's Destination"));
      await pump();

      expect(
        find.text("Primary Destination (Partner's Destination)"),
        findsOneWidget,
      );
      expect(hub, isNull);
      expect(resetToken, 1);
      expect(
        isSeekerDestinationValid(
          commuteDestinationUnknown: false,
          hub: hub,
        ),
        isFalse,
      );
      expect(
        find.text('Neighbourhood, campus, or workplace…'),
        findsOneWidget,
      );
    });

    testWidgets('Partner → My also clears hub', (tester) async {
      DublinCommuterHub? hub = DublinCommuterHubs.ifscDocklands;
      var mine = false;
      var resetToken = 0;

      Future<void> pump() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 420,
                height: 1100,
                child: SeekerOnboardingDestinationScreen(
                  persona: SeekerPersona.family,
                  commuteMethod: CommuteMethod.driving,
                  onCommuteMethodChanged: (_) {},
                  selectedHub: hub,
                  maxCommuteMinutes: 45,
                  onHubSelected: (selected) => hub = selected,
                  onHubCleared: () => hub = null,
                  onCommuteMinutesChanged: (_) {},
                  partnerCommuteEnabled: true,
                  destinationEnteredIsMine: mine,
                  onDestinationEnteredIsMineChanged: (nextMine) {
                    if (nextMine == mine) return;
                    mine = nextMine;
                    hub = null;
                    resetToken++;
                  },
                  guarantorStatus: null,
                  onGuarantorChanged: (_) {},
                  destinationFieldResetToken: resetToken,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pump();
      expect(
        find.text("Primary Destination (Partner's Destination)"),
        findsOneWidget,
      );

      await tester.tap(find.text('My Destination'));
      await pump();

      expect(find.text('Primary Destination (My Destination)'), findsOneWidget);
      expect(hub, isNull);
      expect(resetToken, 1);
    });
  });

  group('passport destination after clear', () {
    test('cleared hub fields do not show Partner\'s: TCD', () {
      final session = <String, dynamic>{
        'commute_destination': '',
        'primary_commute_destination': '',
        'commute_destination_hub_id': '',
        'destination_latitude': null,
        'destination_longitude': null,
        'commute_profiles': <Map<String, dynamic>>[],
        'commute_destination_unknown': false,
        'dual_commute_priority': 'person_b',
        'household_commuters_count': 2,
        'full_name': 'Test Seeker',
        'onboarding_intent': 'seeker',
      };

      final snapshot = ContextualPassportSnapshot.fromSession(session);
      expect(snapshot.destinationHub, isEmpty);
      expect(snapshot.destinationHub.contains('TCD'), isFalse);
      expect(snapshot.destinationHub.contains("Partner's:"), isFalse);
    });

    test('baseline leftover label would show partner prefix — cleared keys prevent it',
        () {
      // Simulates merge after owner switch: destination keys explicitly emptied.
      final session = <String, dynamic>{
        'commute_destination': 'Trinity College Dublin (TCD)',
        'commute_destination_hub_id': 'tcd',
        'dual_commute_priority': 'person_b',
        'household_commuters_count': 2,
        'full_name': 'Test Seeker',
        'onboarding_intent': 'seeker',
      };
      final withLeftover = ContextualPassportSnapshot.fromSession(session);
      expect(withLeftover.destinationHub, "Partner's: Trinity College Dublin (TCD)");

      final cleared = ContextualPassportSnapshot.fromSession({
        ...session,
        'commute_destination': '',
        'commute_destination_hub_id': '',
        'commute_profiles': <Map<String, dynamic>>[],
      });
      expect(cleared.destinationHub, isEmpty);
    });
  });
}
