import 'package:flutter/material.dart';

import '../../utils/landlord_dashboard_helpers.dart';
import 'landlord_dashboard_theme.dart';

class LandlordListingRailItem {
  const LandlordListingRailItem({
    required this.listing,
    required this.applicantCount,
    this.inviteReadyCount = 0,
    this.reviewCount = 0,
    this.notSuitableCount = 0,
  });

  final Map<String, dynamic> listing;
  final int applicantCount;
  final int inviteReadyCount;
  final int reviewCount;
  final int notSuitableCount;
}

/// Column 1 — compact listings rail.
class LandlordListingsRail extends StatelessWidget {
  const LandlordListingsRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<LandlordListingRailItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
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
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
            child: Text(
              'Listings',
              style: LandlordDashboardTheme.railEyebrow(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _ListingRailTile(
                  item: item,
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

class _ListingRailTile extends StatelessWidget {
  const _ListingRailTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final LandlordListingRailItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = LandlordDashboardHelpers.listingTitle(item.listing);
    final waiting = item.applicantCount;
    final waitingLabel =
        waiting == 1 ? '1 waiting' : '$waiting waiting';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? LandlordDashboardTheme.selectionFill
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
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
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: LandlordDashboardTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  waitingLabel,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: LandlordDashboardTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
