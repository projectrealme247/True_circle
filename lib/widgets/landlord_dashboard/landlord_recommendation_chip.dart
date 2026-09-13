import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/landlord_recommendation_state.dart';
import 'landlord_dashboard_theme.dart';

/// Rich recommendation state — emoji + label (+ optional hint).
class LandlordRecommendationChip extends StatelessWidget {
  const LandlordRecommendationChip({
    super.key,
    required this.state,
    this.hero = false,
    this.showHint = false,
  });

  final LandlordRecommendationState state;
  final bool hero;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final visual = LandlordDashboardTheme.recommendationVisual(state);
    final padH = hero ? 18.0 : 12.0;
    final padV = hero ? 16.0 : 11.0;
    final emojiSize = hero ? 22.0 : 16.0;
    final labelSize = hero ? 18.0 : 14.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: visual.bg,
        borderRadius: BorderRadius.circular(hero ? 18 : 14),
        border: Border.all(color: visual.fg.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                state.emoji,
                style: TextStyle(
                  fontSize: emojiSize,
                  height: 1,
                  fontFamily: AppTypography.emojiFontFamily,
                  fontFamilyFallback: AppTypography.emojiFontFallback,
                ),
              ),
              SizedBox(width: hero ? 12 : 8),
              Expanded(
                child: Text(
                  state.label,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: labelSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                    color: visual.fg,
                  ),
                ),
              ),
            ],
          ),
          if (showHint) ...[
            SizedBox(height: hero ? 8 : 6),
            Padding(
              padding: EdgeInsets.only(left: emojiSize + (hero ? 12 : 8)),
              child: Text(
                state.hint,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: hero ? 14 : 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: visual.fg.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
