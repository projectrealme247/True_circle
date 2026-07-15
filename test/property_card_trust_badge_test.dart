import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin_v2.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/utils/listing_data.dart';
import 'package:true_circle/utils/listing_match_engine.dart';
import 'package:true_circle/utils/viewer_profile.dart';
import 'package:true_circle/widgets/property_card.dart';
import 'package:true_circle/widgets/trust_badge.dart';

void main() {
  testWidgets('PropertyCard shows full trust badge for host_trust_stage', (
    tester,
  ) async {
    final share = SampleListingsDublinV2.items.firstWhere(
      (l) =>
          ListingData.propertyType(l) == 'Share' &&
          ListingData.hostTrustStage(l) == 2,
    );
    final session = {
      'occupant_type': 'Students',
      'budget_max': 850,
      'detected_city': 'Dublin',
    };
    final viewer = ViewerProfile.fromSession(session);
    final match = ListingMatchEngine.evaluate(
      share,
      viewer,
      viewerSession: session,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: PropertyCard.gridMainAxisExtent,
            child: PropertyCard(
              listing: share,
              match: match,
              activeSpace: MarketplaceSpace.sharedSpace,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TrustBadge), findsOneWidget);
    final badgeSize = tester.getSize(find.byType(TrustBadge));
    expect(
      badgeSize.height,
      greaterThanOrEqualTo(22),
      reason: 'Trust badge should not be vertically clipped',
    );
    expect(
      find.textContaining('Grand'),
      findsOneWidget,
    );

    await expectLater(
      find.byType(PropertyCard),
      matchesGoldenFile('goldens/property_card_trust_badge.png'),
    );
  });
}
