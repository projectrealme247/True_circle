import 'package:flutter/material.dart';

import '../../services/active_mode_service.dart';
import '../../theme/app_typography.dart';
import '../../core/theme/app_theme.dart' show AppColors;

/// Persistent Explore | Hosting switch with cross-mode unread badges.
class ActiveModeSwitch extends StatelessWidget {
  const ActiveModeSwitch({
    super.key,
    required this.current,
    required this.unread,
    required this.canSeek,
    required this.canHost,
    required this.onModeSelected,
    this.compact = false,
  });

  final ActiveMode current;
  final UnreadActivity unread;
  final bool canSeek;
  final bool canHost;
  final ValueChanged<ActiveMode> onModeSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!canSeek && !canHost) return const SizedBox.shrink();
    if (canSeek && !canHost) return const SizedBox.shrink();

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
                label: compact ? 'Explore' : 'Explore',
                selected: current == ActiveMode.explore,
                badgeCount: current == ActiveMode.hosting
                    ? unread.seekerBadgeCount
                    : 0,
                onTap: () => onModeSelected(ActiveMode.explore),
              ),
            if (canSeek && canHost) const SizedBox(width: 2),
            if (canHost)
              _Segment(
                label: compact ? 'Hosting' : 'Hosting',
                selected: current == ActiveMode.hosting,
                badgeCount: current == ActiveMode.explore
                    ? unread.hostBadgeCount
                    : 0,
                onTap: () => onModeSelected(ActiveMode.hosting),
              ),
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
  });

  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
