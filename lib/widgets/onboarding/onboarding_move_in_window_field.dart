import 'package:flutter/material.dart';

import '../../models/move_in_timing.dart';
import 'onboarding_choice_chip.dart';

/// Chip selector for seeker move-in month windows (never exact dates).
class OnboardingMoveInWindowField extends StatelessWidget {
  const OnboardingMoveInWindowField({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final SeekerMoveInWindow? selected;
  final ValueChanged<SeekerMoveInWindow> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = SeekerMoveInWindow.values;
    final selectedIndex = selected == null
        ? null
        : options.indexOf(selected!);

    return OnboardingEqualChoiceRow(
      options: [for (final w in options) w.label],
      selectedIndex: selectedIndex,
      onSelected: (index) => onChanged(options[index]),
    );
  }
}
