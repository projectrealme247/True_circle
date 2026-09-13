import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/landlord_applicant_card_model.dart';
import '../../models/move_in_timing.dart';
import '../../models/seeker_onboarding_enums.dart';
import 'landlord_dashboard_theme.dart';

/// Context-aware fact rows for Independent Places vs Shared Living.
class LandlordApplicantSummaryFacts {
  LandlordApplicantSummaryFacts._();

  /// Students are asked the guarantor question; professionals typically are not.
  static bool isStudent(LandlordApplicantCardModel applicant) =>
      applicant.decision?.guarantorStatus != null;

  static String queueHint(LandlordApplicantCardModel applicant) {
    final rows = build(applicant);
    if (rows.isEmpty) return applicant.statusLabel;
    final first = rows.first;
    return '${first.emoji} ${first.label}: ${first.value}';
  }

  static List<LandlordApplicantSummaryRow> build(
    LandlordApplicantCardModel applicant,
  ) {
    final student = isStudent(applicant);
    if (applicant.isSharedLiving) {
      return _shared(applicant, student: student);
    }
    return _independent(applicant, student: student);
  }

  static List<LandlordApplicantSummaryRow> _independent(
    LandlordApplicantCardModel applicant, {
    required bool student,
  }) {
    if (student) {
      return [
        _budget(applicant),
        _university(applicant),
        _guarantor(applicant),
        _moveIn(applicant),
        _householdSize(applicant),
        _leaseIntent(applicant),
      ];
    }
    return [
      _budget(applicant),
      _employment(applicant),
      _moveIn(applicant),
      _householdSize(applicant),
      _leaseIntent(applicant),
    ];
  }

  static List<LandlordApplicantSummaryRow> _shared(
    LandlordApplicantCardModel applicant, {
    required bool student,
  }) {
    final rows = <LandlordApplicantSummaryRow>[
      _lifestyleFit(applicant),
      _smoking(applicant),
      _food(applicant),
      _languages(applicant),
    ];
    if (student) {
      rows.addAll([
        _university(applicant),
        _guarantor(applicant),
      ]);
    }
    rows.addAll([
      _budget(applicant),
      _moveIn(applicant),
      _householdFit(applicant),
    ]);
    return rows;
  }

  static LandlordApplicantSummaryRow _budget(
    LandlordApplicantCardModel applicant,
  ) {
    return LandlordApplicantSummaryRow(
      emoji: '💰',
      label: 'Budget Fit',
      value: applicant.decision?.affordabilityLabel ??
          applicant.affordabilityLabel,
    );
  }

  static LandlordApplicantSummaryRow _employment(
    LandlordApplicantCardModel applicant,
  ) {
    return LandlordApplicantSummaryRow(
      emoji: '💼',
      label: 'Employment Status',
      value: applicant.decision?.employmentVerified == true
          ? 'Confirmed'
          : 'Open',
    );
  }

  static LandlordApplicantSummaryRow _university(
    LandlordApplicantCardModel applicant,
  ) {
    return LandlordApplicantSummaryRow(
      emoji: '🎓',
      label: 'University',
      value: applicant.isVerifiedUser ? 'Verified' : 'Pending',
    );
  }

  static LandlordApplicantSummaryRow _guarantor(
    LandlordApplicantCardModel applicant,
  ) {
    return LandlordApplicantSummaryRow(
      emoji: '🛡️',
      label: 'Guarantor',
      value: switch (applicant.decision?.guarantorStatus) {
        GuarantorStatus.yes => 'Available',
        GuarantorStatus.no => 'None',
        GuarantorStatus.notSureYet => 'Unsure',
        null => 'Not asked',
      },
    );
  }

  static LandlordApplicantSummaryRow _moveIn(
    LandlordApplicantCardModel applicant,
  ) {
    return LandlordApplicantSummaryRow(
      emoji: '📅',
      label: 'Move-in Timeline',
      value: _moveInValue(applicant),
    );
  }

  static LandlordApplicantSummaryRow _householdSize(
    LandlordApplicantCardModel applicant,
  ) {
    return LandlordApplicantSummaryRow(
      emoji: '👥',
      label: 'Household Size',
      value: applicant.decision?.householdCompositionLabel ?? 'Unknown',
    );
  }

  static LandlordApplicantSummaryRow _leaseIntent(
    LandlordApplicantCardModel applicant,
  ) {
    final months = applicant.decision?.preferredLeaseMonths;
    final value = months != null
        ? '$months months'
        : (applicant.decision?.leaseTermMatch == true ? 'Aligned' : 'Unknown');
    return LandlordApplicantSummaryRow(
      emoji: '📜',
      label: 'Lease Intent',
      value: value,
    );
  }

