import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/profile_onboarding_models.dart';
import '../../utils/contextual_passport_snapshot.dart';
import '../../theme/app_scroll_behavior.dart';
import '../emoji_leading_row.dart';
import '../profile_completeness_indicator.dart';
import '../trust_badge.dart';
import 'onboarding_design_tokens.dart';

/// Dynamic 4-track contextual passport — identity header + track-specific body.
class ContextualPassportCard extends StatelessWidget {
  const ContextualPassportCard({
    super.key,
    required this.snapshot,
    this.headerCaption = 'Your Public Passport',
    this.showHeaderCaption = true,
    this.omitOuterFrame = false,
    this.useOnboardingSeekerPreview = false,
    this.flatOnboardingStyle = false,
  });

  factory ContextualPassportCard.fromSession(
    Map<String, dynamic> session, {
    int? listingBudgetRequirement,
    String headerCaption = 'Your Public Passport',
    bool showHeaderCaption = true,
    bool useOnboardingSeekerPreview = false,
    bool flatOnboardingStyle = false,
  }) {
    return ContextualPassportCard(
      snapshot: ContextualPassportSnapshot.fromSession(
        session,
        listingBudgetRequirement: listingBudgetRequirement,
      ),
      headerCaption: headerCaption,
      showHeaderCaption: showHeaderCaption,
      useOnboardingSeekerPreview: useOnboardingSeekerPreview,
      flatOnboardingStyle: flatOnboardingStyle,
    );
  }

  final ContextualPassportSnapshot snapshot;
  final String headerCaption;
  final bool showHeaderCaption;
  final bool omitOuterFrame;
  /// During seeker onboarding, show Financial / Operational / Compatibility sections
  /// for both Independent Place and Shared Living tracks.
  final bool useOnboardingSeekerPreview;
  /// Pass-1 flat passport: no inner cards, dividers, muted uppercase headers.
  final bool flatOnboardingStyle;

  static const _titleColor = Color(0xFF0F172A);
  static const _subtitleColor = Color(0xFF64748B);
  static const _placeholder = Color(0xFFCBD5E1);
  static const _cardFill = Color(0xFFF8FAFC);
  static const _cardBorder = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fillHeight = flatOnboardingStyle &&
            constraints.hasBoundedHeight &&
            constraints.maxHeight.isFinite;

        final body = flatOnboardingStyle
            ? _buildFlatBody(fillHeight: fillHeight)
            : ScrollConfiguration(
                behavior: const OnboardingFormScrollBehavior(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  primary: false,
                  physics: appPageScrollPhysics,
                  child: _buildDefaultBody(),
                ),
              );

        if (omitOuterFrame || flatOnboardingStyle) {
          return SizedBox(
            width: double.infinity,
            height: fillHeight ? constraints.maxHeight : null,
            child: body,
          );
        }

        return SizedBox(
          width: OnboardingTokens.passportWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OnboardingTokens.inputBorder),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: body,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeaderCaption) ...[
              Text(
                headerCaption,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _subtitleColor,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 14),
            ],
            _PassportIdentityHeader(snapshot: snapshot),
          ],
        ),
        if (!omitOuterFrame) ...[
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.withValues(alpha: 0.1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: _PassportTrackBody(
              snapshot: snapshot,
              useOnboardingSeekerPreview: useOnboardingSeekerPreview,
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          _PassportTrackBody(
            snapshot: snapshot,
            useOnboardingSeekerPreview: useOnboardingSeekerPreview,
          ),
        ],
      ],
    );
  }

  Widget _buildFlatBody({required bool fillHeight}) {
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeaderCaption) ...[
          Text(
            headerCaption.toUpperCase(),
            style: SeekerOnboardingLayout.passportSectionHeader,
          ),
          const SizedBox(height: SeekerOnboardingLayout.passportRelatedGap),
          Text(
            'This is what hosts see when you apply.',
            style: SeekerOnboardingLayout.helperText,
          ),
          const SizedBox(height: SeekerOnboardingLayout.passportRelatedGap),
          ProfileCompletenessIndicator(
            percent: snapshot.profileCompletionPercent,
            levelLabel: snapshot.profileCompletenessLevel,
          ),
          const SizedBox(height: SeekerOnboardingLayout.passportSectionGap),
        ],
        _PassportIdentityHeader(
          snapshot: snapshot,
          flatStyle: true,
        ),
      ],
    );

    final body = _PublicPassportBody(
      snapshot: snapshot,
      fillHeight: fillHeight,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: SeekerOnboardingLayout.passportSectionGap),
        if (fillHeight) Expanded(child: body) else body,
      ],
    );
  }
}

