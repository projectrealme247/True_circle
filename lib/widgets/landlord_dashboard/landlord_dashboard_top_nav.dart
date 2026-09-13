import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../truecircle_logo.dart';
import 'landlord_dashboard_theme.dart';
import 'landlord_notifications_button.dart';

/// Minimal landlord chrome — logo + primary destinations outside the workspace.
class LandlordDashboardTopNav extends StatelessWidget
    implements PreferredSizeWidget {
  const LandlordDashboardTopNav({
    super.key,
    this.leadingNav,
    this.trailing,
    this.onRefresh,
    this.onAddListing,
    this.onEditListing,
    this.onDeleteListing,
    this.onLogout,
    this.ownedListingIds = const {},
  });

  final Widget? leadingNav;
  final Widget? trailing;
  final VoidCallback? onRefresh;
  final VoidCallback? onAddListing;
  final VoidCallback? onEditListing;
  final VoidCallback? onDeleteListing;
  final VoidCallback? onLogout;
  final Set<String> ownedListingIds;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final path = GoRouter.of(context).state.uri.path;

    return Material(
      color: LandlordDashboardTheme.surfaceRaised,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 63,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.go('/'),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TrueCircleLogo.appBarMark(size: 28),
                          SizedBox(width: 10),
                          Text(
                            'TrueCircle',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: LandlordDashboardTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (leadingNav != null) ...[
                    const SizedBox(width: 24),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: leadingNav!,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 16),
                  _NavLink(
                    label: 'Dashboard',
                    selected: path.contains('landlord-dashboard') ||
                        path.contains('/manage'),
                    onTap: () => context.go('/landlord-dashboard'),
                  ),
                  if (onAddListing != null) ...[
                    const SizedBox(width: 4),
                    _NavLink(
                      label: '+ Add Listing',
                      selected: false,
                      onTap: onAddListing!,
                    ),
                  ],
                  if (onEditListing != null) ...[
                    const SizedBox(width: 4),
                    _NavLink(
                      label: '✏️ Edit Listing',
                      selected: false,
                      onTap: onEditListing!,
                    ),
                  ],
                  if (onDeleteListing != null) ...[
                    const SizedBox(width: 4),
                    _NavLink(
                      label: 'Delete Listing',
                      selected: false,
                      onTap: onDeleteListing!,
                      color: LandlordDashboardTheme.declineInk,
                    ),
                  ],
                  const Spacer(),
                  LandlordNotificationsButton(
                    ownedListingIds: ownedListingIds,
                  ),
                  if (onRefresh != null)
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      color: LandlordDashboardTheme.textSecondary,
                    ),
                  if (onLogout != null)
                    TextButton(
                      onPressed: onLogout,
                      style: TextButton.styleFrom(
                        foregroundColor: LandlordDashboardTheme.textSecondary,
                      ),
                      child: const Text('Logout'),
                    ),
                  if (trailing != null) ...[
                    const SizedBox(width: 4),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
          Container(height: 1, color: LandlordDashboardTheme.border),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ??
        (selected
            ? LandlordDashboardTheme.ink
            : LandlordDashboardTheme.textSecondary);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: resolved,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
