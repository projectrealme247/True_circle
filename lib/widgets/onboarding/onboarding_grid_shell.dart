import 'package:flutter/material.dart';

import 'onboarding_design_tokens.dart';

/// Center → 1280px max → 48px padding → 7/5 Row split.
class OnboardingGridShell extends StatelessWidget {
  const OnboardingGridShell({
    super.key,
    required this.leftPane,
    required this.rightPane,
    this.stretchRightPane = false,
  });

  final Widget leftPane;
  final Widget rightPane;
  final bool stretchRightPane;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: stretchRightPane && constraints.hasBoundedHeight
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: OnboardingTokens.leftFlex,
              child: leftPane,
            ),
            Expanded(
              flex: OnboardingTokens.rightFlex,
              child: rightPane,
            ),
          ],
        );
      },
    );
  }
}