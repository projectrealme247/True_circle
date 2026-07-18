import 'package:flutter/material.dart';

import '../../../config/market/dublin_commuter_hubs.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/move_in_timing.dart';
import '../../../models/seeker_onboarding_enums.dart';
import '../../../services/commute_scoring_service.dart';
import '../../commute_destination_field.dart';
import '../../gamified_form_wizard.dart';
import '../onboarding_choice_chip.dart';
import '../onboarding_design_tokens.dart';
import '../onboarding_field_block.dart';
import '../onboarding_move_in_window_field.dart';

/// Seeker onboarding screen 3 — destination intelligence layer (structure).
///
/// Fits the fixed onboarding shell (no left-column scroll).
class SeekerOnboardingDestinationScreen extends StatefulWidget {
  const SeekerOnboardingDestinationScreen({
    super.key,
    required this.persona,
    required this.commuteMethod,
    required this.onCommuteMethodChanged,
    required this.selectedHub,
    required this.commuteDestinationUnknown,
    required this.maxCommuteMinutes,
    required this.onHubSelected,
    required this.onHubCleared,
    required this.onCommuteDestinationUnknown,
    required this.onCommuteMinutesChanged,
    required this.partnerCommuteEnabled,
    required this.onPartnerCommuteEnabledChanged,
    required this.partnerHub,
    required this.partnerMaxCommuteMinutes,
    required this.onPartnerHubSelected,
    required this.onPartnerHubCleared,
    required this.onPartnerCommuteMinutesChanged,
    required this.dualCommutePriority,
    required this.onDualCommutePriorityChanged,
    required this.moveInWindow,
    required this.onMoveInWindowChanged,
    required this.guarantorStatus,
    required this.onGuarantorChanged,
  });

  final SeekerPersona? persona;
  final CommuteMethod commuteMethod;
  final ValueChanged<CommuteMethod> onCommuteMethodChanged;
  final DublinCommuterHub? selectedHub;
  final bool commuteDestinationUnknown;
  final int maxCommuteMinutes;
  final ValueChanged<DublinCommuterHub> onHubSelected;
  final VoidCallback onHubCleared;
  final VoidCallback onCommuteDestinationUnknown;
  final ValueChanged<int> onCommuteMinutesChanged;
  final bool partnerCommuteEnabled;
  final ValueChanged<bool> onPartnerCommuteEnabledChanged;
  final DublinCommuterHub? partnerHub;
  final int partnerMaxCommuteMinutes;
  final ValueChanged<DublinCommuterHub> onPartnerHubSelected;
  final VoidCallback onPartnerHubCleared;
  final ValueChanged<int> onPartnerCommuteMinutesChanged;
  final DualCommutePriority dualCommutePriority;
  final ValueChanged<DualCommutePriority> onDualCommutePriorityChanged;
  final SeekerMoveInWindow? moveInWindow;
  final ValueChanged<SeekerMoveInWindow> onMoveInWindowChanged;
  final GuarantorStatus? guarantorStatus;
  final ValueChanged<GuarantorStatus> onGuarantorChanged;

  @override
  State<SeekerOnboardingDestinationScreen> createState() =>
      _SeekerOnboardingDestinationScreenState();
}

