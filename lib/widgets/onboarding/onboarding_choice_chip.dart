import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../listing_creation/listing_creation_primitives.dart';
/// Outline selection control — 1.5px dark border when selected, no fill inversion.
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final bool expand;
  final bool centerLabel;
  final bool compactLabel;

  @override
  Widget build(BuildContext context) {
    final padding = expand
        ? EdgeInsets.symmetric(
            horizontal: compactLabel ? 8 : 16,
            vertical: compactLabel ? 12 : 14,
          )
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 10);

    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: expand ? double.infinity : null,
          height: centerLabel ? double.infinity : null,
          padding: padding,
          decoration: listingChoiceBoxDecoration(selected: selected, borderRadius: 12),
          alignment: centerLabel ? Alignment.center : null,
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment:
                centerLabel ? MainAxisAlignment.center : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 10),
              ],
              if (expand)
                Expanded(
                  child: Text(
                    label,
                    textAlign: centerLabel ? TextAlign.center : TextAlign.start,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _labelStyle(selected),
                  ),
                )
              else
                Text(
                  label,
                  textAlign: centerLabel ? TextAlign.center : TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(selected),
                ),
            ],
          ),
        ),
      ),
    );

    return child;
  }

  TextStyle _labelStyle(bool selected) => TextStyle(
        fontSize: compactLabel ? 12 : 14,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: const Color(0xFF111827),
        height: 1.25,
        fontFamily: 'PlusJakartaSans',
        fontFamilyFallback: AppTypography.emojiFontFallback,
      );
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
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
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
              const SizedBox(height: listingLabelSpacing),
              chips,
            ],
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: listingFieldHeight),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  label,
                  style: listingFieldLabelStyle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: chips,
                ),
              ),
            ],
          ),
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
  });

  final List<String> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: OnboardingChoiceChip(
                label: options[i],
                selected: selectedIndex == i,
                onTap: () => onSelected(i),
                centerLabel: true,
                compactLabel: options.length >= 3,
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
      spacing: 8,
      runSpacing: 8,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accentLight
                : Colors.transparent,
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.accent : AppColors.secondaryText,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
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
