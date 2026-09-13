import 'package:flutter/material.dart';

import '../../../models/seeker_onboarding_enums.dart';
import '../onboarding_choice_chip.dart';
import '../onboarding_design_tokens.dart';
import 'seeker_shared_choice_chips.dart';

/// Mandatory persona split beneath space track on seeker screen 1.
class SeekerPersonaSelector extends StatelessWidget {
  const SeekerPersonaSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.showHeading = true,
    this.isSharedTrack = false,
  });

  final SeekerPersona? selected;
  final ValueChanged<SeekerPersona> onChanged;
  final bool showHeading;
  final bool isSharedTrack;

  static const _ipPersonas = [
    SeekerPersona.student,
    SeekerPersona.professional,
    SeekerPersona.family,
  ];

  static const _ipLabels = [
    '🎓 Student',
    '💼 Working Professional (Single / Couple)',
    '👨‍👩‍👧‍👦 Family',
  ];

  static const _sharedOptions = <SeekerPersona, String>{
    SeekerPersona.professional: '💼 Working Professional',
    SeekerPersona.student: '🎓 Student',
  };

  SeekerPersona? _resolvedSelection(SeekerPersona? value) {
    if (value == null) return null;
    if (value == SeekerPersona.relocating) return SeekerPersona.professional;
    if (isSharedTrack && value == SeekerPersona.family) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedSelection(selected);

    if (isSharedTrack) {
      return SeekerSharedChoiceRow<SeekerPersona>(
        options: _sharedOptions,
        selected: resolved == SeekerPersona.student ||
                resolved == SeekerPersona.professional
            ? resolved
            : null,
        onChanged: onChanged,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading) ...[
          Text(
            'What best describes you?',
            style: SeekerOnboardingLayout.sectionLabel,
          ),
          const SizedBox(height: OnboardingTokens.space8),
        ],
        SeekerOnboardingLayout.constrainOptionCluster(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _ipPersonas.length; i++) ...[
                if (i > 0) const SizedBox(height: OnboardingTokens.space8),
                OnboardingChoiceChip(
                  label: _ipLabels[i],
                  selected: resolved == _ipPersonas[i],
                  onTap: () => onChanged(_ipPersonas[i]),
                  seekerOptionStyle: true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
