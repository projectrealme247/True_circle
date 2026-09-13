import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' as core show AppTypography;
import '../../theme/app_typography.dart';
import '../../theme/home_marketplace_theme.dart';
import '../../utils/seeker_application_pipeline.dart';

/// Column 1 — seeker application groups.
class SeekerPipelineColumn extends StatelessWidget {
  const SeekerPipelineColumn({
    super.key,
    required this.buckets,
    required this.selected,
    required this.onSelected,
    required this.rejectedExpanded,
    required this.onRejectedExpandedChanged,
  });

  final SeekerPipelineBuckets buckets;
  final SeekerPipelineSection selected;
  final ValueChanged<SeekerPipelineSection> onSelected;
  final bool rejectedExpanded;
  final ValueChanged<bool> onRejectedExpandedChanged;

  static const _primarySections = [
    SeekerPipelineSection.inProgress,
    SeekerPipelineSection.waitingForHost,
  ];

  @override
  Widget build(BuildContext context) {
    final rejectedCount = buckets.countFor(SeekerPipelineSection.rejected);

    return Container(
      width: 200,
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
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: Text(
              'APPLICATIONS',
              style: AppTypography.sectionMeta().copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
              children: [
                for (final section in _primarySections)
                  _PipelineRow(
                    label: section.label,
                    count: buckets.countFor(section),
                    selected: selected == section,
                    onTap: () => onSelected(section),
                  ),
                _RejectedPipelineRow(
                  label: SeekerPipelineSection.rejected.label,
                  count: rejectedCount,
                  selected: selected == SeekerPipelineSection.rejected,
                  expanded: rejectedExpanded,
                  onToggleExpanded: () {
                    final next = !rejectedExpanded;
                    onRejectedExpandedChanged(next);
                    if (next) onSelected(SeekerPipelineSection.rejected);
                  },
                  onSelect: () => onSelected(SeekerPipelineSection.rejected),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineRow extends StatelessWidget {
  const _PipelineRow({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? HomeMarketplaceTheme.accentSurface
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
                      ? HomeMarketplaceTheme.primary
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: core.AppTypography.withEmojiFallback(
                      AppTypography.detail().copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                Text(
                  '($count)',
                  style: AppTypography.detail().copyWith(
                    fontWeight: FontWeight.w700,
                    color: HomeMarketplaceTheme.textSecondary,
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

class _RejectedPipelineRow extends StatelessWidget {
  const _RejectedPipelineRow({
    required this.label,
    required this.count,
    required this.selected,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSelect,
  });

  final String label;
  final int count;
  final bool selected;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected && expanded
            ? HomeMarketplaceTheme.accentSurface
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: expanded ? onSelect : onToggleExpanded,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: selected && expanded
                      ? HomeMarketplaceTheme.primary
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: core.AppTypography.withEmojiFallback(
                      AppTypography.detail().copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                Text(
                  '($count)',
                  style: AppTypography.detail().copyWith(
                    fontWeight: FontWeight.w700,
                    color: HomeMarketplaceTheme.textSecondary,
                  ),
                ),
                InkWell(
                  onTap: onToggleExpanded,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: HomeMarketplaceTheme.textMuted,
                    ),
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
