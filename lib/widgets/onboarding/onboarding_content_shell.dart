import 'package:flutter/material.dart';

import '../../debug/agent_log.dart';
import '../../theme/app_scroll_behavior.dart';
import 'onboarding_design_tokens.dart';

/// White panel frame — matches [ContextualPassportCard] outer chrome.
class OnboardingPanelFrame extends StatelessWidget {
  const OnboardingPanelFrame({
    super.key,
    required this.child,
    this.maxWidth = OnboardingTokens.contentMaxWidth,
    this.padding = OnboardingTokens.panelCardPadding,
    this.stretchVertically = false,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  /// When true, fills the grid row height (passport preview). When false, hugs content.
  final bool stretchVertically;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // #region agent log
        agentLog(
          'H1',
          'onboarding_content_shell.dart:OnboardingPanelFrame',
          'panel frame constraints',
          {
            'maxH': constraints.maxHeight,
            'minH': constraints.minHeight,
            'hasBoundedHeight': constraints.hasBoundedHeight,
            'stretchVertically': stretchVertically,
          },
        );
        // #endregion

        final scrollChild = ScrollConfiguration(
          behavior: const OnboardingFormScrollBehavior(),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            primary: false,
            physics: appPageScrollPhysics,
            padding: padding,
            child: child,
          ),
        );

        final framedChild = DecoratedBox(
          decoration: OnboardingTokens.panelCardDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(OnboardingTokens.panelRadius),
            child: scrollChild,
          ),
        );

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: stretchVertically
                ? SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: framedChild,
                  )
                : SizedBox(
                    width: double.infinity,
                    child: framedChild,
                  ),
          ),
        );
      },
    );
  }
}

/// Centered 600px scroll column shared by seeker and landlord onboarding.
class OnboardingContentShell extends StatelessWidget {
  const OnboardingContentShell({
    super.key,
    required this.child,
    this.minViewportHeight,
  });

  final Widget child;

  /// When set, short pages stretch to fill the step viewport (seeker pages 2–3).
  final double? minViewportHeight;

  @override
  Widget build(BuildContext context) {
    final minHeight = minViewportHeight;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: OnboardingTokens.contentMaxWidth,
        ),
        child: ScrollConfiguration(
          behavior: const OnboardingFormScrollBehavior(),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            primary: true,
            physics: appPageScrollPhysics,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: minHeight != null && minHeight > 0 ? minHeight : 0,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
