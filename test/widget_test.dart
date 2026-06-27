import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/widgets/truecircle_logo.dart';

void main() {
  testWidgets('TrueCircle logo renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrueCircleLogo(height: 40),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });
}
