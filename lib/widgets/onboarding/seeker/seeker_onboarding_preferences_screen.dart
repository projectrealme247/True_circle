import 'package:flutter/material.dart';



import '../../../config/market/market_config.dart';

import '../../../models/seeker_onboarding_enums.dart';

import '../../gamified_form_wizard.dart';

import '../onboarding_design_tokens.dart';

import '../onboarding_field_block.dart';

import '../onboarding_premium_field.dart';



/// Seeker onboarding screen 2 — budget and Dublin location context.

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



  @override

  Widget build(BuildContext context) {

    final symbol = MarketConfig.current.currencySymbol;

    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        const GamifiedFormPageHeader(

          title: 'Budget and location',

          subtitle: 'This is what hosts see first.',

        ),

        const SizedBox(height: OnboardingTokens.fieldSpacing),

        OnboardingStepCard(

          title: 'Max monthly rent',

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

        OnboardingStepCard(

          title: 'Where are you based right now',

          child: OnboardingStackedChoiceList(

            options: const [

              'Already in Dublin',

              'Arriving in Dublin Soon',

            ],

            selectedIndex: locationContext == null

                ? null

                : DublinLocationContext.values.indexOf(locationContext!),

            onSelected: (index) => onLocationContextChanged(

              DublinLocationContext.values[index],

            ),

          ),

        ),

      ],

    );

  }

}


