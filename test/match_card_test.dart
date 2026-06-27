import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/core/theme/app_theme.dart';
import 'package:true_circle/widgets/match_card.dart';

void main() {
  testWidgets('MatchCard renders title and lifestyle tags', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: MatchCard(
                title: 'Sample flatmate',
                lifestyleTags: const ['Veg', 'Non-Smoking'],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sample flatmate'), findsOneWidget);
    expect(find.text('Veg'), findsOneWidget);
    expect(find.text('Non-Smoking'), findsOneWidget);
  });

  test('AppTheme cardDecoration uses 16px radius and soft shadow', () {
    final decoration = AppTheme.cardDecoration();
    expect(decoration.borderRadius, BorderRadius.circular(AppRadius.lg));
    expect(decoration.boxShadow, isNotEmpty);
    expect(decoration.boxShadow!.first.blurRadius, 8);
  });
}
