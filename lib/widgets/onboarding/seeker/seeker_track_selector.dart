import 'package:flutter/material.dart';

import '../onboarding_choice_chip.dart';

/// Side-by-side track cards for independent place vs shared living.
class SeekerTrackSelector extends StatelessWidget {
  const SeekerTrackSelector({
    super.key,
    required this.isSharedTrack,
    required this.onSelectEntirePlace,
    required this.onSelectSharedSpace,
  });

  /// Display labels aligned with feed tab names — storage tokens unchanged.
  static const entirePlaceDisplayLabel = '🏠 Independent Place';
  static const sharedLivingDisplayLabel = '👥 Shared Living';

  final bool isSharedTrack;
  final VoidCallback onSelectEntirePlace;
  final VoidCallback onSelectSharedSpace;

  @override
  Widget build(BuildContext context) {
    return OnboardingEqualChoiceRow(
      options: const [
        entirePlaceDisplayLabel,
        sharedLivingDisplayLabel,
      ],
      selectedIndex: isSharedTrack ? 1 : 0,
      onSelected: (index) {
        if (index == 0) {
          onSelectEntirePlace();
        } else {
          onSelectSharedSpace();
        }
      },
    );
  }
}