class _PassportIdentityHeader extends StatelessWidget {
  const _PassportIdentityHeader({
    required this.snapshot,
    this.flatStyle = false,
  });

  final ContextualPassportSnapshot snapshot;
  final bool flatStyle;

  @override
  Widget build(BuildContext context) {
    final name = snapshot.displayName.trim();

    if (flatStyle) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: SeekerOnboardingLayout.avatarFill,
            child: Text(
              _initials(name),
              style: SeekerOnboardingLayout.optionCardText.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: name.isEmpty
                    ? ContextualPassportCard._placeholder
                    : SeekerOnboardingLayout.muted,
              ),
            ),
          ),
          const SizedBox(width: OnboardingTokens.space12),
          Expanded(
            child: Text(
              name.isEmpty ? 'Your name' : name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SeekerOnboardingLayout.passportIdentityName.copyWith(
                color: name.isEmpty
                    ? ContextualPassportCard._placeholder
                    : SeekerOnboardingLayout.ink,
              ),
            ),
          ),
        ],
      );
    }

    final nameStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: name.isEmpty
          ? ContextualPassportCard._placeholder
          : ContextualPassportCard._titleColor,
      height: 1.15,
      letterSpacing: -0.4,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFE2E8F0),
              child: Text(
                _initials(name),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: name.isEmpty
                      ? ContextualPassportCard._placeholder
                      : const Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TrustBadge(
              tier: snapshot.trustTier,
              compact: true,
              showTooltip: false,
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                child: Text(
                  name.isEmpty ? 'Your name' : name,
                  key: ValueKey(name.isEmpty ? 'name-empty' : name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: nameStyle,
                ),
              ),
              const SizedBox(height: 8),
              EmojiLeadingRow(
                emoji: snapshot.personaEmoji,
                text: snapshot.personaLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ContextualPassportCard._titleColor,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0].toUpperCase()).take(2).join();
    return letters.isEmpty ? '?' : letters;
  }
}

/// Host-facing public passport hierarchy for seeker onboarding preview.
class _PublicPassportBody extends StatelessWidget {
  const _PublicPassportBody({
    required this.snapshot,
    this.fillHeight = false,
  });

  final ContextualPassportSnapshot snapshot;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final budgetValue = snapshot.budgetMax != null
        ? '${NumberFormat.currency(symbol: '€', decimalDigits: 0).format(snapshot.budgetMax!)}/mo'
        : '';
    final travelValue = snapshot.maxCommuteMinutes != null &&
            snapshot.maxCommuteMinutes! > 0
        ? '${snapshot.maxCommuteMinutes} min'
        : '';
    final personaValue = [
      snapshot.personaEmoji,
      snapshot.personaLabel,
    ].where((part) => part.trim().isNotEmpty).join(' ').trim();

    final languageChips = snapshot.languagesLabel
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    final whoTraits = <String>[
      if (personaValue.isNotEmpty) personaValue,
      if (snapshot.listingTypeLabel.trim().isNotEmpty)
        snapshot.listingTypeLabel.trim(),
      ...languageChips,
    ];

    final transportEmoji =
        snapshot.transportPreference.toLowerCase().contains('driv')
            ? '🚗'
            : '🚌';

    final commuteTraits = <String>[
      if (snapshot.destinationHub.trim().isNotEmpty)
        '🚉 ${snapshot.destinationHub.trim()}',
      if (snapshot.transportPreference.trim().isNotEmpty)
        '$transportEmoji ${snapshot.transportPreference.trim()}',
      if (travelValue.isNotEmpty) '⏳ $travelValue',
      if (snapshot.moveInTimeline.trim().isNotEmpty)
        '📅 ${snapshot.moveInTimeline.trim()}',
    ];

