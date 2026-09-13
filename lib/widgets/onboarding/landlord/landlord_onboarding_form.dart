import 'package:flutter/material.dart';

import '../onboarding_design_tokens.dart';
import 'landlord_onboarding_field.dart';
import 'landlord_trust_ecosystem_overview.dart';

/// Shared Living host profile — name + trust primer.
/// Independent Place hosts skip this screen (name collected on Add Listing).
class LandlordOnboardingForm extends StatelessWidget {
  const LandlordOnboardingForm({
    super.key,
    required this.nameController,
    required this.onNameChanged,
  });

  final TextEditingController nameController;
  final VoidCallback onNameChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Set up your Shared Living host profile',
          style: OnboardingTokens.pageTitleStyle,
        ),
        const SizedBox(height: 8),
        const Text(
          'Tell us a little about yourself — you can add listing details later.',
          style: OnboardingTokens.pageSubtitleStyle,
        ),
        const SizedBox(height: 32),
        LandlordOnboardingField(
          controller: nameController,
          label: 'Full name',
          hint: 'As on your ID',
          onChanged: onNameChanged,
        ),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        const LandlordTrustEcosystemOverview(isSharedSpace: true),
      ],
    );
  }
}
