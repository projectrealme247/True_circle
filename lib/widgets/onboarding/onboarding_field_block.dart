import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../emoji_leading_row.dart';
import 'onboarding_choice_chip.dart';
import 'onboarding_design_tokens.dart';

/// Surface card grouping for seeker onboarding steps 1–2.
class OnboardingStepCard extends StatelessWidget {
  const OnboardingStepCard({
    super.key,
    required this.title,
    required this.child,
    this.verticalPadding = OnboardingTokens.stepCardPaddingV,
    this.seekerTypography = false,
  });

  final String title;
  final Widget child;
  final double verticalPadding;
  /// Pass-1 section headings (16 / semibold).
  final bool seekerTypography;

  @override
  Widget build(BuildContext context) {
    final titleStyle = seekerTypography
        ? SeekerOnboardingLayout.sectionLabel
        : OnboardingTokens.sectionLabelStyle;
    final padding = EdgeInsets.symmetric(
      horizontal: OnboardingTokens.stepCardPaddingH,
      vertical: verticalPadding,
    );
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(OnboardingTokens.stepCardRadius),
        border: Border.all(color: OnboardingTokens.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: titleStyle),
          SizedBox(
            height: seekerTypography
                ? OnboardingTokens.space8
                : OnboardingTokens.space12,
          ),
          child,
        ],
      ),
    );
  }
}

/// Label-above-field section block — enforces stacked hierarchy at 600px width.
class OnboardingFieldBlock extends StatelessWidget {
  const OnboardingFieldBlock({
    super.key,
    this.label,
    this.labelEmoji,
    required this.child,
  });

  final String? label;
  final String? labelEmoji;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          if (labelEmoji != null)
            EmojiLeadingRow(
              emoji: labelEmoji!,
              text: label!,
              style: SeekerOnboardingLayout.fieldLabel,
              crossAxisAlignment: CrossAxisAlignment.start,
            )
          else
            Text(label!, style: SeekerOnboardingLayout.fieldLabel),
          const SizedBox(height: OnboardingTokens.space4),
        ],
        child,
      ],
    );
  }
}

/// Full-width stacked outline choice rows (guarantor, location context).
class OnboardingStackedChoiceList extends StatelessWidget {
  const OnboardingStackedChoiceList({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.seekerOptionStyle = true,
  });

  final List<String> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final bool seekerOptionStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) SizedBox(height: seekerOptionStyle ? OnboardingTokens.space8 : OnboardingTokens.space8),
          OnboardingChoiceChip(
            label: options[i],
            selected: selectedIndex == i,
            onTap: () => onSelected(i),
            seekerOptionStyle: seekerOptionStyle,
          ),
        ],
      ],
    );
  }
}

/// Symmetrical equal-width row — 3-column grids and move-in window.
class OnboardingEqualGridRow extends StatelessWidget {
  const OnboardingEqualGridRow({
    super.key,
    required this.labels,
    required this.selectedIndices,
    required this.onSelected,
    this.compactLabel = true,
    this.dense = false,
    this.seekerOptionStyle = true,
    this.fixedHeight,
  });

  final List<String> labels;
  final Set<int> selectedIndices;
  final ValueChanged<int> onSelected;
  final bool compactLabel;
  final bool dense;
  final bool seekerOptionStyle;
  final double? fixedHeight;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) SizedBox(width: dense ? OnboardingTokens.space8 : OnboardingTokens.space8),
            Expanded(
              child: OnboardingChoiceChip(
                label: labels[i],
                selected: selectedIndices.contains(i),
                onTap: () => onSelected(i),
                centerLabel: true,
                compactLabel: compactLabel,
                dense: dense,
                seekerOptionStyle: seekerOptionStyle,
                fixedHeight: fixedHeight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
