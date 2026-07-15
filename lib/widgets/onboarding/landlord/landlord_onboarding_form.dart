import 'package:flutter/material.dart';

import '../onboarding_design_tokens.dart';
import '../onboarding_field_block.dart';
import 'landlord_inventory_track_selector.dart';
import 'landlord_onboarding_field.dart';
import 'landlord_trust_ecosystem_overview.dart';

/// Streamlined landlord form — hosting track, full name, trust ecosystem primer.
class LandlordOnboardingForm extends StatelessWidget {
  const LandlordOnboardingForm({
    super.key,
    required this.nameController,
    required this.isSharedSpace,
    required this.onSelectEntirePlace,
    required this.onSelectSharedSpace,
    required this.onNameChanged,
  });

  final TextEditingController nameController;
  final bool isSharedSpace;
  final VoidCallback onSelectEntirePlace;
  final VoidCallback onSelectSharedSpace;
  final VoidCallback onNameChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Set up your host profile',
          style: OnboardingTokens.pageTitleStyle,
        ),
        const SizedBox(height: 8),
        const Text(
          'Tell us a little about yourself — you can add listing details later.',
          style: OnboardingTokens.pageSubtitleStyle,
        ),
        const SizedBox(height: 32),
        OnboardingFieldBlock(
          child: LandlordInventoryTrackSelector(
            isSharedSpace: isSharedSpace,
            onSelectEntirePlace: onSelectEntirePlace,
            onSelectSharedSpace: onSelectSharedSpace,
          ),
        ),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        LandlordOnboardingField(
          controller: nameController,
          label: 'Full name',
          hint: 'As on your ID',
          onChanged: onNameChanged,
        ),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        LandlordTrustEcosystemOverview(isSharedSpace: isSharedSpace),
      ],
    );
  }
}
