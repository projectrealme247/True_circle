import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' show AppColors;
import '../../theme/app_typography.dart';
import '../../theme/home_marketplace_theme.dart';
import '../../utils/profile_progress.dart';
import '../emoji_leading_row.dart';

/// In-memory session flag — survives route changes; cleared on app restart.
abstract final class HomeProfileCompletionBannerSession {
  static bool dismissed = false;
  static bool hostDismissed = false;

  static void reset() {
    dismissed = false;
    hostDismissed = false;
  }
}

/// Compact secondary prompt below search — profile completion for better matches.
class HomeProfileCompletionBanner extends StatelessWidget {
  const HomeProfileCompletionBanner({
    super.key,
    required this.percent,
    required this.onContinue,
    required this.onDismiss,
    this.audience = ProfileCompletionAudience.seeker,
  });

  final int percent;
  final VoidCallback onContinue;
  final VoidCallback onDismiss;
  final ProfileCompletionAudience audience;

  String get _title => switch (audience) {
        ProfileCompletionAudience.seeker =>
          percent > 0 ? 'Complete Profile ($percent%)' : 'Complete Profile',
        ProfileCompletionAudience.host =>
          percent > 0
              ? 'Complete Host Profile ($percent%)'
              : 'Complete Host Profile',
      };

  String get _subtitle => switch (audience) {
        ProfileCompletionAudience.seeker =>
          'Complete your profile for better matches.',
        ProfileCompletionAudience.host =>
          'Add contact details and listing basics to attract quality applicants.',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HomeMarketplaceTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          EmojiLeadingRow(
            emoji: audience == ProfileCompletionAudience.host ? '🏠' : '⚡',
            text: _title,
            style: AppTypography.cardTitle().copyWith(fontSize: 14),
            emojiFontSize: 14,
            emojiWidth: 20,
            gap: 6,
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _subtitle,
                  style: AppTypography.meta().copyWith(
                    color: AppColors.secondaryText,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  textStyle: AppTypography.meta().copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Continue'),
              ),
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.secondaryText,
                  textStyle: AppTypography.meta(),
                ),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
