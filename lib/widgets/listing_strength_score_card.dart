import 'package:flutter/material.dart';

import '../utils/listing_strength_calculator.dart';
import 'listing_detail_tokens.dart';

/// Gamified listing completeness card above property highlights.
class ListingStrengthScoreCard extends StatelessWidget {
  const ListingStrengthScoreCard({
    super.key,
    required this.snapshot,
  });

  final ListingStrengthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final progress = snapshot.scorePercent / 100;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: const Color(0xFFDBEAFE),
                  color: const Color(0xFF2563EB),
                ),
                Text(
                  '${snapshot.scorePercent}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.statusTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  snapshot.statusSubtitle,
                  style: ListingDetailTokens.deposit.copyWith(
                    fontSize: 12,
                    height: 1.45,
                    color: const Color(0xFF475569),
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
