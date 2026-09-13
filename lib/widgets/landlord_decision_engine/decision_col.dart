import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/landlord_engine_models.dart';
import '../../models/landlord_recommendation_state.dart';
import '../landlord_dashboard/landlord_dashboard_theme.dart';
import 'applicant_passport.dart';

const _kWhyCoral = Color(0xFFE05A3A);
const _kWhyTint = Color(0xFFFDF0EC);
const _kAlertAmber = Color(0xFF854F0B);
const _kPositiveGreen = Color(0xFF0F6E56);
const _kCardBorder = Color(0xFFE8E6E1);

/// Col 3 — decision workspace for one applicant.
///
/// One unified card. No [SingleChildScrollView]. No font-based icons
/// (CanvasKit-safe: colored dots + Unicode checkmarks only).
class DecisionCol extends StatelessWidget {
  const DecisionCol({
    super.key,
    required this.applicant,
    required this.listingType,
    required this.onInvite,
    required this.onMessage,
    this.onDismiss,
  });

  final Applicant applicant;
  final ListingType listingType;
  final VoidCallback onInvite;
  final VoidCallback onMessage;
  /// Not Suitable primary action — defaults to [onMessage] if null.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final outerPad = h < 520 ? AppSpacing.sm : AppSpacing.md;
        final compact = h < 560;

        return Padding(
          padding: EdgeInsets.all(outerPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 560),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kCardBorder),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1 — Verdict + identity
                      _VerdictChip(
                        verdict: applicant.verdict,
                        compact: compact,
                      ),
                      const SizedBox(height: 8),
                      _PersonRow(applicant: applicant, compact: compact),
                      const SizedBox(height: 16),
                      const _ThinDivider(),
                      const SizedBox(height: 16),

                      // 2 — Why recommended
                      _SectionWhyRecommended(
                        applicant: applicant,
                        listingType: listingType,
                        compact: compact,
                      ),
                      const SizedBox(height: 16),
                      const _ThinDivider(),
                      const SizedBox(height: 16),

                      // 3 — Applicant Passport (same slot as former Proof of Trust)
                      ApplicantPassport(
                        applicant: applicant,
                        listingType: listingType,
                        compact: compact,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _contextLine(applicant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: LandlordDashboardTheme.textSecondary,
                        ),
                      ),

                      // Pin CTAs to bottom — single Spacer only
                      const Spacer(),

                      // 4 — Actions (state-aware labels / enablement)
                      _SectionActions(
                        verdict: applicant.verdict,
                        onInvite: onInvite,
                        onMessage: onMessage,
                        onDismiss: onDismiss ?? onMessage,
                        compact: compact,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _contextLine(Applicant a) {
    final move = a.moveInLabel.toLowerCase().contains('immediate')
        ? 'available now'
        : a.moveInLabel;
    final lang = a.languages.isEmpty ? null : '${a.languages.first} spoken';
    return [
      'Move-in: $move',
      if (lang != null) lang,
    ].join(' · ');
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _kCardBorder,
      child: SizedBox(height: 0.5, width: double.infinity),
    );
  }
}

