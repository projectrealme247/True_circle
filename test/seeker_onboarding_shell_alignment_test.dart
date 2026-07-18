import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/widgets/onboarding/onboarding_design_tokens.dart';
import 'package:true_circle/widgets/onboarding/seeker/seeker_onboarding_shell.dart';

void main() {
  testWidgets('passport card height matches left column including Continue',
      (tester) async {
    final passportKey = GlobalKey();
    final continueKey = GlobalKey();

    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeekerOnboardingShell(
            progress: const SizedBox(height: 32),
            leftBody: const Text('Left body'),
            leftFooter: KeyedSubtree(
              key: continueKey,
              child: const SizedBox(
                height: 40,
                width: double.infinity,
                child: ColoredBox(color: Colors.orange),
              ),
            ),
            rightPane: KeyedSubtree(
              key: passportKey,
              child: DecoratedBox(
                decoration: SeekerOnboardingLayout.passportPanelDecoration(),
                child: const SizedBox.expand(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Passport'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Inject key onto left ColoredBox by finding white ColoredBox under shell.
    final coloredBoxes = find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color == Colors.white,
    );
    expect(coloredBoxes, findsOneWidget);

    final leftColumnBox = tester.renderObject(coloredBoxes) as RenderBox;
    final passportBox = tester.renderObject(find.byKey(passportKey)) as RenderBox;
    final continueBox =
        tester.renderObject(find.byKey(continueKey)) as RenderBox;

    final leftHeight = leftColumnBox.size.height;
    final passportHeight = passportBox.size.height;
    final leftBottom = leftColumnBox.localToGlobal(Offset(0, leftHeight)).dy;
    final passportBottom =
        passportBox.localToGlobal(Offset(0, passportHeight)).dy;
    final continueBottom =
        continueBox.localToGlobal(Offset(0, continueBox.size.height)).dy;

    // ignore: avoid_print
    print('MEASURE leftHeight=$leftHeight passportHeight=$passportHeight '
        'diff=${(leftHeight - passportHeight).abs()} '
        'leftBottom=$leftBottom passportBottom=$passportBottom '
        'continueBottom=$continueBottom '
        'continueVsPassport=${(continueBottom - passportBottom).abs()}');

    expect(passportHeight, moreOrLessEquals(leftHeight, epsilon: 0.5),
        reason: 'passport must match left column outer height');
    expect(passportBottom, moreOrLessEquals(leftBottom, epsilon: 0.5),
        reason: 'passport bottom must match left column bottom');
    expect(continueBottom, moreOrLessEquals(passportBottom, epsilon: 0.5),
        reason: 'Continue bottom must match passport border bottom');
  });
}
