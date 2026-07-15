import 'package:flutter/material.dart';

import '../../../config/market/dublin_commuter_hubs.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/move_in_timing.dart';
import '../../../models/seeker_onboarding_enums.dart';
import '../../commute_destination_field.dart';
import '../../gamified_form_wizard.dart';
import '../onboarding_design_tokens.dart';
import '../onboarding_field_block.dart';
import '../onboarding_move_in_window_field.dart';
import '../onboarding_grid_shell.dart';

/// Seeker onboarding screen 3 — commute hub, travel time, move-in, guarantor.
class SeekerOnboardingDestinationScreen extends StatelessWidget {
  const SeekerOnboardingDestinationScreen({
    super.key,
    required this.persona,
    required this.selectedHub,
    required this.commuteDestinationUnknown,
    required this.maxCommuteMinutes,
    required this.onHubSelected,
    required this.onHubCleared,
    required this.onCommuteDestinationUnknown,
    required this.onCommuteMinutesChanged,
    required this.moveInWindow,
    required this.onMoveInWindowChanged,
    required this.guarantorStatus,
    required this.onGuarantorChanged,
  });

  final SeekerPersona? persona;
  final DublinCommuterHub? selectedHub;
  final bool commuteDestinationUnknown;
  final int maxCommuteMinutes;
  final ValueChanged<DublinCommuterHub> onHubSelected;
  final VoidCallback onHubCleared;
  final VoidCallback onCommuteDestinationUnknown;
  final ValueChanged<int> onCommuteMinutesChanged;
  final SeekerMoveInWindow? moveInWindow;
  final ValueChanged<SeekerMoveInWindow> onMoveInWindowChanged;
  final GuarantorStatus? guarantorStatus;
  final ValueChanged<GuarantorStatus> onGuarantorChanged;

  bool get _showGuarantor => persona?.requiresGuarantorQuestion ?? false;

  int get _guarantorSelectedIndex {
    if (guarantorStatus != null) {
      return GuarantorStatus.values.indexOf(guarantorStatus!);
    }
    return GuarantorStatus.values.indexOf(GuarantorStatus.notSureYet);
  }

  @override
  Widget build(BuildContext context) {
    final sliderIndex = SeekerCommuteTimeOptions.indexOf(maxCommuteMinutes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GamifiedFormPageHeader(
          title: 'Your Dublin geography',
          titleEmoji: '🗺️',
          subtitle:
              'We optimize your listings based on your daily transit hubs.',
        ),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        CommuteDestinationField(
          persona: persona,
          selectedHub: selectedHub,
          commuteDestinationUnknown: commuteDestinationUnknown,
          onHubSelected: onHubSelected,
          onCleared: onHubCleared,
          onCommuteDestinationUnknown: onCommuteDestinationUnknown,
        ),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        OnboardingFieldBlock(
          labelEmoji: '⏳',
          label: 'Maximum desired travel time: $maxCommuteMinutes min',
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.accent,
              thumbColor: AppColors.accent,
              inactiveTrackColor: const Color(0xFFE5E7EB),
            ),
            child: Slider(
              value: sliderIndex.toDouble(),
              min: 0,
              max: (SeekerCommuteTimeOptions.values.length - 1).toDouble(),
              divisions: SeekerCommuteTimeOptions.values.length - 1,
              label: '$maxCommuteMinutes min',
              onChanged: (v) => onCommuteMinutesChanged(
                SeekerCommuteTimeOptions.values[v.round()],
              ),
            ),
          ),
        ),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        OnboardingFieldBlock(
          labelEmoji: '📅',
          label: 'When do you want to move in?',
          child: OnboardingMoveInWindowField(
            selected: moveInWindow,
            onChanged: onMoveInWindowChanged,
          ),
        ),
        if (_showGuarantor) ...[
          const SizedBox(height: OnboardingTokens.fieldSpacing),
          OnboardingStepCard(
            title: 'Guarantor status',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Do you have an Irish guarantor?',
                  style: OnboardingTokens.sectionLabelStyle.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Some hosts ask for this later. It won\'t affect your matches now.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 12),
                OnboardingEqualGridRow(
                  labels: const ['Yes', 'No', 'Not sure yet'],
                  selectedIndices: {_guarantorSelectedIndex},
                  onSelected: (index) =>
                      onGuarantorChanged(GuarantorStatus.values[index]),
                  compactLabel: true,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