    final sections = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PublicPassportSectionHeader(title: 'Budget'),
        const SizedBox(height: SeekerOnboardingLayout.passportRelatedGap),
        _PublicPassportValueLine(
          value: budgetValue,
          placeholder: 'Add max rent',
        ),
        const SizedBox(height: SeekerOnboardingLayout.passportSectionGap),
        const _PublicPassportSectionHeader(title: 'Who you are'),
        const SizedBox(height: SeekerOnboardingLayout.passportRelatedGap),
        if (whoTraits.isEmpty)
          Text('Add profile traits', style: SeekerOnboardingLayout.helperText)
        else
          Wrap(
            spacing: OnboardingTokens.chipSpacing,
            runSpacing: OnboardingTokens.chipSpacing,
            children: [
              for (final trait in whoTraits) _PassportTraitChip(label: trait),
            ],
          ),
        const SizedBox(height: SeekerOnboardingLayout.passportSectionGap),
        const _PublicPassportSectionHeader(title: 'Commute'),
        const SizedBox(height: SeekerOnboardingLayout.passportRelatedGap),
        if (commuteTraits.isEmpty)
          Text(
            'Add destination and travel details',
            style: SeekerOnboardingLayout.helperText,
          )
        else
          Wrap(
            spacing: OnboardingTokens.chipSpacing,
            runSpacing: OnboardingTokens.chipSpacing,
            children: [
              for (final trait in commuteTraits)
                _PassportTraitChip(label: trait),
            ],
          ),
        const SizedBox(height: SeekerOnboardingLayout.passportSectionGap),
        const _PublicPassportSectionHeader(title: 'Trust'),
        const SizedBox(height: SeekerOnboardingLayout.passportRelatedGap),
        Align(
          alignment: Alignment.centerLeft,
          child: TrustBadge(
            tier: snapshot.trustTier,
            compact: false,
            showTooltip: false,
          ),
        ),
        const SizedBox(height: SeekerOnboardingLayout.passportRelatedGap),
        Text(
          snapshot.verificationProgressLabel.trim().isEmpty
              ? 'Verification pending'
              : snapshot.verificationProgressLabel,
          style: SeekerOnboardingLayout.passportValueSecondary,
        ),
        if (_verificationIncomplete(snapshot)) ...[
          const SizedBox(height: OnboardingTokens.space4),
          Text(
            'Next step: Complete verification to unlock a higher trust tier.',
            style: SeekerOnboardingLayout.helperText.copyWith(
              fontSize: 13,
              color: SeekerOnboardingLayout.labelMuted,
            ),
          ),
        ],
      ],
    );

    if (!fillHeight) {
      return sections;
    }

    return Align(
      alignment: Alignment.topLeft,
      child: sections,
    );
  }

  bool _verificationIncomplete(ContextualPassportSnapshot snapshot) {
    final rows = snapshot.verificationRows;
    if (rows.isEmpty) return true;
    final verified = rows.where((row) => row.verified).length;
    return verified == 0 || verified < rows.length;
  }
}

class _PublicPassportSectionHeader extends StatelessWidget {
  const _PublicPassportSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: SeekerOnboardingLayout.passportSectionHeader,
    );
  }
}

class _PublicPassportValueLine extends StatelessWidget {
  const _PublicPassportValueLine({
    required this.value,
    required this.placeholder,
  });

  final String value;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final resolved = value.trim();
    final empty = resolved.isEmpty;
    return Text(
      empty ? placeholder : resolved,
      style: empty
          ? SeekerOnboardingLayout.helperText
          : SeekerOnboardingLayout.passportBudgetValue,
    );
  }
}

