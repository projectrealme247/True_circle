import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../debug/agent_log.dart';
import '../../models/profile_onboarding_models.dart';
import '../../utils/contextual_passport_snapshot.dart';
import '../../theme/app_scroll_behavior.dart';
import '../emoji_leading_row.dart';
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
  });

  factory ContextualPassportCard.fromSession(
    Map<String, dynamic> session, {
    int? listingBudgetRequirement,
    String headerCaption = 'Your Public Passport',
    bool showHeaderCaption = true,
    bool useOnboardingSeekerPreview = false,
  }) {
    return ContextualPassportCard(
      snapshot: ContextualPassportSnapshot.fromSession(
        session,
        listingBudgetRequirement: listingBudgetRequirement,
      ),
      headerCaption: headerCaption,
      showHeaderCaption: showHeaderCaption,
      useOnboardingSeekerPreview: useOnboardingSeekerPreview,
    );
  }

  final ContextualPassportSnapshot snapshot;
  final String headerCaption;
  final bool showHeaderCaption;
  final bool omitOuterFrame;
  /// During seeker onboarding, show Financial / Operational / Compatibility sections
  /// for both Independent Place and Shared Living tracks.
  final bool useOnboardingSeekerPreview;

  static const _titleColor = Color(0xFF0F172A);
  static const _subtitleColor = Color(0xFF64748B);
  static const _placeholder = Color(0xFFCBD5E1);
  static const _cardFill = Color(0xFFF8FAFC);
  static const _cardBorder = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // #region agent log
        agentLog(
          'H1',
          'contextual_passport_card.dart:ContextualPassportCard',
          'passport card constraints',
          {
            'maxH': constraints.maxHeight,
            'minH': constraints.minHeight,
            'hasBoundedHeight': constraints.hasBoundedHeight,
            'omitOuterFrame': omitOuterFrame,
          },
        );
        // #endregion

        final body = ScrollConfiguration(
      behavior: const OnboardingFormScrollBehavior(),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        primary: false,
        physics: appPageScrollPhysics,
        child: Column(
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
        ),
      ),
    );

        if (omitOuterFrame) {
          return SizedBox(width: double.infinity, child: body);
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
}

class _PassportIdentityHeader extends StatelessWidget {
  const _PassportIdentityHeader({required this.snapshot});

  final ContextualPassportSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final name = snapshot.displayName.trim();

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
                  color: name.isEmpty ? ContextualPassportCard._placeholder : const Color(0xFF334155),
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
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: name.isEmpty
                        ? ContextualPassportCard._placeholder
                        : ContextualPassportCard._titleColor,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
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

class _PassportTrackBody extends StatelessWidget {
  const _PassportTrackBody({
    required this.snapshot,
    this.useOnboardingSeekerPreview = false,
  });

  final ContextualPassportSnapshot snapshot;
  final bool useOnboardingSeekerPreview;

  @override
  Widget build(BuildContext context) {
    if (useOnboardingSeekerPreview && snapshot.track.isSeeker) {
      return _SeekerSharedBody(snapshot: snapshot);
    }
    return switch (snapshot.track) {
      ProfileOnboardingTrack.seekerSharedSpace =>
        _SeekerSharedBody(snapshot: snapshot),
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
  const _SeekerSharedBody({required this.snapshot});

  final ContextualPassportSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PassportSectionCard(
          titleEmoji: '💶',
          title: 'Financial Gate',
          child: _MaxBudgetCard(budgetMax: snapshot.budgetMax),
        ),
        const SizedBox(height: 12),
        _PassportSectionCard(
          titleEmoji: '🗓️',
          title: 'Operational Gate',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PassportDetailRow(
                emoji: '📅',
                label: 'Move-in timeline',
                value: snapshot.moveInTimeline,
                placeholder: 'Add move-in date',
              ),
              const SizedBox(height: 10),
              _PassportDetailRow(
                emoji: '🚉',
                label: 'Daily destination hub',
                value: snapshot.destinationHub,
                placeholder: 'Add commute hub',
              ),
              if (snapshot.maxCommuteMinutes != null &&
                  snapshot.maxCommuteMinutes! > 0) ...[
                const SizedBox(height: 10),
                _PassportDetailRow(
                  emoji: '⏳',
                  label: 'Max travel time',
                  value: '${snapshot.maxCommuteMinutes} min',
                  placeholder: 'Add travel time',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PassportSectionCard(
          titleEmoji: '🤝',
          title: 'Compatibility Grid',
          child: snapshot.compatibilityChips.isEmpty
              ? const Text(
                  'Add lifestyle preferences',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: ContextualPassportCard._placeholder,
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final chip in snapshot.compatibilityChips)
                      _PassportChip(chip: chip),
                  ],
                ),
        ),
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
  });

  final String titleEmoji;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
  });

  final String emoji;
  final String label;
  final String value;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final resolved = value.trim();
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
  const _MaxBudgetCard({required this.budgetMax});

  final int? budgetMax;

  @override
  Widget build(BuildContext context) {
    final hasBudget = budgetMax != null;
    final budgetLabel = hasBudget
        ? '${NumberFormat.currency(symbol: '€', decimalDigits: 0).format(budgetMax!)}/mo'
        : 'Add max budget';

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ContextualPassportCard._cardBorder),
      ),
      child: EmojiLeadingRow(
        emoji: chip.emoji,
        text: chip.label,
        emojiWidth: 20,
        emojiFontSize: 13,
        gap: 6,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
          height: 1.2,
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
