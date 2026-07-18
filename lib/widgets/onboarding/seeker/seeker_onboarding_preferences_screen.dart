import 'package:flutter/material.dart';

import '../../../config/market/market_config.dart';
import '../../../models/seeker_onboarding_enums.dart';
import '../../gamified_form_wizard.dart';
import '../onboarding_design_tokens.dart';
import '../onboarding_field_block.dart';
import '../onboarding_premium_field.dart';

/// Seeker onboarding screen 2 — monthly budget and Dublin presence only.
class SeekerOnboardingPreferencesScreen extends StatelessWidget {
  const SeekerOnboardingPreferencesScreen({
    super.key,
    required this.budgetController,
    required this.isSharedTrack,
    required this.locationContext,
    required this.onLocationContextChanged,
  });

  final TextEditingController budgetController;
  final bool isSharedTrack;
  final DublinLocationContext? locationContext;
  final ValueChanged<DublinLocationContext> onLocationContextChanged;

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

  @override
  Widget build(BuildContext context) {
    final symbol = MarketConfig.current.currencySymbol;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GamifiedFormPageHeader(
          title: 'Preferences',
          subtitle: 'Budget and whether you are already local.',
        ),
        const SizedBox(height: OnboardingTokens.space24),
        OnboardingStepCard(
          title: 'Monthly Budget',
          child: OnboardingPremiumField(
            controller: budgetController,
            label: _budgetFieldLabel(),
            hint: 'e.g. 1800',
            keyboardType: TextInputType.number,
            prefixSymbol: symbol,
            integerOnly: true,
          ),
        ),
        const SizedBox(height: OnboardingTokens.stepCardGap),
        const SizedBox(height: OnboardingTokens.space16),
        OnboardingStepCard(
          title: 'Current Status',
          child: OnboardingStackedChoiceList(
            options: const [
              'Already in Dublin',
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
        const SizedBox(height: OnboardingTokens.space24),
      ],
    );
  }
}
