import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/core/theme/app_theme.dart';
import 'package:true_circle/services/trust_service.dart';
import 'package:true_circle/theme/trust_tier_design.dart';
import 'package:true_circle/widgets/trust_badge.dart';

void main() {
  testWidgets('TrustBadge shows Verified User when verified', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: TrustBadge(isVerified: true)),
        ),
      ),
    );

    expect(find.text(TrustBadge.label), findsOneWidget);

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(TrustBadge),
        matching: find.byType(Container),
      ).first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, TrustTierDesign.trustScaleCapsuleBg);
    expect(decoration.color, AppColors.surface2);
  });

  testWidgets('TrustBadge is empty when not verified', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: TrustBadge(isVerified: false)),
        ),
      ),
    );

    expect(find.text(TrustBadge.label), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('TrustBadge.fromHostTrustStage never shows Verified User', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TrustBadge.fromHostTrustStage(3, hostVerifiedBadge: true),
          ),
        ),
      ),
    );

    expect(find.text(TrustBadge.label), findsNothing);
  });

  test('TrustBadge.fromSession uses contact unlock, not trust_stage', () {
    final withStageOnly = TrustBadge.fromSession({
      'trust_stage': 3,
      'trust_tier': 'Sound',
      'occupant_type': 'Students',
    });
    expect(withStageOnly.isVerified, isFalse);

    final student = TrustBadge.fromSession({
      'occupant_type': 'Students',
      'onboarding_letter_verified': true,
    });
    expect(student.isVerified, isTrue);

    final professional = TrustBadge.fromSession({
      'occupant_type': 'Working Professionals',
      'linkedin_verified': true,
    });
    expect(professional.isVerified, isTrue);

    expect(
      TrustService.meetsContactVerification({
        'occupant_type': 'Family',
        'family_children': 1,
        'employment_verified': true,
      }),
      isTrue,
    );
  });
}