class _PassportTraitChip extends StatelessWidget {
  const _PassportTraitChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OnboardingTokens.space12,
        vertical: OnboardingTokens.space4,
      ),
      decoration: SeekerOnboardingLayout.passportTraitChipDecoration(),
      child: Text(
        label,
        style: SeekerOnboardingLayout.chipText.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _PassportTrackBody extends StatelessWidget {
  const _PassportTrackBody({
    required this.snapshot,
    this.useOnboardingSeekerPreview = false,
    this.flatStyle = false,
    this.fillHeight = false,
  });

  final ContextualPassportSnapshot snapshot;
  final bool useOnboardingSeekerPreview;
  final bool flatStyle;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    if (useOnboardingSeekerPreview && snapshot.track.isSeeker) {
      return _SeekerSharedBody(
        snapshot: snapshot,
        flatStyle: flatStyle,
        fillHeight: fillHeight,
      );
    }
    return switch (snapshot.track) {
      ProfileOnboardingTrack.seekerSharedSpace =>
        _SeekerSharedBody(
          snapshot: snapshot,
          flatStyle: flatStyle,
          fillHeight: fillHeight,
        ),
      ProfileOnboardingTrack.seekerEntirePlace =>
        _SeekerFullRentalBody(snapshot: snapshot),
      ProfileOnboardingTrack.landlordSharedSpace =>
        _LandlordSharedBody(snapshot: snapshot),
      ProfileOnboardingTrack.landlordEntirePlace =>
        _LandlordFullRentalBody(snapshot: snapshot),
    };
  }
}

class _SeekerSharedBody extends StatelessWidget {
  const _SeekerSharedBody({
    required this.snapshot,
    this.flatStyle = false,
    this.fillHeight = false,
  });

  final ContextualPassportSnapshot snapshot;
  final bool flatStyle;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final financial = _PassportSectionCard(
      titleEmoji: '💶',
      title: 'Financial Gate',
      flatStyle: flatStyle,
      child: _MaxBudgetCard(budgetMax: snapshot.budgetMax, flatStyle: flatStyle),
    );

    final operational = _PassportSectionCard(
      titleEmoji: '🗓️',
      title: 'Operational Gate',
      flatStyle: flatStyle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PassportDetailRow(
            emoji: '📅',
            label: 'Move-in timeline',
            value: snapshot.moveInTimeline,
            placeholder: 'Add move-in date',
            flatStyle: flatStyle,
          ),
          SizedBox(
            height: flatStyle
                ? SeekerOnboardingLayout.passportRelatedGap
                : OnboardingTokens.space12,
          ),
          _PassportDetailRow(
            emoji: '🚉',
            label: 'Daily destination hub',
            value: snapshot.destinationHub,
            placeholder: 'Add commute hub',
            flatStyle: flatStyle,
          ),
          if (snapshot.maxCommuteMinutes != null &&
              snapshot.maxCommuteMinutes! > 0) ...[
            SizedBox(
              height: flatStyle
                  ? SeekerOnboardingLayout.passportRelatedGap
                  : OnboardingTokens.space12,
            ),
            _PassportDetailRow(
              emoji: '⏳',
              label: 'Max travel time',
              value: '${snapshot.maxCommuteMinutes} min',
              placeholder: 'Add travel time',
              flatStyle: flatStyle,
            ),
          ],
        ],
      ),
    );

    final compatibilityChild = snapshot.compatibilityChips.isEmpty
        ? Text(
            'Add lifestyle preferences',
            style: flatStyle
                ? SeekerOnboardingLayout.passportLabel
                : const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: ContextualPassportCard._placeholder,
                  ),
          )
        : Wrap(
            spacing: OnboardingTokens.space8,
            runSpacing: OnboardingTokens.space8,
            children: [
              for (final chip in snapshot.compatibilityChips)
                _PassportChip(chip: chip),
            ],
          );

    final compatibility = _PassportSectionCard(
      titleEmoji: '🤝',
      title: 'Compatibility Grid',
      flatStyle: flatStyle,
      expandChild: flatStyle && fillHeight,
      child: compatibilityChild,
    );

    if (!flatStyle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          financial,
          const SizedBox(height: OnboardingTokens.space12),
          operational,
          const SizedBox(height: OnboardingTokens.space12),
          compatibility,
        ],
      );
    }

    // Cohesive hierarchy: one continuous stack, fixed section gaps, no island dividers.
    // Extra height (when matching left column) is absorbed by Compatibility only.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        financial,
        const SizedBox(height: SeekerOnboardingLayout.passportSectionGap),
        operational,
        const SizedBox(height: SeekerOnboardingLayout.passportSectionGap),
        if (fillHeight) Expanded(child: compatibility) else compatibility,
      ],
    );
  }
}

