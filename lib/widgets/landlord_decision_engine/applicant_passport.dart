import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/applicant_trust_tier.dart';
import '../../models/landlord_engine_models.dart';
import '../landlord_dashboard/landlord_dashboard_theme.dart';

const _kPositiveGreen = Color(0xFF0F6E56);
const _kProofTint = Color(0xFFE8F5EE);

/// Compact landlord-facing Applicant Passport for Col 3.
///
/// Same green block slot as the former Proof of Trust section —
/// layout frozen; content only.
class ApplicantPassport extends StatelessWidget {
  const ApplicantPassport({
    super.key,
    required this.applicant,
    required this.listingType,
    required this.compact,
  });

  final Applicant applicant;
  final ListingType listingType;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rows = _rows(applicant, listingType);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kProofTint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Applicant Passport',
            style: LandlordDashboardTheme.railEyebrow().copyWith(
              fontSize: compact ? 10 : 11,
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: compact ? 4 : 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rows[i].prefix,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: rows[i].emphasis
                        ? _kPositiveGreen
                        : LandlordDashboardTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rows[i].text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: compact ? 12.5 : 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: LandlordDashboardTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static List<_PassportRow> _rows(Applicant a, ListingType type) {
    final verified = a.employmentVerified;
    final out = <_PassportRow>[
      _PassportRow(
        '✓',
        verified
            ? ApplicantTrustTier.verifiedUserLabel
            : 'Verification pending',
        emphasis: verified,
      ),
      _PassportRow(
        a.employmentVerified ? '✓' : '·',
        a.employmentVerified ? 'Employment verified' : 'Employment open',
        emphasis: a.employmentVerified,
      ),
      _PassportRow(
        a.incomeVerified ? '✓' : '·',
        a.incomeVerified ? 'Income verified' : 'Income verification open',
        emphasis: a.incomeVerified,
      ),
    ];

    if (a.languages.isNotEmpty) {
      out.add(
        _PassportRow('·', 'Languages: ${a.languages.take(3).join(', ')}'),
      );
    }

    if (type.isShared) {
      if (a.householdLabel != null && a.householdLabel!.trim().isNotEmpty) {
        out.add(_PassportRow('·', a.householdLabel!.trim()));
      }
      if (a.commuteLabel != null && a.commuteLabel!.trim().isNotEmpty) {
        out.add(_PassportRow('·', 'Commute: ${a.commuteLabel!.trim()}'));
      }
    } else {
      if (a.householdLabel != null && a.householdLabel!.trim().isNotEmpty) {
        out.add(_PassportRow('·', 'Household: ${a.householdLabel!.trim()}'));
      }
      if (a.stabilityBullet != null && a.stabilityBullet!.trim().isNotEmpty) {
        out.add(_PassportRow('·', a.stabilityBullet!.trim()));
      }
    }

    // Cap rows so the frozen Col 3 card stays compact.
    if (out.length > 6) return out.take(6).toList();
    return out;
  }
}

class _PassportRow {
  const _PassportRow(this.prefix, this.text, {this.emphasis = false});
  final String prefix;
  final String text;
  final bool emphasis;
}