  static LandlordApplicantSummaryRow _lifestyleFit(
    LandlordApplicantCardModel applicant,
  ) {
    final d = applicant.decision;
    final pct = d?.lifestyleMatchPercent;
    String value;
    if (pct != null) {
      value = pct >= 70
          ? 'Strong'
          : pct >= 50
              ? 'Good'
              : 'Review';
    } else if (d?.foodCompatible == true && d?.smokingCompatible == true) {
      value = 'Aligned';
    } else if (d?.foodCompatible == false || d?.smokingCompatible == false) {
      value = 'Review';
    } else {
      value = 'Unknown';
    }
    return LandlordApplicantSummaryRow(
      emoji: '✨',
      label: 'Lifestyle Fit',
      value: value,
    );
  }

  static LandlordApplicantSummaryRow _smoking(
    LandlordApplicantCardModel applicant,
  ) {
    final ok = applicant.decision?.smokingCompatible;
    return LandlordApplicantSummaryRow(
      emoji: '🚭',
      label: 'Smoking',
      value: ok == null
          ? 'Unknown'
          : ok
              ? 'Fits house'
              : 'Conflict',
    );
  }

  static LandlordApplicantSummaryRow _food(
    LandlordApplicantCardModel applicant,
  ) {
    final ok = applicant.decision?.foodCompatible;
    return LandlordApplicantSummaryRow(
      emoji: '🍽️',
      label: 'Food Preference',
      value: ok == null
          ? 'Unknown'
          : ok
              ? 'Compatible'
              : 'Mismatch',
    );
  }

  static LandlordApplicantSummaryRow _languages(
    LandlordApplicantCardModel applicant,
  ) {
    final overlap = applicant.decision?.languageOverlap ?? const <String>[];
    final value = overlap.isNotEmpty
        ? overlap.join(', ')
        : applicant.languages.isNotEmpty
            ? applicant.languages.join(', ')
            : 'None shared';
    return LandlordApplicantSummaryRow(
      emoji: '🗣️',
      label: 'Languages',
      value: value,
    );
  }

  static LandlordApplicantSummaryRow _householdFit(
    LandlordApplicantCardModel applicant,
  ) {
    final d = applicant.decision;
    final value = d == null
        ? 'Unknown'
        : d.propertyRequirementMatch
            ? 'Fits household'
            : 'Does not fit';
    return LandlordApplicantSummaryRow(
      emoji: '🏠',
      label: 'Household Fit',
      value: value,
    );
  }

  static String _moveInValue(LandlordApplicantCardModel applicant) {
    final d = applicant.decision;
    final window = d?.moveInWindowLabel.trim() ?? '';
    if (window.isNotEmpty) {
      return window.split(' · ').first;
    }
    switch (d?.moveInQuality) {
      case TimingMatchQuality.strong:
        return 'Strong';
      case TimingMatchQuality.good:
        return 'Good';
      case TimingMatchQuality.flexible:
        return 'Flexible';
      case TimingMatchQuality.weak:
        return 'Weak';
      case TimingMatchQuality.none:
      case null:
        break;
    }
    final fallback = applicant.moveInLabel?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback.split(' · ').first;
    }
    return 'Unknown';
  }
}

class LandlordApplicantSummaryRow {
  const LandlordApplicantSummaryRow({
    required this.emoji,
    required this.label,
    required this.value,
  });

  final String emoji;
  final String label;
  final String value;
}

/// Compact context-aware facts for column 3.
class LandlordDecisionSummaryPanel extends StatelessWidget {
  const LandlordDecisionSummaryPanel({
    super.key,
    required this.applicant,
  });

  final LandlordApplicantCardModel applicant;

  @override
  Widget build(BuildContext context) {
    final rows = LandlordApplicantSummaryFacts.build(applicant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: _FactRow(row: row),
          ),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.row});

  final LandlordApplicantSummaryRow row;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${row.emoji}  '),
          TextSpan(
            text: '${row.label}: ',
            style: LandlordDashboardTheme.cardSubtext(),
          ),
          TextSpan(
            text: row.value,
            style: LandlordDashboardTheme.cardLabel().copyWith(
              fontSize: 13,
              color: LandlordDashboardTheme.textPrimary,
            ),
          ),
        ],
      ),
      style: AppTypography.withEmojiFallback(
        LandlordDashboardTheme.cardSubtext(),
      ),
    );
  }
}
