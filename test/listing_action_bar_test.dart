import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/widgets/listing_action_bar.dart';

void main() {
  group('ListingActionBar', () {
    testWidgets('shows apply CTA for viewer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListingActionBar(
              listing: const {
                'id': '1',
                'type': 'Rent',
                'hostName': 'Other Host',
              },
              session: const {'full_name': 'Seeker'},
              space: MarketplaceSpace.fullRental,
              hasApplied: false,
              onApply: () {},
              onManage: () {},
              onStartReplacement: () {},
              onVerifyToApply: () {},
            ),
          ),
        ),
      );

      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('shows manage CTA for owner', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListingActionBar(
              listing: const {
                'id': '1',
                'type': 'Rent',
                'hostName': 'Demo Host',
              },
              session: const {'full_name': 'Demo Host'},
              space: MarketplaceSpace.fullRental,
              hasApplied: false,
              onApply: () {},
              onManage: () {},
              onStartReplacement: () {},
              onVerifyToApply: () {},
            ),
          ),
        ),
      );

      expect(find.text('View applicants'), findsOneWidget);
    });
  });
}
