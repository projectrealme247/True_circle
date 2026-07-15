import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/onboarding_user_intent.dart';
import '../widgets/onboarding/onboarding_content_shell.dart';
import '../widgets/onboarding/onboarding_design_tokens.dart';
import '../widgets/onboarding/onboarding_gateway_track_option.dart';
import '../widgets/truecircle_logo.dart';

/// Pure routing gate — no profile fields, only seeker vs landlord choice.
class WelcomeGateScreen extends StatelessWidget {
  const WelcomeGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingTokens.canvasBg,
      appBar: AppBar(
        backgroundColor: OnboardingTokens.canvasBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: const Align(
          alignment: Alignment.centerLeft,
          child: TrueCircleHomeLogoButton(markSize: 26),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: OnboardingTokens.inputBorder,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OnboardingTokens.contentPaddingH,
            vertical: 32,
          ),
          child: OnboardingContentShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Welcome to True Circle',
                  style: OnboardingTokens.pageTitleStyle,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set up your profile in under a minute — you can refine '
                  'details anytime.',
                  style: OnboardingTokens.pageSubtitleStyle,
                ),
                const SizedBox(height: 32),
                Text(
                  'What brings you to True Circle?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                OnboardingGatewayTrackOption(
                  label: OnboardingUserIntent.seeker.segmentLabel,
                  prefixEmoji: '🔍',
                  premium: true,
                  selected: false,
                  onTap: () => context.push('/profile/edit'),
                ),
                const SizedBox(height: 12),
                OnboardingGatewayTrackOption(
                  label: OnboardingUserIntent.provider.segmentLabel,
                  prefixEmoji: '🏠',
                  premium: true,
                  selected: false,
                  onTap: () => context.push('/profile/edit/host'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