// ─── Section 1 ───────────────────────────────────────────────────────────────

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.applicant,
    required this.compact,
  });

  final Applicant applicant;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = LandlordDashboardTheme.avatarColorsFor(applicant.name);
    final initials = _initials(applicant.name);

    return Row(
      children: [
        Container(
          width: compact ? 40 : 48,
          height: compact ? 40 : 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: fg.withValues(alpha: 0.2)),
          ),
          child: Text(
            initials,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
        SizedBox(width: compact ? 10 : 12),
        Expanded(
          child: Text(
            applicant.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.35,
              height: 1.2,
              color: LandlordDashboardTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _VerdictChip extends StatelessWidget {
  const _VerdictChip({
    required this.verdict,
    required this.compact,
  });

  final DecisionVerdict verdict;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, emoji) = switch (verdict) {
      DecisionVerdict.recommended => (
          LandlordDashboardTheme.readyInk,
          LandlordDashboardTheme.readyFill,
          '✨',
        ),
      DecisionVerdict.viewingInvited => (
          LandlordDashboardTheme.reviewInk,
          LandlordDashboardTheme.reviewFill,
          '📨',
        ),
      DecisionVerdict.needsReview => (
          LandlordDashboardTheme.timingInk,
          LandlordDashboardTheme.timingFill,
          '👀',
        ),
      DecisionVerdict.notSuitable => (
          LandlordDashboardTheme.declineInk,
          LandlordDashboardTheme.declineFill,
          '🚫',
        ),
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(color: fg.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Text(
            emoji,
            style: TextStyle(
              fontSize: compact ? 16 : 20,
              height: 1,
              fontFamily: AppTypography.emojiFontFamily,
              fontFamilyFallback: AppTypography.emojiFontFallback,
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Text(
              verdict.label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section 2 — Why Recommended ─────────────────────────────────────────────

class _SectionWhyRecommended extends StatelessWidget {
  const _SectionWhyRecommended({
    required this.applicant,
    required this.listingType,
    required this.compact,
  });

  final Applicant applicant;
  final ListingType listingType;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final copy = _WhyRecommendedCopy.build(
      applicant: applicant,
      listingType: listingType,
    );
    final proseSize = compact ? 13.5 : 15.0;
    final bulletSize = compact ? 12.5 : 13.5;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kWhyTint.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: _kWhyCoral, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            copy.sectionTitle,
            style: LandlordDashboardTheme.railEyebrow().copyWith(
              fontSize: compact ? 10 : 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            copy.prose,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: proseSize,
              fontWeight: FontWeight.w600,
              height: 1.35,
              letterSpacing: -0.2,
              color: LandlordDashboardTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < copy.bullets.length; i++) ...[
            if (i > 0) SizedBox(height: compact ? 4 : 6),
            _DotBullet(
              color: copy.bullets[i].kind.dotColor,
              text: copy.bullets[i].text,
              fontSize: bulletSize,
              colorText: LandlordDashboardTheme.textSecondary,
            ),
          ],
          if (copy.mismatchNote != null) ...[
            SizedBox(height: compact ? 8 : 10),
            _DotBullet(
              color: _kAlertAmber,
              text: copy.mismatchNote!,
              fontSize: compact ? 12 : 13,
              colorText: _kAlertAmber,
              weight: FontWeight.w600,
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }
}

enum _BulletKind {
  positive,
  warning,
}

extension on _BulletKind {
  Color get dotColor => switch (this) {
        _BulletKind.warning => _kAlertAmber,
        _BulletKind.positive => _kPositiveGreen,
      };
}

class _WhyBullet {
  const _WhyBullet(this.kind, this.text);
  final _BulletKind kind;
  final String text;
}

/// CanvasKit-safe bullet: 6px colored circle (no IconData / icon fonts).
class _DotBullet extends StatelessWidget {
  const _DotBullet({
    required this.color,
    required this.text,
    required this.fontSize,
    required this.colorText,
    this.weight = FontWeight.w500,
    this.maxLines = 2,
  });

  final Color color;
  final String text;
  final double fontSize;
  final Color colorText;
  final FontWeight weight;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: fontSize,
              fontWeight: weight,
              height: 1.35,
              color: colorText,
            ),
          ),
        ),
      ],
    );
  }
}

/// Derives prose + bullets + optional mismatch from applicant + listing type.
class _WhyRecommendedCopy {
  const _WhyRecommendedCopy({
    required this.sectionTitle,
    required this.prose,
    required this.bullets,
    this.mismatchNote,
  });

  final String sectionTitle;
  final String prose;
  final List<_WhyBullet> bullets;
  final String? mismatchNote;

  static _WhyRecommendedCopy build({
    required Applicant applicant,
    required ListingType listingType,
  }) {
    final base = listingType.isShared
        ? _shared(applicant)
        : _entire(applicant);
    return _WhyRecommendedCopy(
      sectionTitle: applicant.verdict.whySectionTitle,
      prose: base.prose,
      bullets: base.bullets,
      mismatchNote: base.mismatchNote,
    );
  }

  static _WhyRecommendedCopy _shared(Applicant a) {
    final prose = switch (a.verdict) {
      DecisionVerdict.viewingInvited =>
        'Viewing already invited — follow up when you are ready to meet.',
      DecisionVerdict.recommended =>
        'Strong household and lifestyle fit for this shared home — ready to invite.',
      DecisionVerdict.needsReview =>
        'Close on lifestyle, but a few household signals need your judgment before inviting.',
      DecisionVerdict.notSuitable =>
        'This applicant conflicts with hard house rules or filters — not a fit to invite.',
    };

    final lifestyleOk =
        (a.lifestylePercent != null && a.lifestylePercent! >= 70) ||
            a.foodCompatible == true;
    final lifestyleLine = lifestyleOk
        ? 'Lifestyle and household habits compatible'
        : 'Lifestyle and household habits need a closer look';

    final specific = _sharedSpecificSignal(a);

    final affordOk = a.affordabilityMeetsTarget;
    final affordLine = affordOk
        ? 'Affordability looks comfortable for this room'
        : 'Affordability needs a closer look';

    final bullets = <_WhyBullet>[
      _WhyBullet(
        lifestyleOk ? _BulletKind.positive : _BulletKind.warning,
        lifestyleLine,
      ),
      _WhyBullet(_BulletKind.positive, specific),
      _WhyBullet(
        affordOk ? _BulletKind.positive : _BulletKind.warning,
        affordLine,
      ),
    ];

    String? mismatch;
    if (a.foodCompatible == false) {
      mismatch = 'Kitchen culture may not match this household.';
    } else if (a.smokingCompatible == false) {
      mismatch = 'Smoking preference conflicts with house rules.';
    } else if (!a.affordabilityMeetsTarget) {
      mismatch = 'Income sits below the comfort target for this room.';
    } else if (a.recommendation == LandlordRecommendationState.timingConflict) {
      mismatch = 'Move-in timing does not line up cleanly with availability.';
    } else if (a.recommendation == LandlordRecommendationState.notSuitable) {
      mismatch = 'A hard filter mismatch means this applicant is unlikely to work.';
    }

    return _WhyRecommendedCopy(
      sectionTitle: '',
      prose: prose,
      bullets: bullets,
      mismatchNote: mismatch,
    );
  }

  static String _sharedSpecificSignal(Applicant a) {
    if (a.smokingCompatible == true) return 'Non-smoker';
    if (a.smokingCompatible == false) {
      return 'Smoking may conflict with house rules';
    }
    if (a.foodCompatible == true) return 'Kitchen habits look compatible';
    if (a.foodCompatible == false) return 'Kitchen habits may conflict';
    if (a.hasPets) return 'Has pets — confirm with the household';
    if (a.languages.isNotEmpty) {
      return 'Shares ${a.languages.take(2).join(' / ')}';
    }
    return 'Quiet evenings preferred';
  }

  static _WhyRecommendedCopy _entire(Applicant a) {
    final prose = switch (a.verdict) {
      DecisionVerdict.viewingInvited =>
        'Viewing already invited — keep momentum with a clear next step.',
      DecisionVerdict.recommended =>
        'Income, timing, and stability line up well for this entire place.',
      DecisionVerdict.needsReview =>
        'Promising on paper — confirm income, timing, or stability before you invite.',
      DecisionVerdict.notSuitable =>
        'This applicant misses a hard requirement for this home — not a fit to invite.',
    };

    final incomeOk = a.incomeVerified || a.affordabilityMeetsTarget;
    final incomeBit = a.incomeVerified
        ? 'Income verified'
        : a.affordabilityMeetsTarget
            ? 'Income signal looks sound'
            : 'Income needs a closer look';

    final moveOk = !(a.moveInLabel.contains('Weak') ||
        a.recommendation == LandlordRecommendationState.timingConflict);
    final moveIn =
        moveOk ? 'Move-in timing confirmed' : 'Move-in timing needs a conversation';

    final stability = (a.stabilityBullet != null &&
            a.stabilityBullet!.trim().isNotEmpty)
        ? a.stabilityBullet!.trim()
        : 'Tenant stability to confirm';

    final bullets = <_WhyBullet>[
      _WhyBullet(
        incomeOk ? _BulletKind.positive : _BulletKind.warning,
        incomeBit,
      ),
      _WhyBullet(
        moveOk ? _BulletKind.positive : _BulletKind.warning,
        moveIn,
      ),
      _WhyBullet(
        a.stabilityBullet != null && a.stabilityBullet!.trim().isNotEmpty
            ? _BulletKind.positive
            : _BulletKind.warning,
        stability,
      ),
    ];

    String? mismatch;
    if (!a.propertyMatch) {
      mismatch = 'Property layout does not match what they asked for.';
    } else if (a.recommendation == LandlordRecommendationState.timingConflict) {
      mismatch = 'Move-in window conflicts with when this home is free.';
    } else if (!a.affordabilityMeetsTarget) {
      mismatch = 'Affordability sits under the comfort line for this rent.';
    } else if (a.recommendation ==
        LandlordRecommendationState.guarantorReview) {
      mismatch = 'Guarantor status still needs a clear yes before you proceed.';
    } else if (a.recommendation == LandlordRecommendationState.notSuitable) {
      mismatch = 'A hard requirement mismatch makes this a poor fit.';
    }

    return _WhyRecommendedCopy(
      sectionTitle: '',
      prose: prose,
      bullets: bullets,
      mismatchNote: mismatch,
    );
  }
}

// ─── Section 4 ───────────────────────────────────────────────────────────────

class _SectionActions extends StatelessWidget {
  const _SectionActions({
    required this.verdict,
    required this.onInvite,
    required this.onMessage,
    required this.onDismiss,
    required this.compact,
  });

  final DecisionVerdict verdict;
  final VoidCallback onInvite;
  final VoidCallback onMessage;
  final VoidCallback onDismiss;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 42.0 : 48.0;

    final primaryLabel = switch (verdict) {
      DecisionVerdict.viewingInvited => 'Message applicant',
      DecisionVerdict.notSuitable => 'Dismiss',
      DecisionVerdict.needsReview => 'Invite anyway',
      DecisionVerdict.recommended => 'Invite viewing',
    };

    final secondaryLabel = switch (verdict) {
      DecisionVerdict.viewingInvited => 'Resend invite',
      DecisionVerdict.notSuitable => 'Message',
      _ => 'Message',
    };

    final VoidCallback primaryAction = switch (verdict) {
      DecisionVerdict.viewingInvited => onMessage,
      DecisionVerdict.notSuitable => onDismiss,
      _ => onInvite,
    };

    final VoidCallback secondaryAction = switch (verdict) {
      DecisionVerdict.viewingInvited => onInvite,
      _ => onMessage,
    };

    final primaryFilled = verdict != DecisionVerdict.notSuitable;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: primaryFilled
              ? FilledButton(
                  onPressed: primaryAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: Size(0, height),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: compact ? 14 : 15,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(primaryLabel),
                )
              : OutlinedButton(
                  onPressed: primaryAction,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LandlordDashboardTheme.declineInk,
                    minimumSize: Size(0, height),
                    side: const BorderSide(
                      color: LandlordDashboardTheme.declineInk,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(primaryLabel),
                ),
        ),
        SizedBox(width: compact ? 8 : 10),
        Expanded(
          flex: 2,
          child: OutlinedButton(
            onPressed: secondaryAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: LandlordDashboardTheme.textPrimary,
              minimumSize: Size(0, height),
              side: const BorderSide(
                color: LandlordDashboardTheme.borderStrong,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Text(secondaryLabel),
          ),
        ),
      ],
    );
  }
}
