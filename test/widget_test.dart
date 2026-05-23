import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/main.dart';

void main() {
  testWidgets('Home page shows title', (WidgetTester tester) async {
    await tester.pumpWidget(const CircleKeyApp());
    expect(find.text('CircleKey'), findsOneWidget);
  });
}
