import 'package:flutter/material.dart';

import '../onboarding_design_tokens.dart';

/// Full-viewport seeker onboarding: centered ~70% band, no page scroll.
///
/// Progress tracker + columns share one band width.
/// Left white column and right passport card share the same Row height so
/// their outer top/bottom edges align (passport fills the right cell).
class SeekerOnboardingShell extends StatelessWidget {
  const SeekerOnboardingShell({
    super.key,
    required this.progress,
    required this.leftBody,
    required this.leftFooter,
    required this.rightPane,
  });

  final Widget progress;
  final Widget leftBody;
  final Widget leftFooter;
  final Widget rightPane;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: OnboardingTokens.canvasBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bandWidth = (constraints.maxWidth *
                  SeekerOnboardingLayout.contentBandWidthFactor)
              .clamp(720.0, constraints.maxWidth);

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: bandWidth,
              height: constraints.maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: OnboardingTokens.space8,
                    ),
                    child: progress,
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: SeekerOnboardingLayout.leftFlex,
                          child: ColoredBox(
                            color: Colors.white,
                            child: Padding(
                              // Bottom 0 so Continue sits on the column bottom
                              // edge — same Y as the passport card border.
                              padding: SeekerOnboardingLayout.leftColumnInsets,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: leftBody,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: OnboardingTokens.space8,
                                  ),
                                  leftFooter,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: SeekerOnboardingLayout.rightFlex,
                          // No outer padding: passport card IS the column.
                          child: rightPane,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Page heading + subheading using seeker polish typography.
class SeekerOnboardingPageHeader extends StatelessWidget {
  const SeekerOnboardingPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: SeekerOnboardingLayout.pageHeading),
        SizedBox(
          height: compact ? OnboardingTokens.space4 : OnboardingTokens.space8,
        ),
        Text(subtitle, style: SeekerOnboardingLayout.pageSubheading),
      ],
    );
  }
}

/// Optional fit helper for step screens that must fill a bounded height.
class SeekerStepFitColumn extends StatelessWidget {
  const SeekerStepFitColumn({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        if (!maxHeight.isFinite) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          );
        }
        return SizedBox(
          height: maxHeight,
          width: constraints.maxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
      },
    );
  }
}
