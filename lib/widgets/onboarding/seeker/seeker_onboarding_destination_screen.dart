import 'package:flutter/material.dart';

import '../../../config/market/dublin_commuter_hubs.dart';
import '../../../config/market/market_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/seeker_onboarding_enums.dart';
import '../../../services/commute_scoring_service.dart';
import '../../commute_destination_field.dart';
import '../../gamified_form_wizard.dart';
import '../../listing_creation/listing_creation_primitives.dart';
import '../onboarding_choice_chip.dart';
import '../onboarding_design_tokens.dart';
import '../onboarding_field_block.dart';
import '../onboarding_premium_field.dart';
import 'seeker_shared_choice_chips.dart';

/// Seeker onboarding screen 3 — Search (Shared) or Destination (IP).
class SeekerOnboardingDestinationScreen extends StatefulWidget {
  const SeekerOnboardingDestinationScreen({
    super.key,
    required this.persona,
    required this.commuteMethod,
    required this.onCommuteMethodChanged,
    required this.selectedHub,
    required this.maxCommuteMinutes,
    required this.onHubSelected,
    required this.onHubCleared,
    required this.onCommuteMinutesChanged,
    required this.partnerCommuteEnabled,
    required this.destinationEnteredIsMine,
    required this.onDestinationEnteredIsMineChanged,
    required this.guarantorStatus,
    required this.onGuarantorChanged,
    this.financialSupportType,
    this.onFinancialSupportChanged,
    this.financialSupportOptions = const [],
    this.destinationFieldResetToken = 0,
    this.isSharedTrack = false,
    this.budgetController,
    this.moveInDate,
    this.onMoveInDateChanged,
    this.transportMode,
    this.onTransportModeChanged,
    this.parkingNeed,
    this.onParkingNeedChanged,
    this.locationContext,
    this.onLocationContextChanged,
  });

  final SeekerPersona? persona;
  final CommuteMethod commuteMethod;
  final ValueChanged<CommuteMethod> onCommuteMethodChanged;
  final DublinCommuterHub? selectedHub;
  final int maxCommuteMinutes;
  final ValueChanged<DublinCommuterHub> onHubSelected;
  final VoidCallback onHubCleared;
  final ValueChanged<int> onCommuteMinutesChanged;

  final bool partnerCommuteEnabled;
  final bool destinationEnteredIsMine;
  final ValueChanged<bool> onDestinationEnteredIsMineChanged;

  final GuarantorStatus? guarantorStatus;
  final ValueChanged<GuarantorStatus> onGuarantorChanged;

  /// Student-only financial support (Phase 4). Null until the seeker selects.
  final String? financialSupportType;
  final ValueChanged<String>? onFinancialSupportChanged;
  final List<String> financialSupportOptions;

  final int destinationFieldResetToken;

  final bool isSharedTrack;
  final TextEditingController? budgetController;
  final DateTime? moveInDate;
  final ValueChanged<DateTime>? onMoveInDateChanged;
  final String? transportMode;
  final ValueChanged<String>? onTransportModeChanged;
  final String? parkingNeed;
  final ValueChanged<String>? onParkingNeedChanged;
  final DublinLocationContext? locationContext;
  final ValueChanged<DublinLocationContext>? onLocationContextChanged;

  @override
  State<SeekerOnboardingDestinationScreen> createState() =>
      _SeekerOnboardingDestinationScreenState();
}

