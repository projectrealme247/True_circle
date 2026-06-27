import 'package:flutter/material.dart';

import '../services/commute_scoring_service.dart';
import '../utils/listing_commute_display.dart';
import 'listing_detail_tokens.dart';

/// Inline transit banner for listing detail — soft tint, single-baseline scan.
class CommuteScoreBadge extends StatelessWidget {
  const CommuteScoreBadge({
    super.key,
    required this.display,
  });

  final MultiCommuteDisplayModel display;

  static const _bannerFill = Color(0xFFE8EEF5);
  static const _bannerBorder = Color(0xFFD5DEEA);
  static const _iconColor = Color(0xFF64748B);
  static const _mutedColor = Color(0xFF94A3B8);
  static const _warningColor = Color(0xFFB45309);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < display.rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _InlineTransitBannerRow(
            row: display.rows[i],
            isPersonalized: display.isPersonalized,
            showCommuterLabel: display.rows.length > 1,
          ),
        ],
        if (display.subtitle != null && display.subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            display.subtitle!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _mutedColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _InlineTransitBannerRow extends StatelessWidget {
  const _InlineTransitBannerRow({
    required this.row,
    required this.isPersonalized,
    required this.showCommuterLabel,
  });

  final CommuteDisplayRow row;
  final bool isPersonalized;
  final bool showCommuterLabel;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForRow(row, isPersonalized);
    final isWarning = row.exceedsBudget || row.parkingWarning != null;
    final identity = _transitIdentity(row);
    final timeLabel = _timeLabel(row);

    return Semantics(
      label: 'Transit for ${row.commuterLabel}: ${row.headline}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isWarning
              ? const Color(0xFFFFF7ED)
              : CommuteScoreBadge._bannerFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isWarning
                ? const Color(0xFFFED7AA)
                : CommuteScoreBadge._bannerBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showCommuterLabel) ...[
              Text(
                row.commuterLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: isWarning
                      ? CommuteScoreBadge._warningColor
                      : CommuteScoreBadge._iconColor,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isWarning
                      ? CommuteScoreBadge._warningColor
                      : CommuteScoreBadge._iconColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _transitLineLabel(
                      identity: identity,
                      timeLabel: timeLabel,
                      isPersonalized: isPersonalized,
                      showCommuterLabel: showCommuterLabel,
                      exceedsBudget: row.exceedsBudget,
                    ),
                    style: ListingDetailTokens.highlightMeta.copyWith(
                      color: isWarning
                          ? CommuteScoreBadge._warningColor
                          : ListingDetailTokens.highlightMeta.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (row.parkingWarning != null) ...[
              const SizedBox(height: 8),
              Text(
                row.parkingWarning!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CommuteScoreBadge._warningColor,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _transitIdentity(CommuteDisplayRow row) {
    final headline = row.headline.trim();
    if (headline.isEmpty) return row.commuterLabel;

    final walkTo = RegExp(
      r'walk to (.+)$',
      caseSensitive: false,
    ).firstMatch(headline);
    if (walkTo != null) return walkTo.group(1)!.trim();

    final minsTo = RegExp(
      r'mins to (.+)$',
      caseSensitive: false,
    ).firstMatch(headline);
    if (minsTo != null) return minsTo.group(1)!.trim();

    if (row.exceedsBudget) return 'Commute';
    return headline;
  }

  static String _transitLineLabel({
    required String identity,
    required String timeLabel,
    required bool isPersonalized,
    required bool showCommuterLabel,
    required bool exceedsBudget,
  }) {
    final buffer = StringBuffer('$identity · $timeLabel');
    if (isPersonalized && !showCommuterLabel && !exceedsBudget) {
      buffer.write(' · For you');
    }
    return buffer.toString();
  }

  static String _timeLabel(CommuteDisplayRow row) {
    final headline = row.headline.toLowerCase();
    if (headline.contains('walk')) return '${row.minutes} min walk';
    if (row.commuteMethod == CommuteMethod.driving) {
      return '${row.minutes} min drive';
    }
    return '${row.minutes} mins';
  }

  static IconData _iconForRow(CommuteDisplayRow row, bool isPersonalized) {
    if (!isPersonalized) return Icons.directions_transit_outlined;
    return switch (row.commuteMethod) {
      CommuteMethod.driving => Icons.directions_car_outlined,
      CommuteMethod.publicTransportWalking => Icons.directions_transit_outlined,
      null => Icons.directions_transit_outlined,
    };
  }
}
