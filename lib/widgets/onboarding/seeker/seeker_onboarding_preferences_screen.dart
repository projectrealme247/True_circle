import 'package:flutter/material.dart';

import '../../../config/market/market_config.dart';
import '../../../models/move_in_timing.dart';
import '../../../models/seeker_onboarding_enums.dart';
import '../../gamified_form_wizard.dart';
import '../onboarding_choice_chip.dart';
import '../onboarding_design_tokens.dart';
import '../onboarding_field_block.dart';
import '../onboarding_move_in_window_field.dart';
import '../onboarding_premium_field.dart';
import 'seeker_language_selection_section.dart';
import 'seeker_shared_choice_chips.dart';

/// Seeker onboarding screen 2 — Profile (Shared) or Rental Plan (IP).
class SeekerOnboardingPreferencesScreen extends StatelessWidget {
  const SeekerOnboardingPreferencesScreen({
    super.key,
    required this.budgetController,
    required this.isSharedTrack,
    required this.locationContext,
    required this.onLocationContextChanged,
    required this.moveInWindow,
    required this.onMoveInWindowChanged,
    required this.partnerCommuteEnabled,
    required this.onPartnerCommuteEnabledChanged,
    this.tenurePreference,
    this.onTenurePreferenceChanged,
    this.furnishingPreference,
    this.onFurnishingPreferenceChanged,
    this.propertyTypePreference,
    this.onPropertyTypePreferenceChanged,
    this.bathroomPreference,
    this.onBathroomPreferenceChanged,
    this.primaryLanguage = '',
    this.onPrimaryLanguageChanged,
    this.suggestedLanguages = const [],
    this.selectedSecondaryLanguages = const {},
    this.onToggleSecondaryLanguage,
    this.onAddSecondaryLanguage,
    this.smokingStatus,
    this.onSmokingStatusChanged,
    this.petType,
    this.onPetTypeChanged,
  });

  final TextEditingController budgetController;
  final bool isSharedTrack;
  final DublinLocationContext? locationContext;
  final ValueChanged<DublinLocationContext> onLocationContextChanged;
  final SeekerMoveInWindow? moveInWindow;
  final ValueChanged<SeekerMoveInWindow> onMoveInWindowChanged;
  final bool partnerCommuteEnabled;
  final ValueChanged<bool> onPartnerCommuteEnabledChanged;
  final TenurePreference? tenurePreference;
  final ValueChanged<TenurePreference>? onTenurePreferenceChanged;
  final FurnishingPreference? furnishingPreference;
  final ValueChanged<FurnishingPreference>? onFurnishingPreferenceChanged;
  final PropertyTypePreference? propertyTypePreference;
  final ValueChanged<PropertyTypePreference>? onPropertyTypePreferenceChanged;
  final BathroomPreference? bathroomPreference;
  final ValueChanged<BathroomPreference>? onBathroomPreferenceChanged;

  /// Shared Spaces profile step.
  final String primaryLanguage;
  final ValueChanged<String>? onPrimaryLanguageChanged;
  final List<String> suggestedLanguages;
  final Set<String> selectedSecondaryLanguages;
  final ValueChanged<String>? onToggleSecondaryLanguage;
  final ValueChanged<String>? onAddSecondaryLanguage;
  final String? smokingStatus;
  final ValueChanged<String>? onSmokingStatusChanged;
  final String? petType;
  final ValueChanged<String>? onPetTypeChanged;

  String _budgetFieldLabel() {
    if (isSharedTrack) {
      return 'Including bills';
    }
    return 'Monthly maximum';
  }

  int? get _locationSelectedIndex => switch (locationContext) {
        DublinLocationContext.alreadyInDublin => 0,
        DublinLocationContext.arrivingSoon ||
        DublinLocationContext.relocating =>
          1,
        null => null,
      };

  int? get _tenureSelectedIndex => switch (tenurePreference) {
        TenurePreference.temporary => 0,
        TenurePreference.longTerm => 1,
        TenurePreference.flexible => 1,
        null => null,
      };

