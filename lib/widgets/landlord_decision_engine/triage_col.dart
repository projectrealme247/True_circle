import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/applicant_trust_tier.dart';
import '../../models/landlord_engine_models.dart';
import '../../models/landlord_recommendation_state.dart';
import '../landlord_dashboard/landlord_dashboard_theme.dart';

/// Col 2 — triage queue. “Who should I review next?”
///
/// Card UI: verdict · avatar + name · one-line triage sentence.
/// [Applicant.matchPercent] is for sort order only — never displayed.
class TriageCol extends StatelessWidget {
  const TriageCol({
    super.key,
    required this.listingType,
    required this.applicants,
    required this.selectedId,
    required this.onSelect,
  });

  final ListingType listingType;
  final List<Applicant> applicants;
  final String? selectedId;
  final ValueChanged<Applicant> onSelect;

  static const double width = 340;

  @override
  Widget build(BuildContext context) {
    final sorted = List<Applicant>.from(applicants)
      ..sort((a, b) {
        final cmp = _verdictSort(a.verdict).compareTo(_verdictSort(b.verdict));
        if (cmp != 0) return cmp;
        // Internal ranking only — not shown on the card.
        return b.matchPercent.compareTo(a.matchPercent);
      });

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: LandlordDashboardTheme.surface,
        border: Border(
          right: BorderSide(color: LandlordDashboardTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    listingType.isShared ? '👥  Housemates' : '👥  Applicants',
                    style: AppTypography.withEmojiFallback(
                      LandlordDashboardTheme.railEyebrow(),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: LandlordDashboardTheme.selectionFill,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${applicants.length}',
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: LandlordDashboardTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        listingType.isShared
                            ? '☕  No housemate applications yet.'
                            : '☕  No applicants yet.',
                        textAlign: TextAlign.center,
                        style: AppTypography.withEmojiFallback(
                          const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 14,
                            height: 1.45,
                            color: LandlordDashboardTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final a = sorted[index];
                      return _TriageCard(
                        applicant: a,
                        listingType: listingType,
                        selected: a.id == selectedId,
                        onTap: () => onSelect(a),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static int _verdictSort(DecisionVerdict v) => switch (v) {
        DecisionVerdict.recommended => 0,
        DecisionVerdict.needsReview => 1,
        DecisionVerdict.viewingInvited => 2,
        DecisionVerdict.notSuitable => 3,
      };
}

class _TriageCard extends StatelessWidget {
  const _TriageCard({
    required this.applicant,
    required this.listingType,
    required this.selected,
    required this.onTap,
  });

  final Applicant applicant;
  final ListingType listingType;
  final bool selected;
  final VoidCallback onTap;

  String get _initials {
    final parts = applicant.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final verdict = applicant.verdict;
    final (fg, bg) = _verdictColors(verdict);
    final (avatarBg, avatarFg) =
        LandlordDashboardTheme.avatarColorsFor(applicant.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected
            ? LandlordDashboardTheme.selectionFill
            : LandlordDashboardTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? fg.withValues(alpha: 0.35)
                    : LandlordDashboardTheme.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: fg.withValues(alpha: 0.12)),
                  ),
                  child: Text(
                    verdict.label,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.35,
                      color: fg,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: avatarBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: avatarFg.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        _initials,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: avatarFg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            applicant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LandlordDashboardTheme.personName(size: 15.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _triageSentence(applicant, listingType),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: LandlordDashboardTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One-line cue — trust + a single signal. No match %, no trust pill.
  static String _triageSentence(Applicant a, ListingType type) {
    final tier = a.employmentVerified
        ? ApplicantTrustTier.verifiedUserLabel
        : 'Verification pending';
    final signal = type.isShared
        ? _sharedSignal(a)
        : _entireSignal(a);
    return '$tier · $signal';
  }

  static String _sharedSignal(Applicant a) {
    if (a.recommendation == LandlordRecommendationState.notSuitable ||
        a.verdict == DecisionVerdict.notSuitable) {
      return 'Not suitable for this home';
    }
    if (a.foodCompatible == false) return 'Kitchen needs a check';
    if (a.smokingCompatible == false) return 'Smoking conflict';
    if (!a.affordabilityMeetsTarget) return 'Affordability review';
    if (a.lifestylePercent != null && a.lifestylePercent! >= 70) {
      return 'Lifestyle looks aligned';
    }
    if (a.viewingInvited) return 'Viewing already invited';
    return 'Household fit to review';
  }

  static String _entireSignal(Applicant a) {
    if (a.recommendation == LandlordRecommendationState.notSuitable ||
        a.verdict == DecisionVerdict.notSuitable) {
      return 'Not suitable for this home';
    }
    if (a.incomeVerified) return 'Verified income';
    if (a.employmentVerified) return 'Employment verified';
    if (!a.affordabilityMeetsTarget) return 'Affordability review';
    if (a.recommendation.name == 'timingConflict') return 'Timing conflict';
    if (a.viewingInvited) return 'Viewing already invited';
    if (a.guarantorLabel != null &&
        a.guarantorLabel!.toLowerCase().contains('no')) {
      return 'Guarantor review';
    }
    return 'Stability to confirm';
  }

  static (Color fg, Color bg) _verdictColors(DecisionVerdict v) =>
      switch (v) {
        DecisionVerdict.recommended => (
            LandlordDashboardTheme.readyInk,
            LandlordDashboardTheme.readyFill,
          ),
        DecisionVerdict.viewingInvited => (
            LandlordDashboardTheme.reviewInk,
            LandlordDashboardTheme.reviewFill,
          ),
        DecisionVerdict.needsReview => (
            LandlordDashboardTheme.timingInk,
            LandlordDashboardTheme.timingFill,
          ),
        DecisionVerdict.notSuitable => (
            LandlordDashboardTheme.declineInk,
            LandlordDashboardTheme.declineFill,
          ),
      };
}
