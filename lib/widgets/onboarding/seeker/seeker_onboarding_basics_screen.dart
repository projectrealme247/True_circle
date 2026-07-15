import 'package:flutter/material.dart';



import '../../../core/theme/app_theme.dart';

import '../../../services/auth_service.dart';

import '../../../services/profile_state_notifier.dart';

import '../../../utils/profile_data.dart';

import '../../gamified_form_wizard.dart';

import '../onboarding_design_tokens.dart';

import '../onboarding_field_block.dart';

import '../onboarding_premium_field.dart';

import '../../../models/seeker_onboarding_enums.dart';

import '../../../screens/auth_screen.dart';

import 'seeker_language_selection_section.dart';

import 'seeker_persona_selector.dart';

import 'seeker_track_selector.dart';



/// Seeker onboarding screen 1 — track, persona, language, signed-in identity.

class SeekerOnboardingBasicsScreen extends StatelessWidget {

  const SeekerOnboardingBasicsScreen({

    super.key,

    required this.emailController,

    required this.nameController,

    required this.isSharedTrack,

    required this.onSelectEntirePlace,

    required this.onSelectSharedSpace,

    required this.persona,

    required this.onPersonaChanged,

    required this.primaryLanguage,

    required this.onPrimaryLanguageChanged,

    required this.suggestedLanguages,

    required this.selectedSecondaryLanguages,

    required this.onToggleSecondaryLanguage,

    required this.onAddSecondaryLanguage,

    this.familySharedLivingTip,

  });



  final TextEditingController emailController;

  final TextEditingController nameController;

  final bool isSharedTrack;

  final VoidCallback onSelectEntirePlace;

  final VoidCallback onSelectSharedSpace;

  final SeekerPersona? persona;

  final ValueChanged<SeekerPersona> onPersonaChanged;

  final String primaryLanguage;

  final ValueChanged<String> onPrimaryLanguageChanged;

  final List<String> suggestedLanguages;

  final Set<String> selectedSecondaryLanguages;

  final ValueChanged<String> onToggleSecondaryLanguage;

  final ValueChanged<String> onAddSecondaryLanguage;

  final String? familySharedLivingTip;



  Map<String, dynamic>? get _session =>

      AuthScreen.currentUserSession ?? profileStateNotifier.session;



  bool get _showSignedInIdentity => AuthService.isSignedIn(_session);



  String get _displayName {

    final fromField = nameController.text.trim();

    if (fromField.isNotEmpty) return fromField;

    return ProfileData.text(_session?['full_name']);

  }



  String get _displayEmail {

    final fromField = emailController.text.trim();

    if (fromField.isNotEmpty) return fromField;

    return ProfileData.text(_session?['email']);

  }



  String get _initials {

    final name = _displayName.trim();

    if (name.isEmpty) {

      final email = _displayEmail.trim();

      if (email.isNotEmpty) return email.substring(0, 1).toUpperCase();

      return '?';

    }

    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

    if (parts.length >= 2) {

      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();

    }

    return parts.first[0].toUpperCase();

  }



  @override

  Widget build(BuildContext context) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        const GamifiedFormPageHeader(

          title: "Let's find your place in Dublin",

          subtitle: 'Takes about a minute.',

        ),

        const SizedBox(height: OnboardingTokens.fieldSpacing),

        OnboardingStepCard(

          title: 'What are you looking for',

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              SeekerTrackSelector(

                isSharedTrack: isSharedTrack,

                onSelectEntirePlace: onSelectEntirePlace,

                onSelectSharedSpace: onSelectSharedSpace,

              ),

              if (familySharedLivingTip != null) ...[

                const SizedBox(height: 10),

                Text(

                  familySharedLivingTip!,

                  style: const TextStyle(

                    fontSize: 12,

                    height: 1.4,

                    color: AppColors.secondaryText,

                  ),

                ),

              ],

            ],

          ),

        ),

        const SizedBox(height: OnboardingTokens.stepCardGap),

        OnboardingStepCard(

          title: 'What best describes you',

          child: SeekerPersonaSelector(

            selected: persona,

            onChanged: onPersonaChanged,

            showHeading: false,

          ),

        ),

        const SizedBox(height: OnboardingTokens.stepCardGap),

        OnboardingStepCard(

          title: 'Language',

          child: SeekerLanguageSelectionSection(

            key: ValueKey(

              'seeker-lang-$primaryLanguage-${suggestedLanguages.join('|')}-'

              '${selectedSecondaryLanguages.join('|')}',

            ),

            primaryLanguage: primaryLanguage,

            onPrimaryLanguageChanged: onPrimaryLanguageChanged,

            suggestedLanguages: List<String>.from(suggestedLanguages),

            selectedSecondaryLanguages: selectedSecondaryLanguages,

            onToggleSecondaryLanguage: onToggleSecondaryLanguage,

            onAddSecondaryLanguage: onAddSecondaryLanguage,

          ),

        ),

        const SizedBox(height: OnboardingTokens.stepCardGap),

        OnboardingStepCard(

          title: "You're signed in as",

          child: _showSignedInIdentity

              ? _SignedInIdentityDisplay(

                  initials: _initials,

                  name: _displayName,

                  email: _displayEmail,

                )

              : Column(

                  crossAxisAlignment: CrossAxisAlignment.stretch,

                  children: [

                    OnboardingPremiumField(

                      controller: emailController,

                      label: '✉️ Email address',

                      hint: 'you@company.com',

                      keyboardType: TextInputType.emailAddress,

                      validateEmailOnUnfocus: true,

                    ),

                    const SizedBox(height: OnboardingTokens.fieldSpacing),

                    OnboardingPremiumField(

                      controller: nameController,

                      label: '👤 Full name',

                      hint: 'As on your ID',

                    ),

                  ],

                ),

        ),

      ],

    );

  }

}



class _SignedInIdentityDisplay extends StatelessWidget {

  const _SignedInIdentityDisplay({

    required this.initials,

    required this.name,

    required this.email,

  });



  final String initials;

  final String name;

  final String email;



  @override

  Widget build(BuildContext context) {

    return Row(

      children: [

        CircleAvatar(

          radius: 26,

          backgroundColor: AppColors.accentLight,

          child: Text(

            initials,

            style: const TextStyle(

              fontSize: 16,

              fontWeight: FontWeight.w700,

              color: AppColors.accent,

            ),

          ),

        ),

        const SizedBox(width: 14),

        Expanded(

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text(

                name.isNotEmpty ? name : 'Signed-in seeker',

                style: const TextStyle(

                  fontSize: 16,

                  fontWeight: FontWeight.w600,

                  color: AppColors.primaryText,

                ),

              ),

              if (email.isNotEmpty) ...[

                const SizedBox(height: 4),

                Text(

                  email,

                  style: const TextStyle(

                    fontSize: 13,

                    color: AppColors.secondaryText,

                  ),

                ),

              ],

            ],

          ),

        ),

      ],

    );

  }

}


