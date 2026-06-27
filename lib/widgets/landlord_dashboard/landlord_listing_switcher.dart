import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' show AppColors;
import '../../theme/app_typography.dart';
import '../../utils/landlord_dashboard_helpers.dart';

class LandlordListingSwitcher extends StatelessWidget {
  const LandlordListingSwitcher({
    super.key,
    required this.listings,
    required this.selectedIndex,
    required this.pageController,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> listings;
  final int selectedIndex;
  final PageController pageController;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Active listings',
            style: AppTypography.meta().copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(LandlordDashboardTokens.unselectedGrey),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final listing = listings[index];
              final selected = index == selectedIndex;
              final category = LandlordDashboardHelpers.categoryForListing(listing);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Material(
                    color: selected ? AppColors.accent : AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    elevation: selected ? 2 : 0,
                    shadowColor: AppColors.accent.withValues(alpha: 0.35),
                    child: InkWell(
                      onTap: () {
                        onSelected(index);
                        pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? AppColors.accent
                                : const Color(LandlordDashboardTokens.unselectedGrey)
                                    .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              category.isShared
                                  ? Icons.groups_2_outlined
                                  : Icons.home_work_outlined,
                              size: 16,
                              color: selected
                                  ? Colors.white
                                  : const Color(LandlordDashboardTokens.unselectedGrey),
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                LandlordDashboardHelpers.listingTitle(listing),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.primaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
