import 'package:flutter/material.dart';

import '../../models/profile_onboarding_models.dart';
import 'contextual_passport_card.dart';

/// Live passport preview — delegates to the 4-track contextual passport card.
@Deprecated('Use ContextualPassportCard.fromSession instead.')
class PassportPreviewCard extends StatelessWidget {
  const PassportPreviewCard({
    super.key,
    required this.displayName,
    required this.location,
    required this.languages,
    this.isProvider = false,
    this.identityTrustLabel = 'Pending verification',
    this.hostTrustTierLabel = 'Host Trust Badge — Tier 0',
    this.session,
    this.track,
    this.listingBudgetRequirement,
  });

  final String displayName;
  final String location;
  final List<String> languages;
  final bool isProvider;
  final String identityTrustLabel;
  final String hostTrustTierLabel;
  final Map<String, dynamic>? session;
  final ProfileOnboardingTrack? track;
  final int? listingBudgetRequirement;

  @override
  Widget build(BuildContext context) {
    final merged = <String, dynamic>{
      if (session != null) ...session!,
      'full_name': displayName,
      if (location.trim().isNotEmpty) 'detected_city': location.trim(),
      if (languages.isNotEmpty) 'spoken_languages': languages,
      if (isProvider) 'onboarding_intent': 'provider',
      if (track != null) 'profile_onboarding_track': track!.storageToken,
    };

    return ContextualPassportCard.fromSession(
      merged,
      listingBudgetRequirement: listingBudgetRequirement,
    );
  }
}
