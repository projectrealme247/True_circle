import 'package:flutter/material.dart';

import '../../../models/seeker_onboarding_enums.dart';
import '../onboarding_choice_chip.dart';

/// Mandatory persona split beneath space track on seeker screen 1.
class SeekerPersonaSelector extends StatelessWidget {
  const SeekerPersonaSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.showHeading = true,
  });

  final SeekerPersona? selected;
  final ValueChanged<SeekerPersona> onChanged;
  final bool showHeading;

  static const _personas = [
    SeekerPersona.student,
    SeekerPersona.professional,
    SeekerPersona.family,
  ];

  static const _labels = [
    '🎓 Student',
    '💼 Working Professional (Single / Couple)',
    '👨‍👩‍👧‍👦 Family',
  ];

  SeekerPersona? _resolvedSelection(SeekerPersona? value) {
    if (value == null) return null;
    if (value == SeekerPersona.relocating) return SeekerPersona.professional;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedSelection(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text(
            'What best describes you?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < _personas.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          OnboardingChoiceChip(
            label: _labels[i],
            selected: resolved == _personas[i],
            onTap: () => onChanged(_personas[i]),
          ),
        ],
      ],
    );
  }
}
