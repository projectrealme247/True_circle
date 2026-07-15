import 'package:flutter/material.dart';

import '../../../models/marketplace_space.dart';
import '../onboarding_choice_chip.dart';

/// Entire place vs shared room — premium emoji prefix cards.
class LandlordInventoryTrackSelector extends StatelessWidget {
  static final entirePlaceLabel = MarketplaceSpace.fullRental.option2Title;
  static const sharedRoomLabel = 'Room in a Shared Flat / House';
  const LandlordInventoryTrackSelector({
    super.key,
    required this.isSharedSpace,
    required this.onSelectEntirePlace,
    required this.onSelectSharedSpace,
  });

  final bool isSharedSpace;
  final VoidCallback onSelectEntirePlace;
  final VoidCallback onSelectSharedSpace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What are you hosting?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 10),
        OnboardingChoiceChip(
          leading: SizedBox(
            width: 24,
            child: Text(
              MarketplaceSpace.fullRental.option2HeroEmoji,
              style: const TextStyle(fontSize: 16, height: 1.1),
              textAlign: TextAlign.center,
            ),
          ),
          label: entirePlaceLabel,
          selected: !isSharedSpace,
          onTap: onSelectEntirePlace,
        ),        const SizedBox(height: 10),
        OnboardingChoiceChip(
          label: '👥 $sharedRoomLabel',
          selected: isSharedSpace,
          onTap: onSelectSharedSpace,
        ),
      ],
    );
  }
}