class _SeekerOnboardingDestinationScreenState
    extends State<SeekerOnboardingDestinationScreen> {
  bool get _showGuarantor =>
      widget.persona?.requiresGuarantorQuestion ?? false;

  bool get _showFinancialSupport =>
      _showGuarantor && widget.financialSupportOptions.isNotEmpty;

  int get _guarantorSelectedIndex {
    if (widget.guarantorStatus != null) {
      return GuarantorStatus.values.indexOf(widget.guarantorStatus!);
    }
    return GuarantorStatus.values.indexOf(GuarantorStatus.notSureYet);
  }

  int? get _financialSupportSelectedIndex {
    final selected = widget.financialSupportType;
    if (selected == null) return null;
    final index = widget.financialSupportOptions.indexOf(selected);
    return index >= 0 ? index : null;
  }

  String get _primaryDestinationTitle {
    if (!widget.partnerCommuteEnabled) return 'Primary Destination';
    return widget.destinationEnteredIsMine
        ? 'Primary Destination (My Destination)'
        : "Primary Destination (Partner's Destination)";
  }

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

  Widget _primaryDestinationSection({required bool sharedChrome}) {
    if (sharedChrome) {
      return SeekerSharedSection(
        title: '🗺️ Primary Destination',
        subtitle: 'Where do you need to be most weekdays?',
        child: CommuteDestinationField(
          key: ValueKey('dest-field-${widget.destinationFieldResetToken}'),
          persona: widget.persona,
          selectedHub: widget.selectedHub,
          onHubSelected: widget.onHubSelected,
          onCleared: widget.onHubCleared,
          compactPresets: true,
          seekerPolishStyle: true,
          label: '',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _primaryDestinationTitle,
          style: SeekerOnboardingLayout.sectionLabel,
        ),
        const SizedBox(height: OnboardingTokens.space4),
        Text(
          'Where do you need to be most weekdays?',
          style: SeekerOnboardingLayout.fieldLabel,
        ),
        const SizedBox(height: OnboardingTokens.space8),
        CommuteDestinationField(
          key: ValueKey('dest-field-${widget.destinationFieldResetToken}'),
          persona: widget.persona,
          selectedHub: widget.selectedHub,
          onHubSelected: widget.onHubSelected,
          onCleared: widget.onHubCleared,
          compactPresets: true,
          seekerPolishStyle: true,
          label: '',
        ),
      ],
    );
  }

  Future<void> _pickMoveInDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = widget.moveInDate != null &&
            !widget.moveInDate!.isBefore(today)
        ? widget.moveInDate!
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      widget.onMoveInDateChanged?.call(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSharedTrack) {
      return _buildSharedSearch(context);
    }
    return _buildIndependentPlace(context);
  }

  Widget _buildSharedSearch(BuildContext context) {
    final symbol = MarketConfig.current.currencySymbol;
    final budget = widget.budgetController;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GamifiedFormPageHeader(
          title: 'Search',
          subtitle: 'Budget, timing, destination, and how you travel.',
        ),
        const SizedBox(height: OnboardingTokens.space12),
        if (budget != null)
          SeekerSharedSection(
            title: '💰 Budget',
            child: OnboardingPremiumField(
              controller: budget,
              label: 'Monthly budget (incl. bills)',
              hint: 'e.g. 1800',
              keyboardType: TextInputType.number,
              prefixSymbol: symbol,
              integerOnly: true,
            ),
          ),
        if (budget != null)
          const SizedBox(height: SeekerSharedChipStyle.sectionGap),
        SeekerSharedSection(
          title: '📅 Move-In Date',
          child: ListingDateInputField(
            externalLabel: true,
            value: widget.moveInDate,
            placeholder: 'Move-in date',
            onTap: _pickMoveInDate,
          ),
        ),
        const SizedBox(height: SeekerSharedChipStyle.sectionGap),
        if (widget.partnerCommuteEnabled) ...[
          SeekerSharedSection(
            title: 'Whose destination?',
            child: SeekerSharedChoiceRow<bool>(
              options: const {
                true: 'My Destination',
                false: "Partner's Destination",
              },
              selected: widget.destinationEnteredIsMine,
              onChanged: widget.onDestinationEnteredIsMineChanged,
            ),
          ),
          const SizedBox(height: SeekerSharedChipStyle.sectionGap),
        ],
        _primaryDestinationSection(sharedChrome: true),
        const SizedBox(height: SeekerSharedChipStyle.sectionGap),
        SeekerSharedSection(
          title: '🚌 How will you commute?',
          child: SeekerSharedChoiceGrid<String>(
            options: const {
              'public_transport': '🚌 Public Transport',
              'driving': '🚗 Driving',
              'cycling': '🚲 Cycling',
              'walking': '🚶 Walking',
            },
            selected: widget.transportMode,
            onChanged: (v) => widget.onTransportModeChanged?.call(v),
          ),
        ),
        if (widget.transportMode != null) ...[
          const SizedBox(height: SeekerSharedChipStyle.sectionGap),
          SeekerSharedSection(
            title: '🚗 Parking Need',
            child: SeekerSharedChoiceRow<String>(
              options: const {
                'required': '✅ Required',
                'nice_to_have': '👍 Nice to Have',
                'not_needed': '🚫 Not Needed',
              },
              selected: widget.parkingNeed,
              onChanged: (v) => widget.onParkingNeedChanged?.call(v),
            ),
          ),
        ],
        const SizedBox(height: SeekerSharedChipStyle.sectionGap),
        SeekerSharedSection(
          title: '🌍 Where are you based?',
          child: SeekerSharedChoiceRow<DublinLocationContext>(
            options: const {
              DublinLocationContext.alreadyInDublin: '🏠 Already in Ireland',
              DublinLocationContext.relocating: '✈️ Overseas',
            },
            selected: widget.locationContext ==
                        DublinLocationContext.arrivingSoon
                ? DublinLocationContext.relocating
                : widget.locationContext,
            onChanged: (v) => widget.onLocationContextChanged?.call(v),
          ),
        ),
        if (_showFinancialSupport) ...[
          const SizedBox(height: SeekerSharedChipStyle.sectionGap),
          SeekerSharedSection(
            title: 'Financial Support',
            subtitle: 'How will you fund your rent?',
            child: SeekerSharedChoiceRow<String>(
              options: {
                for (final option in widget.financialSupportOptions)
                  option: option,
              },
              selected: widget.financialSupportType,
              onChanged: (v) => widget.onFinancialSupportChanged?.call(v),
            ),
          ),
        ],
        if (_showGuarantor) ...[
          const SizedBox(height: SeekerSharedChipStyle.sectionGap),
          SeekerSharedSection(
            title: 'Guarantor',
            subtitle: 'Do you have a guarantor?',
            child: SeekerSharedChoiceRow<GuarantorStatus>(
              options: const {
                GuarantorStatus.yes: 'Yes',
                GuarantorStatus.no: 'No',
                GuarantorStatus.notSureYet: 'Not sure yet',
              },
              selected: widget.guarantorStatus ?? GuarantorStatus.notSureYet,
              onChanged: widget.onGuarantorChanged,
            ),
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxHeight.isFinite) return column;
        return SizedBox(
          height: constraints.maxHeight,
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: column,
          ),
        );
      },
    );
  }

  Widget _buildIndependentPlace(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GamifiedFormPageHeader(
              title: 'Destination',
              subtitle:
                  'Where you need to be, how you travel, and how far you will go.',
            ),
            const SizedBox(height: OnboardingTokens.space12),
            if (widget.partnerCommuteEnabled) ...[
              OnboardingFieldBlock(
                label: 'Whose destination are you entering?',
                child: OnboardingEqualChoiceRow(
                  options: const ['My Destination', "My Partner's Destination"],
                  selectedIndex: widget.destinationEnteredIsMine ? 0 : 1,
                  onSelected: (index) =>
                      widget.onDestinationEnteredIsMineChanged(index == 0),
                ),
              ),
              _sectionGap(),
            ],
            _primaryDestinationSection(sharedChrome: false),
            _sectionGap(),
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
            OnboardingFieldBlock(
              label: 'Maximum Travel Time: ${widget.maxCommuteMinutes} min',
              child: _travelTimeSlider(
                context: context,
                minutes: widget.maxCommuteMinutes,
                onChanged: widget.onCommuteMinutesChanged,
              ),
            ),
            if (_showFinancialSupport) ...[
              _sectionGap(),
              OnboardingFieldBlock(
                label: 'Financial Support',
                child: OnboardingEqualGridRow(
                  labels: widget.financialSupportOptions,
                  selectedIndices: {
                    if (_financialSupportSelectedIndex != null)
                      _financialSupportSelectedIndex!,
                  },
                  onSelected: (index) {
                    widget.onFinancialSupportChanged?.call(
                      widget.financialSupportOptions[index],
                    );
                  },
                  compactLabel: true,
                  dense: true,
                ),
              ),
            ],
            if (_showGuarantor) ...[
              _sectionGap(),
              OnboardingFieldBlock(
                label: 'Do you have a guarantor?',
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
          ],
        );

        if (!constraints.maxHeight.isFinite) {
          return column;
        }
        return SizedBox(
          height: constraints.maxHeight,
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: column,
          ),
        );
      },
    );
  }
}
