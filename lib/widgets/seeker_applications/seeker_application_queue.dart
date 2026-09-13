import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' as core show AppTypography;
import '../../theme/app_typography.dart';
import '../../theme/home_marketplace_theme.dart';
import 'seeker_application_queue_item.dart';

/// Column 2 — compact application queue.
class SeekerApplicationQueue extends StatelessWidget {
  const SeekerApplicationQueue({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    this.sectionLabel = '',
  });

  final List<SeekerApplicationQueueItem> items;
  final String? selectedId;
  final ValueChanged<SeekerApplicationQueueItem> onSelect;
  final String sectionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: HomeMarketplaceTheme.surface,
        border: Border(
          right: BorderSide(color: HomeMarketplaceTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sectionLabel.isEmpty ? 'APPLICATIONS' : sectionLabel,
                    style: core.AppTypography.withEmojiFallback(
                      AppTypography.sectionMeta().copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${items.length}',
                  style: AppTypography.detail().copyWith(
                    fontWeight: FontWeight.w700,
                    color: HomeMarketplaceTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No applications in this section.',
                        textAlign: TextAlign.center,
                        style: AppTypography.detail().copyWith(
                          color: HomeMarketplaceTheme.textSecondary,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _QueueRow(
                        item: item,
                        selected: item.applicationId == selectedId,
                        onTap: () => onSelect(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SeekerApplicationQueueItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? HomeMarketplaceTheme.accentSurface.withValues(alpha: 0.35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: selected
                      ? HomeMarketplaceTheme.primary
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.propertyTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle().copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.locationLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '📍 ${item.locationLabel}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.detail().copyWith(
                      fontSize: 11,
                      color: HomeMarketplaceTheme.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
                if (item.rentLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '💰 ${item.rentLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.detail().copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  item.statusLabel,
                  style: core.AppTypography.withEmojiFallback(
                    AppTypography.detail().copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (item.queueActivityLine.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.queueActivityLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: core.AppTypography.withEmojiFallback(
                      AppTypography.detail().copyWith(
                        fontSize: 12,
                        color: HomeMarketplaceTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  item.appliedLabel,
                  style: AppTypography.detail().copyWith(
                    fontSize: 11,
                    color: HomeMarketplaceTheme.textMuted,
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
