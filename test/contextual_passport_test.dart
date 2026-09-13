import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/profile_onboarding_models.dart';
import 'package:true_circle/utils/contextual_passport_snapshot.dart';
import 'package:true_circle/widgets/onboarding/contextual_passport_card.dart';

void main() {
  group('ContextualPassportSnapshot', () {
    test('seeker shared omits food chip when food_preference absent', () {
      final snapshot = ContextualPassportSnapshot.fromSession({
        'profile_onboarding_track':
            ProfileOnboardingTrack.seekerSharedSpace.storageToken,
        'full_name': 'Fresh Seeker',
        'budget_max': 900,
        'seeker_persona': 'student',
      });

      expect(
        snapshot.compatibilityChips.where((c) => c.emoji == '🍽️'),
        isEmpty,
      );
    });

    test('seeker shared resolves compatibility chips', () {
      final snapshot = ContextualPassportSnapshot.fromSession({
        'profile_onboarding_track': ProfileOnboardingTrack.seekerSharedSpace.storageToken,
        'full_name': 'Asha Patel',
        'budget_max': 900,
        'food_preference': 'veg',
        'schedule_type': 'Flexible',
        'preferred_spoken_languages': ['English', 'Hindi'],
        'seeker_persona': 'student',
        'earliest_move_in_date': '2026-08-04',
        'dublin_location_context': 'already_in_dublin',
        'guarantor_status': 'not_sure_yet',
      });

      expect(snapshot.track, ProfileOnboardingTrack.seekerSharedSpace);
      expect(snapshot.personaEmoji, '🎓');
      expect(snapshot.compatibilityChips.length, greaterThanOrEqualTo(6));
      expect(
        snapshot.compatibilityChips.any((c) => c.label.contains('Move-in')),
        isTrue,
      );
      expect(
        snapshot.compatibilityChips.any((c) => c.label.contains('900')),
        isTrue,
      );
      expect(
        snapshot.compatibilityChips.any((c) => c.label == 'Guarantor optional'),
        isTrue,
      );
      expect(
        snapshot.compatibilityChips.any((c) => c.label == 'In Dublin'),
        isTrue,
      );
    });

    test('seeker shared adds budget and location chips progressively', () {
      final snapshot = ContextualPassportSnapshot.fromSession({
        'profile_onboarding_track':
            ProfileOnboardingTrack.seekerSharedSpace.storageToken,
        'full_name': 'Liam',
        'budget_max': 1200,
        'spoken_languages': ['English'],
        'dublin_location_context': 'arriving_soon',
      });

      expect(
        snapshot.compatibilityChips.any((c) => c.label == 'Up to €1200'),
        isTrue,
      );
      expect(
        snapshot.compatibilityChips.any((c) => c.label == 'Arriving soon'),
        isTrue,
      );
      expect(
        snapshot.compatibilityChips.any((c) => c.emoji == '🚉'),
        isFalse,
      );
    });

    test('seeker full rental suppresses lifestyle in snapshot', () {
      final snapshot = ContextualPassportSnapshot.fromSession({
        'profile_onboarding_track': ProfileOnboardingTrack.seekerEntirePlace.storageToken,
        'full_name': 'Liam Byrne',
        'employment_verified': true,
        'occupant_type': 'Family',
        'family_adults': 2,
        'family_children': 1,
        'food_preference': 'veg',
        'gender_preference': 'Female',
      });

      expect(snapshot.track, ProfileOnboardingTrack.seekerEntirePlace);
      expect(snapshot.verificationRows.first.label, contains('Employment'));
      expect(snapshot.householdBreakdown, contains('2 adults'));
    });

    test('landlord full rental does not treat host trust fields as verified', () {
      final snapshot = ContextualPassportSnapshot.fromSession({
        'profile_onboarding_track': ProfileOnboardingTrack.landlordEntirePlace.storageToken,
        'full_name': 'Orla Quinn',
        'identity_trust_tier': 'ID_Verified',
        'agency_name': 'Quinn Lets',
        'host_trust_stage': 3,
      });

      expect(snapshot.track, ProfileOnboardingTrack.landlordEntirePlace);
      expect(snapshot.isVerifiedUser, isFalse);
      expect(snapshot.idVerificationLabel, 'Verification not yet complete');
      expect(snapshot.licensingLabel, contains('Agency'));
    });
  });

  group('ContextualPassportCard', () {
    testWidgets('renders seeker shared financial gate', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContextualPassportCard.fromSession({
              'profile_onboarding_track':
                  ProfileOnboardingTrack.seekerSharedSpace.storageToken,
              'full_name': 'Maya Chen',
              'budget_max': 850,
              'seeker_persona': 'student',
            }),
          ),
        ),
      );

      expect(find.text('Financial Gate'), findsOneWidget);
      expect(find.text('Compatibility Grid'), findsOneWidget);
      expect(find.text('Verification Stack'), findsNothing);
    });

    testWidgets('onboarding preview uses rich seeker body for entire place', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContextualPassportCard.fromSession(
              {
                'profile_onboarding_track':
                    ProfileOnboardingTrack.seekerEntirePlace.storageToken,
                'full_name': 'Noah Walsh',
                'budget_max': 2500,
                'commute_destination': 'University College Dublin (UCD)',
                'maximum_commute_budget_minutes': 60,
                'spoken_languages': ['Tamil', 'English', 'Malayalam'],
              },
              useOnboardingSeekerPreview: true,
            ),
          ),
        ),
      );

      expect(find.text('Financial Gate'), findsOneWidget);
      expect(find.text('Operational Gate'), findsOneWidget);
      expect(find.text('Compatibility Grid'), findsOneWidget);
      expect(find.text('Verification Stack'), findsNothing);
      expect(find.textContaining('2,500'), findsOneWidget);
      expect(find.textContaining('UCD'), findsOneWidget);
      expect(find.text('60 min'), findsOneWidget);
      expect(find.text('Tamil'), findsOneWidget);
    });

    testWidgets('renders seeker full rental verification stack only', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContextualPassportCard.fromSession({
              'profile_onboarding_track':
                  ProfileOnboardingTrack.seekerEntirePlace.storageToken,
              'full_name': 'Noah Walsh',
              'verified_university_email': 'noah@tcd.ie',
            }),
          ),
        ),
      );

      expect(find.text('Verification Stack'), findsOneWidget);
      expect(find.text('University Acceptance Verified'), findsOneWidget);
      expect(find.text('Compatibility Grid'), findsNothing);
    });
  });
}
