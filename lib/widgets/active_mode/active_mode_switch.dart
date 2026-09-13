import 'package:flutter/material.dart';

import '../../services/active_mode_service.dart';
import '../../theme/app_typography.dart';
import '../../core/theme/app_theme.dart' show AppColors;

/// Persistent Explore | Hosting | Applications switch with cross-mode badges.
class ActiveModeSwitch extends StatelessWidget {
  const ActiveModeSwitch({
    super.key,
    required this.current,
    required this.unread,
    required this.canSeek,
    required this.canHost,
    required this.onModeSelected,
    this.compact = false,
    this.applicationsSelected = false,
    this.applicationsCount = 0,
    this.onApplicationsSelected,
  });

  final ActiveMode current;
  final UnreadActivity unread;
  final bool canSeek;
  final bool canHost;
  final ValueChanged<ActiveMode> onModeSelected;
  final bool compact;
  final bool applicationsSelected;
  final int applicationsCount;
  final VoidCallback? onApplicationsSelected;

  static String applicationsLabel(int count) {
    if (count <= 0) return 'Applications';
    return 'Applications ($count)';
  }

  @override
  Widget build(BuildContext context) {
    final showApplications = onApplicationsSelected != null && canSeek;
    if (!canSeek && !canHost) return const SizedBox.shrink();
    if (!showApplications && canSeek && !canHost) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canSeek)
              _Segment(
                label: 'Explore',
                selected:
                    !applicationsSelected && current == ActiveMode.explore,
                badgeCount: !applicationsSelected &&
                        current == ActiveMode.hosting
                    ? unread.seekerBadgeCount
                    : 0,
                compact: compact,
                onTap: () => onModeSelected(ActiveMode.explore),
              ),
            if (canSeek && canHost) const SizedBox(width: 2),
            if (canHost)
              _Segment(
                label: 'Hosting',
                selected:
                    !applicationsSelected && current == ActiveMode.hosting,
                badgeCount: !applicationsSelected &&
                        current == ActiveMode.explore
                    ? unread.hostBadgeCount
                    : 0,
                compact: compact,
                onTap: () => onModeSelected(ActiveMode.hosting),
              ),
            if (showApplications) ...[
              if (canSeek || canHost) const SizedBox(width: 2),
              _Segment(
                label: applicationsLabel(applicationsCount),
                selected: applicationsSelected,
                badgeCount: 0,
                compact: compact,
                onTap: onApplicationsSelected!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 5 : 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.meta().copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.primaryText
                      : AppColors.secondaryText,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                _Badge(count: badgeCount),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.meta().copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}