  int? get _furnishingSelectedIndex => switch (furnishingPreference) {
        FurnishingPreference.furnished => 0,
        FurnishingPreference.partFurnished => 1,
        FurnishingPreference.noPreference => 2,
        null => null,
      };

  int? get _propertyTypeSelectedIndex => switch (propertyTypePreference) {
        PropertyTypePreference.house => 0,
        PropertyTypePreference.apartment => 1,
        PropertyTypePreference.noPreference => 2,
        null => null,
      };

  int? get _bathroomSelectedIndex => switch (bathroomPreference) {
        BathroomPreference.privateBathroom => 0,
        BathroomPreference.sharedBathroom => 1,
        BathroomPreference.noPreference => 2,
        null => null,
      };

  @override
  Widget build(BuildContext context) {
    if (isSharedTrack) {
      return _buildSharedProfile(context);
    }
    return _buildIndependentPlace(context);
  }

  Widget _buildSharedProfile(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GamifiedFormPageHeader(
          title: 'Profile',
          subtitle: 'Languages and household lifestyle signals.',
        ),
        const SizedBox(height: OnboardingTokens.space16),
        SeekerSharedSection(
          title: '🗣️ Languages',
          subtitle: 'English is assumed — add your other languages.',
          child: SeekerLanguageSelectionSection(
            key: ValueKey(
              'seeker-lang-$primaryLanguage-${suggestedLanguages.join('|')}-'
              '${selectedSecondaryLanguages.join('|')}',
            ),
            primaryLanguage: primaryLanguage,
            onPrimaryLanguageChanged: onPrimaryLanguageChanged ?? (_) {},
            suggestedLanguages: List<String>.from(suggestedLanguages),
            selectedSecondaryLanguages: selectedSecondaryLanguages,
            onToggleSecondaryLanguage: onToggleSecondaryLanguage ?? (_) {},
            onAddSecondaryLanguage: onAddSecondaryLanguage ?? (_) {},
          ),
        ),
        const SizedBox(height: SeekerSharedChipStyle.sectionGap),
        SeekerSharedSection(
          title: '🚭 Smoking',
          child: SeekerSharedChoiceRow<String>(
            options: const {
              'non_smoker': '🚫 Non-Smoker',
              'vaper': '🌿 Vaper',
              'smoker': '🚬 Smoker',
            },
            selected: smokingStatus,
            onChanged: (v) => onSmokingStatusChanged?.call(v),
          ),
        ),
        const SizedBox(height: SeekerSharedChipStyle.sectionGap),
        SeekerSharedSection(
          title: '🐾 Pets',
          child: SeekerSharedChoiceGrid<String>(
            options: const {
              'none': '🐾 No Pet',
              'dog': '🐕 Dog',
              'cat': '🐈 Cat',
              'other': '🐾 Other',
            },
            selected: petType,
            onChanged: (v) => onPetTypeChanged?.call(v),
          ),
        ),
        const SizedBox(height: SeekerSharedChipStyle.sectionGap),
        SeekerSharedSection(
          title: '🛁 Bathroom Preference',
          subtitle: 'What bathroom arrangement do you prefer?',
          child: SeekerSharedChoiceGrid<BathroomPreference>(
            columns: 1,
            options: {
              for (final value in BathroomPreference.values)
                value: value.chipLabel,
            },
            selected: bathroomPreference,
            onChanged: (v) => onBathroomPreferenceChanged?.call(v),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite || !constraints.maxHeight.isFinite) {
          return content;
        }
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildIndependentPlace(BuildContext context) {
    final symbol = MarketConfig.current.currencySymbol;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GamifiedFormPageHeader(
          title: 'Rental Plan',
          subtitle: 'Budget, timing, and home preferences.',
        ),
        const SizedBox(height: OnboardingTokens.space16),
        OnboardingStepCard(
          title: 'Monthly Budget',
          seekerTypography: true,
          verticalPadding: OnboardingTokens.space8,
          child: OnboardingPremiumField(
            controller: budgetController,
            label: _budgetFieldLabel(),
            hint: 'e.g. 1800',
            keyboardType: TextInputType.number,
            prefixSymbol: symbol,
            integerOnly: true,
          ),
        ),
        const SizedBox(height: OnboardingTokens.space12),
        OnboardingStepCard(
          title: 'Residential Status',
          seekerTypography: true,
          verticalPadding: OnboardingTokens.space8,
          child: OnboardingStackedChoiceList(
            options: const [
              'Already Living in Dublin',
              'Moving to Dublin',
            ],
            selectedIndex: _locationSelectedIndex,
            onSelected: (index) => onLocationContextChanged(
              index == 0
                  ? DublinLocationContext.alreadyInDublin
                  : DublinLocationContext.arrivingSoon,
            ),
          ),
        ),
        const SizedBox(height: OnboardingTokens.space12),
        OnboardingStepCard(
          title: 'Move-In Timeline',
          seekerTypography: true,
          verticalPadding: OnboardingTokens.space8,
          child: OnboardingMoveInWindowField(
            selected: moveInWindow,
            onChanged: onMoveInWindowChanged,
          ),
        ),
        const SizedBox(height: OnboardingTokens.space12),
        OnboardingStepCard(
          title: 'Tenure Preference',
          seekerTypography: true,
          verticalPadding: OnboardingTokens.space8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How long do you plan to stay?',
                style: SeekerOnboardingLayout.helperText,
              ),
              const SizedBox(height: OnboardingTokens.space8),
              OnboardingEqualChoiceRow(
                options: TenurePreference.independentPlaceValues
                    .map((e) => e.label)
                    .toList(),
                selectedIndex: _tenureSelectedIndex,
                onSelected: (index) => onTenurePreferenceChanged?.call(
                  TenurePreference.independentPlaceValues[index],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: OnboardingTokens.space12),
        OnboardingStepCard(
          title: 'Furnishing Preference',
          seekerTypography: true,
          verticalPadding: OnboardingTokens.space8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How furnished would you like the property to be?',
                style: SeekerOnboardingLayout.helperText,
              ),
              const SizedBox(height: OnboardingTokens.space8),
              OnboardingEqualChoiceRow(
                options:
                    FurnishingPreference.values.map((e) => e.label).toList(),
                selectedIndex: _furnishingSelectedIndex,
                onSelected: (index) => onFurnishingPreferenceChanged
                    ?.call(FurnishingPreference.values[index]),
              ),
            ],
          ),
        ),
        const SizedBox(height: OnboardingTokens.space12),
        OnboardingStepCard(
          title: 'Property Type Preference',
          seekerTypography: true,
          verticalPadding: OnboardingTokens.space8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What type of property do you prefer?',
                style: SeekerOnboardingLayout.helperText,
              ),
              const SizedBox(height: OnboardingTokens.space8),
              OnboardingEqualChoiceRow(
                options: PropertyTypePreference.values
                    .map((e) => e.label)
                    .toList(),
                selectedIndex: _propertyTypeSelectedIndex,
                onSelected: (index) => onPropertyTypePreferenceChanged
                    ?.call(PropertyTypePreference.values[index]),
              ),
            ],
          ),
        ),
        const SizedBox(height: OnboardingTokens.space12),
        OnboardingStepCard(
          title: 'Bathroom Preference',
          seekerTypography: true,
          verticalPadding: OnboardingTokens.space8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What bathroom arrangement do you prefer?',
                style: SeekerOnboardingLayout.helperText,
              ),
              const SizedBox(height: OnboardingTokens.space8),
              OnboardingEqualChoiceRow(
                options: BathroomPreference.values
                    .map((e) => e.chipLabel)
                    .toList(),
                selectedIndex: _bathroomSelectedIndex,
                onSelected: (index) => onBathroomPreferenceChanged
                    ?.call(BathroomPreference.values[index]),
              ),
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite || !constraints.maxHeight.isFinite) {
          return content;
        }
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: content,
          ),
        );
      },
    );
  }
}
