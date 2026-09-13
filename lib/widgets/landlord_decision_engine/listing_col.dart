import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/landlord_engine_models.dart';
import '../landlord_dashboard/landlord_dashboard_theme.dart';

/// Col 1 — listings rail. “What property am I managing?”
class ListingCol extends StatelessWidget {
  const ListingCol({
    super.key,
    required this.listings,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<Listing> listings;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const double width = 236;

  @override
  Widget build(BuildContext context) {
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
            child: Text(
              '🏠  Listings',
              style: AppTypography.withEmojiFallback(
                LandlordDashboardTheme.railEyebrow(),
              ),
            ),
          ),
          Expanded(
            child: listings.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'No listings yet.',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 13,
                        color: LandlordDashboardTheme.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: listings.length,
                    itemBuilder: (context, index) {
                      final listing = listings[index];
                      return _ListingTile(
                        listing: listing,
                        selected: index == selectedIndex,
                        onTap: () => onSelected(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ListingTile extends StatelessWidget {
  const _ListingTile({
    required this.listing,
    required this.selected,
    required this.onTap,
  });

  final Listing listing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = listing.subtitle?.isNotEmpty == true
        ? listing.subtitle!
        : listing.type.label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? LandlordDashboardTheme.selectionFill
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 12, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left: BorderSide(
                  color: selected
                      ? LandlordDashboardTheme.ink
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Icon(
                        selected ? Icons.circle : Icons.circle_outlined,
                        size: 9,
                        color: selected
                            ? LandlordDashboardTheme.ink
                            : LandlordDashboardTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              letterSpacing: -0.2,
                              color: LandlordDashboardTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${listing.type.emoji}  $subtitle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.withEmojiFallback(
                              const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: LandlordDashboardTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${listing.applicantCount} applicant'
                            '${listing.applicantCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: LandlordDashboardTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (selected && listing.applicantCount > 0) ...[
                  const SizedBox(height: 14),
                  _CohortLine(
                    color: LandlordDashboardTheme.readyInk,
                    label: '${listing.inviteReadyCount} Strong Fits',
                  ),
                  const SizedBox(height: 6),
                  _CohortLine(
                    color: LandlordDashboardTheme.reviewInk,
                    label: '${listing.reviewCount} Needs Review',
                  ),
                  const SizedBox(height: 6),
                  _CohortLine(
                    color: LandlordDashboardTheme.declineInk,
                    label: '${listing.notSuitableCount} Not Suitable',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CohortLine extends StatelessWidget {
  const _CohortLine({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
