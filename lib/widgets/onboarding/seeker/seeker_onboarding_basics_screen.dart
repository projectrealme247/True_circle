import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/profile_state_notifier.dart';
import '../../../utils/profile_data.dart';
import '../onboarding_design_tokens.dart';
import '../onboarding_field_block.dart';
import '../onboarding_premium_field.dart';
import '../../../models/seeker_onboarding_enums.dart';
import '../../../screens/auth_screen.dart';
import 'seeker_onboarding_shell.dart';
import 'seeker_persona_selector.dart';
import 'seeker_shared_choice_chips.dart';
import 'seeker_track_selector.dart';

/// Seeker Step 1 (Basics) — shared shell; IP vs Shared content branches below track.
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
    required this.adultsCount,
    required this.childrenCount,
    required this.onAdultsCountChanged,
    required this.onChildrenCountChanged,
    this.familySharedLivingTip,
    this.lookingWith,
    this.onLookingWithChanged,
    this.groupComposition,
    this.onGroupCompositionChanged,
    this.friendCount,
    this.onFriendCountChanged,
    this.roomArrangement,
    this.onRoomArrangementChanged,
    this.roomPreference,
    this.onRoomPreferenceChanged,
    this.leasePreference,
    this.onLeasePreferenceChanged,
    this.leaseDurationMonths,
    this.onLeaseDurationMonthsChanged,
    this.showSignedInAsCard = false,
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
  final int adultsCount;
  final int childrenCount;
  final ValueChanged<int> onAdultsCountChanged;
  final ValueChanged<int> onChildrenCountChanged;
  final String? familySharedLivingTip;

  final String? lookingWith;
  final ValueChanged<String>? onLookingWithChanged;
  final String? groupComposition;
  final ValueChanged<String>? onGroupCompositionChanged;
  final String? friendCount;
  final ValueChanged<String>? onFriendCountChanged;
  final String? roomArrangement;
  final ValueChanged<String>? onRoomArrangementChanged;
  final String? roomPreference;
  final ValueChanged<String>? onRoomPreferenceChanged;
  final TenurePreference? leasePreference;
  final ValueChanged<TenurePreference>? onLeasePreferenceChanged;
  final int? leaseDurationMonths;
  final ValueChanged<int>? onLeaseDurationMonthsChanged;

  /// When true (matching-ready / edit profile), show the signed-in identity card.
  final bool showSignedInAsCard;

  Map<String, dynamic>? get _session =>
      AuthScreen.currentUserSession ?? profileStateNotifier.session;

  bool get _showSignedInIdentity => AuthService.isSignedIn(_session);

  bool get _showAccountSection =>
      showSignedInAsCard || !_showSignedInIdentity;

  bool get _showFamilySize =>
      !isSharedTrack && persona == SeekerPersona.family;

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
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SeekerOnboardingPageHeader(
          title: "Let's find your place in Dublin",
          subtitle: 'Takes about a minute.',
          compact: true,
        ),
        const SizedBox(height: OnboardingTokens.space8),
        OnboardingStepCard(
          title: 'Your Name',
          seekerTypography: true,
          verticalPadding: OnboardingTokens.space8,
          child: OnboardingPremiumField(
            controller: nameController,
            label: '👤 Full name',
            hint: 'As on your ID',
            seekerTypography: true,
            inputHeight: 48,
          ),
        ),
        const SizedBox(height: OnboardingTokens.space12),
        OnboardingStepCard(
          title: 'What are you looking for?',
          seekerTypography: true,
          verticalPadding: OnboardingTokens.space8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SeekerTrackSelector(
                isSharedTrack: isSharedTrack,
                onSelectEntirePlace: onSelectEntirePlace,
                onSelectSharedSpace: onSelectSharedSpace,
              ),
              if (familySharedLivingTip != null) ...[
                const SizedBox(height: OnboardingTokens.space8),
                Text(
                  familySharedLivingTip!,
                  style: SeekerOnboardingLayout.helperText,
                ),
              ],
            ],
          ),
        ),
        if (isSharedTrack) ..._sharedStep1Sections() else ..._ipStep1Sections(),
        if (_showAccountSection) ...[
          const SizedBox(height: OnboardingTokens.space12),
          OnboardingStepCard(
            title: "You're signed in as",
            seekerTypography: true,
            verticalPadding: OnboardingTokens.space8,
            child: _showSignedInIdentity
                ? _SignedInIdentityDisplay(
                    initials: _initials,
                    name: _displayName,
                    email: _displayEmail,
                  )
                : OnboardingPremiumField(
                    controller: emailController,
                    label: '✉️ Email address',
                    hint: 'you@company.com',
                    keyboardType: TextInputType.emailAddress,
                    validateEmailOnUnfocus: true,
                    seekerTypography: true,
                    inputHeight: 48,
                  ),
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxHeight.isFinite) return content;
        return SizedBox(
          height: constraints.maxHeight,
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: content,
          ),
        );
      },
    );
  }

  List<Widget> _ipStep1Sections() {
    return [
      const SizedBox(height: OnboardingTokens.space12),
      OnboardingStepCard(
        title: 'What best describes you',
        seekerTypography: true,
        verticalPadding: OnboardingTokens.space8,
        child: SeekerPersonaSelector(
          selected: persona,
          onChanged: onPersonaChanged,
          showHeading: false,
          isSharedTrack: false,
        ),
      ),
      if (_showFamilySize) ...[
        const SizedBox(height: OnboardingTokens.space12),
        OnboardingStepCard(
          title: 'How many people are moving?',
          seekerTypography: true,
          verticalPadding: OnboardingTokens.space8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FamilyCountRow(
                label: 'Adults',
                value: adultsCount,
                min: 1,
                max: 10,
                onChanged: onAdultsCountChanged,
              ),
              const SizedBox(height: OnboardingTokens.space8),
              _FamilyCountRow(
                label: 'Children',
                value: childrenCount,
                min: 0,
                max: 8,
                onChanged: onChildrenCountChanged,
              ),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _sharedStep1Sections() {
    return [
      const SizedBox(height: OnboardingTokens.space12),
      OnboardingStepCard(
        title: '🏠 Shared Living Preferences',
        seekerTypography: true,
        verticalPadding: OnboardingTokens.space8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Tell us about yourself and who you're moving with.",
              style: SeekerSharedChipStyle.sectionSubtitleStyle,
            ),
            const SizedBox(height: SeekerSharedChipStyle.sectionGap),
            SeekerSharedSection(
              title: 'What best describes you?',
              child: SeekerPersonaSelector(
                selected: persona,
                onChanged: onPersonaChanged,
                showHeading: false,
                isSharedTrack: true,
              ),
            ),
            const SizedBox(height: SeekerSharedChipStyle.sectionGap),
            SeekerSharedSection(
              title: 'Who are you moving with?',
              child: SeekerSharedChoiceRow<String>(
                options: const {
                  'just_me': '🧍 Just Me',
                  'partner': '❤️ Partner',
                  'friends': '🫂 Friends',
                },
                selected: lookingWith,
                onChanged: (v) => onLookingWithChanged?.call(v),
              ),
            ),
            if (lookingWith == 'just_me') ...[
              const SizedBox(height: SeekerSharedChipStyle.sectionGap),
              SeekerSharedSection(
                title: 'I am',
                child: SeekerSharedChoiceRow<String>(
                  options: const {
                    'male': '♂️ Male',
                    'female': '♀️ Female',
                    'prefer_not': '🔲 Prefer Not To Say',
                  },
                  selected: groupComposition,
                  onChanged: (v) => onGroupCompositionChanged?.call(v),
                ),
              ),
            ],
            if (lookingWith == 'partner') ...[
              const SizedBox(height: SeekerSharedChipStyle.sectionGap),
              SeekerSharedSection(
                title: 'Who is looking?',
                child: SeekerSharedChoiceRow<String>(
                  options: const {
                    'male': '♂️ 2 Male',
                    'female': '♀️ 2 Female',
                    'mixed': '🔀 Mixed Couple',
                  },
                  selected: groupComposition,
                  onChanged: (v) => onGroupCompositionChanged?.call(v),
                ),
              ),
            ],
            if (lookingWith == 'friends') ...[
              const SizedBox(height: SeekerSharedChipStyle.sectionGap),
              _FriendsGroupCard(
                friendCount: friendCount,
                onFriendCountChanged: onFriendCountChanged,
                groupComposition: groupComposition,
                onGroupCompositionChanged: onGroupCompositionChanged,
                roomArrangement: roomArrangement,
                onRoomArrangementChanged: onRoomArrangementChanged,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: OnboardingTokens.space12),
      OnboardingStepCard(
        title: '🛏️ Room Preference',
        seekerTypography: true,
        verticalPadding: OnboardingTokens.space8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Tell us what you're looking for.",
              style: SeekerSharedChipStyle.sectionSubtitleStyle,
            ),
            const SizedBox(height: SeekerSharedChipStyle.sectionGap),
            SeekerSharedSection(
              title: 'Room Preference',
              child: SeekerSharedChoiceRow<String>(
                options: const {
                  'private': '🚪 Private Room',
                  'shared': '🛏️ Shared Room',
                },
                selected: roomPreference,
                onChanged: (v) => onRoomPreferenceChanged?.call(v),
              ),
            ),
            const SizedBox(height: SeekerSharedChipStyle.sectionGap),
            SeekerSharedSection(
              title: 'Lease Preference',
              child: SeekerSharedChoiceRow<TenurePreference>(
                options: const {
                  TenurePreference.longTerm: '📅 Long-Term',
                  TenurePreference.temporary: '⏳ Temporary',
                },
                selected: leasePreference == TenurePreference.flexible
                    ? TenurePreference.longTerm
                    : leasePreference,
                onChanged: (v) => onLeasePreferenceChanged?.call(v),
              ),
            ),
            if (leasePreference == TenurePreference.temporary) ...[
              const SizedBox(height: SeekerSharedChipStyle.sectionGap),
              const SeekerSharedFieldLabel('Duration'),
              const SizedBox(height: SeekerSharedChipStyle.headerToContent),
              SeekerSharedChoiceGrid<int>(
                options: const {
                  1: '1 Month',
                  2: '2 Months',
                  3: '3 Months',
                  6: '6 Months',
                },
                selected: leaseDurationMonths,
                onChanged: (v) => onLeaseDurationMonthsChanged?.call(v),
              ),
            ],
          ],
        ),
      ),
    ];
  }
}

/// Groups friends-related Shared Living questions into one sub-card.
class _FriendsGroupCard extends StatelessWidget {
  const _FriendsGroupCard({
    required this.friendCount,
    required this.onFriendCountChanged,
    required this.groupComposition,
    required this.onGroupCompositionChanged,
    required this.roomArrangement,
    required this.onRoomArrangementChanged,
  });

  final String? friendCount;
  final ValueChanged<String>? onFriendCountChanged;
  final String? groupComposition;
  final ValueChanged<String>? onGroupCompositionChanged;
  final String? roomArrangement;
  final ValueChanged<String>? onRoomArrangementChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SeekerSharedSection(
            title: 'How many friends?',
            child: SeekerSharedChoiceRow<String>(
              options: const {
                'one': '👤 1 Friend',
                'two_plus': '👥 2+ Friends',
              },
              selected: friendCount,
              onChanged: (v) => onFriendCountChanged?.call(v),
            ),
          ),
          const SizedBox(height: SeekerSharedChipStyle.groupInnerGap),
          SeekerSharedSection(
            title: 'Group composition',
            child: SeekerSharedChoiceRow<String>(
              options: const {
                'male': '♂️ Male',
                'female': '♀️ Female',
                'mixed': '🔀 Mixed',
              },
              selected: groupComposition,
              onChanged: (v) => onGroupCompositionChanged?.call(v),
            ),
          ),
          if (friendCount == 'two_plus') ...[
            const SizedBox(height: SeekerSharedChipStyle.groupInnerGap),
            SeekerSharedSection(
              title: 'Room arrangement',
              child: SeekerSharedChoiceRow<String>(
                options: const {
                  'separate': '🚪 Need Separate Rooms',
                  'sharing': '🤝 Open To Sharing',
                },
                selected: roomArrangement,
                onChanged: (v) => onRoomArrangementChanged?.call(v),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FamilyCountRow extends StatelessWidget {
  const _FamilyCountRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SeekerOnboardingLayout.optionRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: OnboardingTokens.space12),
      decoration: BoxDecoration(
        color: OnboardingTokens.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OnboardingTokens.inputBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: SeekerOnboardingLayout.optionCardText),
          ),
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 18),
            onPressed: value > min ? () => onChanged(value - 1) : null,
            color: AppColors.accent,
            disabledColor: const Color(0xFFCBD5E1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: SeekerOnboardingLayout.optionCardText.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 18),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            color: AppColors.accent,
            disabledColor: const Color(0xFFCBD5E1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
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
          radius: 20,
          backgroundColor: AppColors.accentLight,
          child: Text(
            initials,
            style: SeekerOnboardingLayout.optionCardText.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: OnboardingTokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isNotEmpty ? name : 'Signed-in seeker',
                style: SeekerOnboardingLayout.optionCardText.copyWith(
                  color: AppColors.primaryText,
                ),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: OnboardingTokens.space4),
                Text(email, style: SeekerOnboardingLayout.helperText),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