class _SeekerFullRentalBody extends StatelessWidget {
  const _SeekerFullRentalBody({required this.snapshot});

  final ContextualPassportSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PassportSectionCard(
          titleEmoji: '📊',
          title: 'Eligibility Metrics',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PassportDetailRow(
                emoji: '💶',
                label: 'Budget tier',
                value: snapshot.budgetTierLabel,
                placeholder: 'Budget tier pending',
              ),
              const SizedBox(height: 10),
              _PassportDetailRow(
                emoji: '👥',
                label: 'Household breakdown',
                value: snapshot.householdBreakdown,
                placeholder: 'Add household size',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PassportSectionCard(
          titleEmoji: '🛡️',
          title: 'Verification Stack',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < snapshot.verificationRows.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _VerificationStatusRow(row: snapshot.verificationRows[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LandlordSharedBody extends StatelessWidget {
  const _LandlordSharedBody({required this.snapshot});

  final ContextualPassportSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final multiplier = snapshot.hostTrustMultiplier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PassportSectionCard(
          titleEmoji: '☘️',
          title: 'Trust Multiplier Focus',
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  snapshot.trustBadgeEmoji,
                  style: const TextStyle(fontSize: 16, height: 1.1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  multiplier == null
                      ? 'Host multiplier pending'
                      : '${multiplier.toStringAsFixed(1)}× community tier multiplier',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ContextualPassportCard._titleColor,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PassportSectionCard(
          titleEmoji: '🏡',
          title: 'Household Physics',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PassportListBlock(
                emoji: '📋',
                title: 'House rules',
                items: snapshot.houseRules,
                emptyLabel: 'Add house rules',
              ),
              const SizedBox(height: 12),
              _PassportListBlock(
                emoji: '💬',
                title: 'Languages spoken at home',
                items: snapshot.homeLanguages,
                emptyLabel: 'Add household languages',
              ),
              const SizedBox(height: 12),
              _PassportListBlock(
                emoji: '🤝',
                title: 'Flatmate preferences',
                items: snapshot.flatmatePreferences,
                emptyLabel: 'Add flatmate preferences',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LandlordFullRentalBody extends StatelessWidget {
  const _LandlordFullRentalBody({required this.snapshot});

  final ContextualPassportSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PassportSectionCard(
          titleEmoji: '🏛️',
          title: 'Rigor Stack',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PassportDetailRow(
                emoji: '🪪',
                label: 'ID verification',
                value: snapshot.idVerificationLabel,
                placeholder: 'ID verification pending',
              ),
              const SizedBox(height: 10),
              _PassportDetailRow(
                emoji: '📜',
                label: 'Licensing indicators',
                value: snapshot.licensingLabel,
                placeholder: 'Licensing pending',
              ),
              const SizedBox(height: 10),
              _PassportDetailRow(
                emoji: '⚡',
                label: 'Systemic responsiveness',
                value: snapshot.responsivenessLabel,
                placeholder: 'Response window pending',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PassportSectionCard extends StatelessWidget {
  const _PassportSectionCard({
    required this.titleEmoji,
    required this.title,
    required this.child,
    this.flatStyle = false,
    this.expandChild = false,
  });

  final String titleEmoji;
  final String title;
  final Widget child;
  final bool flatStyle;
  /// When true (flat fill mode), child absorbs remaining height under the header.
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    if (flatStyle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: SeekerOnboardingLayout.passportSectionHeader,
          ),
          const SizedBox(height: SeekerOnboardingLayout.passportRelatedGap),
          if (expandChild)
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: child,
              ),
            )
          else
            child,
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ContextualPassportCard._cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ContextualPassportCard._cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmojiLeadingRow(
            emoji: titleEmoji,
            text: title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ContextualPassportCard._titleColor,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PassportDetailRow extends StatelessWidget {
  const _PassportDetailRow({
    required this.emoji,
    required this.label,
    required this.value,
    required this.placeholder,
    this.flatStyle = false,
  });

  final String emoji;
  final String label;
  final String value;
  final String placeholder;
  final bool flatStyle;

  @override
  Widget build(BuildContext context) {
    final resolved = value.trim();
    if (flatStyle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: SeekerOnboardingLayout.passportLabel),
          const SizedBox(height: SeekerOnboardingLayout.passportLabelValueGap),
          Text(
            resolved.isEmpty ? placeholder : resolved,
            style: resolved.isEmpty
                ? SeekerOnboardingLayout.passportLabel
                : SeekerOnboardingLayout.passportValue,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmojiLeadingRow(
          emoji: emoji,
          text: label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ContextualPassportCard._subtitleColor,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(
            resolved.isEmpty ? placeholder : resolved,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: resolved.isEmpty
                  ? ContextualPassportCard._placeholder
                  : ContextualPassportCard._titleColor,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _MaxBudgetCard extends StatelessWidget {
  const _MaxBudgetCard({
    required this.budgetMax,
    this.flatStyle = false,
  });

  final int? budgetMax;
  final bool flatStyle;

  @override
  Widget build(BuildContext context) {
    final hasBudget = budgetMax != null;
    final budgetLabel = hasBudget
        ? '${NumberFormat.currency(symbol: '€', decimalDigits: 0).format(budgetMax!)}/mo'
        : 'Add max budget';

    if (flatStyle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Max Budget', style: SeekerOnboardingLayout.passportLabel),
          const SizedBox(height: SeekerOnboardingLayout.passportLabelValueGap),
          Text(
            budgetLabel,
            style: hasBudget
                ? SeekerOnboardingLayout.passportValue
                    .copyWith(fontWeight: FontWeight.w600)
                : SeekerOnboardingLayout.passportLabel,
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ContextualPassportCard._cardBorder),
      ),
      child: Row(
        children: [
          const Text('💶', style: TextStyle(fontSize: 18, height: 1)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Max Budget',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ContextualPassportCard._subtitleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  budgetLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: hasBudget
                        ? ContextualPassportCard._titleColor
                        : ContextualPassportCard._placeholder,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PassportChip extends StatelessWidget {
  const _PassportChip({required this.chip});

  final ContextualPassportChip chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ContextualPassportCard._cardBorder),
      ),
      child: EmojiLeadingRow(
        emoji: chip.emoji,
        text: chip.label,
        emojiWidth: 18,
        emojiFontSize: 13,
        gap: 6,
        expandText: false,
        style: SeekerOnboardingLayout.chipText.copyWith(
          color: const Color(0xFF334155),
        ),
      ),
    );
  }
}

class _VerificationStatusRow extends StatelessWidget {
  const _VerificationStatusRow({required this.row});

  final ContextualPassportVerificationRow row;

  @override
  Widget build(BuildContext context) {
    final color = row.verified ? const Color(0xFF047857) : const Color(0xFF94A3B8);
    final bg = row.verified ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: row.verified ? const Color(0xFFBBF7D0) : ContextualPassportCard._cardBorder,
        ),
      ),
      child: EmojiLeadingRow(
        emoji: row.emoji,
        text: row.label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.3,
        ),
      ),
    );
  }
}

class _PassportListBlock extends StatelessWidget {
  const _PassportListBlock({
    required this.emoji,
    required this.title,
    required this.items,
    required this.emptyLabel,
  });

  final String emoji;
  final String title;
  final List<String> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmojiLeadingRow(
          emoji: emoji,
          text: title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ContextualPassportCard._subtitleColor,
          ),
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              emptyLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ContextualPassportCard._placeholder,
              ),
            ),
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 4),
              child: Text(
                '• $item',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ContextualPassportCard._titleColor,
                  height: 1.35,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
