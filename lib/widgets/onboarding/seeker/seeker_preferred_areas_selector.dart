import 'package:flutter/material.dart';

import '../../../config/market/dublin_macro_areas.dart';
import '../onboarding_choice_chip.dart';

/// Reusable preferred-area macro chips for seeker onboarding.
///
/// Extracted from Preferences for the upcoming Destination recommendation
/// flow. Not mounted on Preferences after the Preferences cleanup.
class SeekerPreferredAreasSelector extends StatelessWidget {
  const SeekerPreferredAreasSelector({
    super.key,
    required this.selectedTargetSearchAreas,
    required this.onToggleTargetSearchArea,
  });

  final List<String> selectedTargetSearchAreas;
  final ValueChanged<String> onToggleTargetSearchArea;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (token, label) in DublinMacroAreas.primaryOptions)
          OnboardingChoiceChip(
            label: label,
            selected: selectedTargetSearchAreas.contains(token),
            expand: false,
            onTap: () => onToggleTargetSearchArea(token),
          ),
      ],
    );
  }
}
