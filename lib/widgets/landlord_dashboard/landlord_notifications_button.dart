import 'package:flutter/material.dart';

import '../../models/host_conversation_notification.dart';
import '../../screens/application_conversation_screen.dart';
import '../../services/application_conversation_service.dart';
import '../../services/auth_service.dart';
import 'landlord_dashboard_theme.dart';

/// Landlord header bell — unread seeker conversation messages.
class LandlordNotificationsButton extends StatefulWidget {
  const LandlordNotificationsButton({
    super.key,
    this.ownedListingIds = const {},
  });

  final Set<String> ownedListingIds;

  @override
  State<LandlordNotificationsButton> createState() =>
      _LandlordNotificationsButtonState();
}

class _LandlordNotificationsButtonState
    extends State<LandlordNotificationsButton> {
  final _menuController = MenuController();
  List<HostConversationNotification> _items = const [];
  bool _loadingPanel = false;

  String get _hostUserId => AuthService.identityUserId();

  int get _badgeCount => applicationConversationService.hostUnreadMessageTotal(
        hostUserId: _hostUserId,
        ownedListingIds: widget.ownedListingIds,
      );

  @override
  void initState() {
    super.initState();
    applicationConversationService.addListener(_onStoreChanged);
    _warm();
  }

  @override
  void dispose() {
    applicationConversationService.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {});
    if (_menuController.isOpen) {
      _reloadPanel();
    }
  }

  Future<void> _warm() async {
    await applicationConversationService.ensureLoaded();
    if (mounted) setState(() {});
  }

  Future<void> _reloadPanel() async {
    setState(() => _loadingPanel = true);
    final items =
        await applicationConversationService.hostUnreadNotificationsWithTitles(
      hostUserId: _hostUserId,
      ownedListingIds: widget.ownedListingIds,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loadingPanel = false;
    });
  }

  Future<void> _openConversation(HostConversationNotification item) async {
    _menuController.close();
    if (!mounted) return;
    await context.pushConversationFromNotification(item);
  }

  @override
  Widget build(BuildContext context) {
    final count = _badgeCount;
    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(-280, 4),
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(
          LandlordDashboardTheme.surfaceRaised,
        ),
        elevation: WidgetStateProperty.all(8),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: LandlordDashboardTheme.border),
          ),
        ),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
      ),
      menuChildren: [
        SizedBox(
          width: 340,
          child: _NotificationsPanel(
            loading: _loadingPanel,
            items: _items,
            onOpen: _openConversation,
          ),
        ),
      ],
      builder: (context, controller, child) {
        return IconButton(
          tooltip: count > 0
              ? 'Notifications ($count unread)'
              : 'Notifications',
          onPressed: () async {
            if (controller.isOpen) {
              controller.close();
              return;
            }
            await _reloadPanel();
            controller.open();
          },
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
            backgroundColor: LandlordDashboardTheme.accent,
            child: Icon(
              count > 0
                  ? Icons.notifications_rounded
                  : Icons.notifications_none_rounded,
              color: LandlordDashboardTheme.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel({
    required this.loading,
    required this.items,
    required this.onOpen,
  });

  final bool loading;
  final List<HostConversationNotification> items;
  final ValueChanged<HostConversationNotification> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text(
            'Messages',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: LandlordDashboardTheme.textPrimary,
            ),
          ),
        ),
        const Divider(height: 1, color: LandlordDashboardTheme.border),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 28),
            child: Text(
              'No unread seeker messages',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                color: LandlordDashboardTheme.textMuted,
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: LandlordDashboardTheme.border,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return _NotificationTile(
                  item: item,
                  onTap: () => onOpen(item),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  final HostConversationNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final listing = item.listingTitle.trim();
    final eyebrow = item.isNewConversation
        ? (listing.isEmpty ? 'New conversation' : 'New conversation · $listing')
        : (listing.isEmpty
            ? '${item.unreadCount} unread'
            : '$listing · ${item.unreadCount} unread');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.senderName,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: LandlordDashboardTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              eyebrow,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: LandlordDashboardTheme.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.messagePreview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: LandlordDashboardTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on BuildContext {
  Future<void> pushConversationFromNotification(
    HostConversationNotification item,
  ) async {
    final hostUserId = AuthService.identityUserId();
    await applicationConversationService.ensureConversation(
      applicationId: item.applicationId,
      listingId: item.listingId,
      applicantUserId: item.applicantUserId,
      hostUserId: hostUserId.isNotEmpty ? hostUserId : item.hostUserId,
    );
    if (!mounted) return;
    await ApplicationConversationScreen.openFromHostArgs(
      this,
      applicationId: item.applicationId,
      listingId: item.listingId,
      applicantUserId: item.applicantUserId,
      listingTitle: item.listingTitle,
      peerName: item.senderName,
    );
  }
}
