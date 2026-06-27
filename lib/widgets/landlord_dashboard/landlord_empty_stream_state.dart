import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' show AppColors;
import '../../core/widgets/app_button.dart';
import '../../theme/app_typography.dart';
import '../../utils/landlord_dashboard_helpers.dart';

class LandlordEmptyStreamState extends StatelessWidget {
  const LandlordEmptyStreamState({
    super.key,
    required this.listing,
    required this.onOptimizeListing,
  });

  final Map<String, dynamic> listing;
  final VoidCallback onOptimizeListing;

  @override
  Widget build(BuildContext context) {
    final category = LandlordDashboardHelpers.categoryForListing(listing);
    final tips = category.isShared
        ? const [
            'Add kitchen culture & spoken languages',
            'Describe your household vibe honestly',
            'Enable lifestyle match filters',
          ]
        : const [
            'Set a realistic target move-in date',
            'Clarify lease term expectations',
            'Verify your listing price band',
          ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              category.isShared ? Icons.nightlight_round : Icons.radar,
              size: 48,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your stream is quiet — for now',
            textAlign: TextAlign.center,
            style: AppTypography.sectionTitle().copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'No active applicants match your listing signals yet. '
            'Tweak a few variables and we\'ll accelerate marketplace discovery.',
            textAlign: TextAlign.center,
            style: AppTypography.detail().copyWith(
              color: const Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.bolt, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: AppTypography.detail().copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Optimize listing variables',
            icon: Icons.tune_rounded,
            onPressed: onOptimizeListing,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }
}