class _SeekerOnboardingDestinationScreenState
    extends State<SeekerOnboardingDestinationScreen> {
  static const _priorityLabels = [
    'Closer to me',
    'Closer to partner',
    'Equal',
  ];

  /// UI-only family driver; recommendation logic comes later.
  FamilyLocationDriver? _familyLocationDriver;

  bool get _showGuarantor =>
      widget.persona?.requiresGuarantorQuestion ?? false;

  bool get _showPartnerCommute =>
      widget.persona == SeekerPersona.professional ||
      widget.persona == SeekerPersona.family;

  bool get _isFamilyPersona => widget.persona == SeekerPersona.family;

  int get _guarantorSelectedIndex {
    if (widget.guarantorStatus != null) {
      return GuarantorStatus.values.indexOf(widget.guarantorStatus!);
    }
    return GuarantorStatus.values.indexOf(GuarantorStatus.notSureYet);
  }

  int get _prioritySelectedIndex => switch (widget.dualCommutePriority) {
        DualCommutePriority.personA => 0,
        DualCommutePriority.personB => 1,
        DualCommutePriority.balanced => 2,
      };

  int? get _familyDriverSelectedIndex => switch (_familyLocationDriver) {
        FamilyLocationDriver.workplace => 0,
        FamilyLocationDriver.schoolArea => 1,
        FamilyLocationDriver.both => 2,
        FamilyLocationDriver.customLocation => 3,
        null => null,
      };

  List<SeekerMacroPreset>? get _familyPresetOverride {
    return switch (_familyLocationDriver) {
      FamilyLocationDriver.workplace =>
        DublinCommuterHubs.professionalDestinationPresets,
      FamilyLocationDriver.schoolArea =>
        DublinCommuterHubs.studentDestinationPresets,
      FamilyLocationDriver.both => [
          ...DublinCommuterHubs.studentDestinationPresets,
          ...DublinCommuterHubs.professionalDestinationPresets,
        ],
      FamilyLocationDriver.customLocation || null => null,
    };
  }

  bool get _showFamilyDestinationField =>
      !_isFamilyPersona || _familyLocationDriver != null;

  bool get _showFamilyPresets =>
      !_isFamilyPersona ||
      (_familyLocationDriver != null &&
          _familyLocationDriver != FamilyLocationDriver.customLocation);

  Widget _sectionGap() => const SizedBox(height: OnboardingTokens.space12);

  Widget _travelTimeSlider({
    required BuildContext context,
    required int minutes,
    required ValueChanged<int> onChanged,
  }) {
    final sliderIndex = SeekerCommuteTimeOptions.indexOf(minutes);
    return SliderTheme(
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
        label: '$minutes min',
        onChanged: (v) => onChanged(
          SeekerCommuteTimeOptions.values[v.round()],
        ),
      ),
    );
  }

  Widget _primaryDestinationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Primary Destination',
          style: SeekerOnboardingLayout.sectionLabel,
        ),
        const SizedBox(height: OnboardingTokens.space4),
        Text(
          'Where do you need to be most weekdays?',
          style: SeekerOnboardingLayout.fieldLabel,
        ),
        const SizedBox(height: OnboardingTokens.space8),
        if (_isFamilyPersona) ...[
          OnboardingEqualGridRow(
            labels: const ['Workplace', 'School Area'],
            selectedIndices: {
              if (_familyDriverSelectedIndex == 0) 0,
              if (_familyDriverSelectedIndex == 1) 1,
            },
            onSelected: (index) => setState(() {
              _familyLocationDriver = index == 0
                  ? FamilyLocationDriver.workplace
                  : FamilyLocationDriver.schoolArea;
            }),
            compactLabel: true,
            dense: true,
          ),
          const SizedBox(height: OnboardingTokens.space8),
          OnboardingEqualGridRow(
            labels: const ['Both', 'Custom Location'],
            selectedIndices: {
              if (_familyDriverSelectedIndex == 2) 0,
              if (_familyDriverSelectedIndex == 3) 1,
            },
            onSelected: (index) => setState(() {
              _familyLocationDriver = index == 0
                  ? FamilyLocationDriver.both
                  : FamilyLocationDriver.customLocation;
            }),
            compactLabel: true,
            dense: true,
          ),
          if (_showFamilyDestinationField) ...[
            const SizedBox(height: OnboardingTokens.space8),
            CommuteDestinationField(
              persona: widget.persona,
              selectedHub: widget.selectedHub,
              commuteDestinationUnknown: widget.commuteDestinationUnknown,
              onHubSelected: widget.onHubSelected,
              onCleared: widget.onHubCleared,
              onCommuteDestinationUnknown: widget.onCommuteDestinationUnknown,
              showPresets: _showFamilyPresets,
              presetOverride: _familyPresetOverride,
              compactPresets: true,
              seekerPolishStyle: true,
              label: '',
            ),
          ],
        ] else
          CommuteDestinationField(
            persona: widget.persona,
            selectedHub: widget.selectedHub,
            commuteDestinationUnknown: widget.commuteDestinationUnknown,
            onHubSelected: widget.onHubSelected,
            onCleared: widget.onHubCleared,
            onCommuteDestinationUnknown: widget.onCommuteDestinationUnknown,
            compactPresets: true,
            seekerPolishStyle: true,
            label: '',
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GamifiedFormPageHeader(
          title: 'Destination',
          subtitle:
              'Where you need to be, how you travel, and how far you will go.',
        ),
        const SizedBox(height: OnboardingTokens.space12),

        // 1. Primary destination
        _primaryDestinationSection(),
        _sectionGap(),

        // 2. Transport mode
        OnboardingFieldBlock(
          label: 'Transport Mode',
          child: OnboardingEqualChoiceRow(
            options: const ['Public transport', 'Driving'],
            selectedIndex:
                widget.commuteMethod == CommuteMethod.driving ? 1 : 0,
            onSelected: (index) => widget.onCommuteMethodChanged(
              index == 1
                  ? CommuteMethod.driving
                  : CommuteMethod.publicTransportWalking,
            ),
          ),
        ),
        _sectionGap(),

        // 3. Maximum travel time
        OnboardingFieldBlock(
          label: 'Maximum Travel Time: ${widget.maxCommuteMinutes} min',
          child: _travelTimeSlider(
            context: context,
            minutes: widget.maxCommuteMinutes,
            onChanged: widget.onCommuteMinutesChanged,
          ),
        ),
        _sectionGap(),

        // 4. Move-in timeline
        OnboardingFieldBlock(
          label: 'Move-in Timeline',
          child: OnboardingMoveInWindowField(
            selected: widget.moveInWindow,
            onChanged: widget.onMoveInWindowChanged,
          ),
        ),

        // Guarantor (existing student logic — retained)
        if (_showGuarantor) ...[
          _sectionGap(),
          OnboardingFieldBlock(
            label: 'Do you have an Irish guarantor?',
            child: OnboardingEqualGridRow(
              labels: const ['Yes', 'No', 'Not sure yet'],
              selectedIndices: {_guarantorSelectedIndex},
              onSelected: (index) =>
                  widget.onGuarantorChanged(GuarantorStatus.values[index]),
              compactLabel: true,
              dense: true,
            ),
          ),
        ],

        // 5. Partner destination (existing optional support)
        if (_showPartnerCommute) ...[
          _sectionGap(),
          OnboardingFieldBlock(
            label: "Partner's Destination",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OnboardingChoiceChip(
                  label: widget.partnerCommuteEnabled
                      ? "Partner's destination added"
                      : "+ Add partner's destination",
                  selected: widget.partnerCommuteEnabled,
                  seekerOptionStyle: true,
                  onTap: () => widget.onPartnerCommuteEnabledChanged(
                    !widget.partnerCommuteEnabled,
                  ),
                ),
                if (widget.partnerCommuteEnabled) ...[
                  const SizedBox(height: OnboardingTokens.space8),
                  CommuteDestinationField(
                    persona: widget.persona,
                    label: '',
                    selectedHub: widget.partnerHub,
                    commuteDestinationUnknown: false,
                    onHubSelected: widget.onPartnerHubSelected,
                    onCleared: widget.onPartnerHubCleared,
                    compactPresets: true,
                    seekerPolishStyle: true,
                  ),
                  const SizedBox(height: OnboardingTokens.space8),
                  OnboardingFieldBlock(
                    label:
                        "Partner's max travel: ${widget.partnerMaxCommuteMinutes} min",
                    child: _travelTimeSlider(
                      context: context,
                      minutes: widget.partnerMaxCommuteMinutes,
                      onChanged: widget.onPartnerCommuteMinutesChanged,
                    ),
                  ),
                  const SizedBox(height: OnboardingTokens.space8),
                  OnboardingFieldBlock(
                    label: 'Commute priority',
                    child: OnboardingEqualChoiceRow(
                      options: _priorityLabels,
                      selectedIndex: _prioritySelectedIndex,
                      onSelected: (index) =>
                          widget.onDualCommutePriorityChanged(
                        switch (index) {
                          0 => DualCommutePriority.personA,
                          1 => DualCommutePriority.personB,
                          _ => DualCommutePriority.balanced,
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // 6. Recommended areas — placeholder only
        _sectionGap(),
        OnboardingFieldBlock(
          label: 'Recommended Areas',
          child: Text(
            'Area recommendations will appear here based on destination, '
            'travel preferences and availability.',
            style: OnboardingTokens.helperTextStyle,
          ),
        ),
        // Future insertion: SeekerPreferredAreasSelector + recommendation engine
      ],
    );
  }
}
