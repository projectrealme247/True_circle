import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/core/theme/app_theme.dart';
import 'package:true_circle/models/applicant_trust_tier.dart';
import 'package:true_circle/theme/trust_tier_design.dart';
import 'package:true_circle/widgets/trust_badge.dart';

void main() {
  const tiers = [
    ApplicantTrustTier.justLanded,
    ApplicantTrustTier.grand,
    ApplicantTrustTier.sound,
  ];

  testWidgets('TrustBadge uses neutral surface2 bg for every tier', (
    tester,
  ) async {
    for (final tier in tiers) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: TrustBadge(tier: tier)),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(TrustBadge),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration! as BoxDecoration;

      expect(
        decoration.color,
        TrustTierDesign.trustScaleCapsuleBg,
        reason: 'Tier $tier should use neutral badge background',
      );
      expect(
        decoration.color,
        AppColors.surface2,
        reason: 'Tier $tier should map to AppColors.surface2',
      );
    }
  });

  testWidgets('TrustBadge golden — all tiers neutral grey pills', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.surface,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < tiers.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  TrustBadge(tier: tiers[i]),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Just Landed'), findsOneWidget);
    expect(find.textContaining('Grand'), findsOneWidget);
    expect(find.textContaining('Sound'), findsOneWidget);

    await expectLater(
      find.byType(Column),
      matchesGoldenFile('goldens/trust_badge_all_tiers_neutral.png'),
    );
  });
}
