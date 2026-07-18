import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../listing_creation/listing_creation_primitives.dart';
import 'onboarding_design_tokens.dart';

/// Outline selection control — seeker cards use fill + border + weight.
class OnboardingChoiceChip extends StatelessWidget {
  const OnboardingChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.expand = true,
    this.centerLabel = false,
    this.compactLabel = false,
    this.dense = false,
    this.seekerOptionStyle = false,
    this.fixedHeight,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final bool expand;
  final bool centerLabel;
  final bool compactLabel;
  /// Destination hub chips: denser padding.
  final bool dense;
  /// Pass-1 option cards: token height, selected fill + weight (no checkmarks).
  final bool seekerOptionStyle;
  /// Override seeker default option height.
  final double? fixedHeight;

  @override
  Widget build(BuildContext context) {
    final padding = dense
        ? const EdgeInsets.symmetric(
            horizontal: OnboardingTokens.space12,
            vertical: OnboardingTokens.space8,
          )
        : seekerOptionStyle
            ? EdgeInsets.symmetric(
                horizontal: OnboardingTokens.space16,
                vertical: 0,
              )
            : expand
                ? EdgeInsets.symmetric(
                    horizontal: compactLabel
                        ? OnboardingTokens.space8
                        : OnboardingTokens.space16,
                    vertical: compactLabel
                        ? OnboardingTokens.space12
                        : OnboardingTokens.space12,
                  )
                : const EdgeInsets.symmetric(
                    horizontal: OnboardingTokens.space12,
                    vertical: OnboardingTokens.space8,
                  );

    final decoration = seekerOptionStyle
        ? SeekerOnboardingLayout.optionDecoration(selected: selected)
        : listingChoiceBoxDecoration(selected: selected, borderRadius: 12);

    final alignCenter = centerLabel;

    Widget chip = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(seekerOptionStyle ? 10 : 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: expand ? double.infinity : null,
          height: centerLabel && !seekerOptionStyle ? double.infinity : null,
          padding: padding,
          decoration: decoration,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment:
                alignCenter ? MainAxisAlignment.center : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: OnboardingTokens.space8),
              ],
              if (expand)
                Expanded(
                  child: Text(
                    label,
                    textAlign: alignCenter ? TextAlign.center : TextAlign.start,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _labelStyle(selected),
                  ),
                )
              else
                Text(
                  label,
                  textAlign: TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(selected),
                ),
            ],
          ),
        ),
      ),
    );

    if (seekerOptionStyle && expand) {
      chip = SizedBox(
        height: fixedHeight ?? SeekerOnboardingLayout.optionRowHeight,
        child: chip,
      );
    }

    return chip;
  }

  TextStyle _labelStyle(bool selected) {
    if (seekerOptionStyle) {
      return SeekerOnboardingLayout.optionRow(selected: selected);
    }
    return OnboardingTokens.chipLabelStyle(selected: selected).copyWith(
      color: const Color(0xFF111827),
    );
  }
}

/// Label left, compact chips right — same full width as [OnboardingPremiumField] input.
class OnboardingInlineChoiceField extends StatelessWidget {
  const OnboardingInlineChoiceField({
    super.key,
    required this.label,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chips = Wrap(
          spacing: OnboardingTokens.space8,
          runSpacing: OnboardingTokens.space8,
          children: [
            for (var i = 0; i < options.length; i++)
              OnboardingChoiceChip(
                label: options[i],
                selected: selectedIndex == i,
                expand: false,
                onTap: () => onSelected(i),
              ),
          ],
        );

        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: listingFieldLabelStyle),
              const SizedBox(height: OnboardingTokens.space8),
              chips,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 5,
              child: Text(
                label,
                style: listingFieldLabelStyle,
              ),
            ),
            const SizedBox(width: OnboardingTokens.space12),
            Expanded(
              flex: 6,
              child: Align(
                alignment: Alignment.centerRight,
                child: chips,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Symmetrical equal-width choice row (guarantor, move-in).
class OnboardingEqualChoiceRow extends StatelessWidget {
  const OnboardingEqualChoiceRow({
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: OnboardingTokens.space8),
            Expanded(
              child: OnboardingChoiceChip(
                label: options[i],
                selected: selectedIndex == i,
                onTap: () => onSelected(i),
                centerLabel: true,
                compactLabel: options.length >= 3,
                seekerOptionStyle: seekerOptionStyle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Horizontal row of compact outline chips (guarantor, move-in, location context).
class OnboardingChoiceChipRow extends StatelessWidget {
  const OnboardingChoiceChipRow({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: OnboardingTokens.space8,
      runSpacing: OnboardingTokens.space8,
      children: [
        for (var i = 0; i < options.length; i++)
          OnboardingChoiceChip(
            label: options[i],
            selected: selectedIndex == i,
            expand: false,
            seekerOptionStyle: true,
            onTap: () => onSelected(i),
          ),
      ],
    );
  }
}

/// Toggle language chip with outline selection state.
class OnboardingLanguageToggleChip extends StatelessWidget {
  const OnboardingLanguageToggleChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: OnboardingTokens.space12,
            vertical: OnboardingTokens.space4,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentLight : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.accent : listingChoiceBorderUnselected,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: OnboardingTokens.chipLabelStyle(selected: selected)
                    .copyWith(
                  color: selected ? AppColors.accent : AppColors.secondaryText,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: OnboardingTokens.space4),
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
