import 'package:flutter/material.dart';

import '../../debug/agent_log.dart';
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
        // #region agent log
        agentLog(
          location: 'onboarding_grid_shell.dart:build',
          message: 'grid row constraints',
          data: {
            'maxHeight': constraints.maxHeight,
            'maxWidth': constraints.maxWidth,
            'hasBoundedHeight': constraints.hasBoundedHeight,
            'stretchRightPane': stretchRightPane,
          },
          hypothesisId: 'A',
        );
        // #endregion

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