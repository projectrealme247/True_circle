import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/skeleton_placeholder.dart';
import '../../models/proximity_display_chip.dart';
import '../../utils/proximity_chip_keys.dart';
import '../../utils/proximity_display_builder.dart';
import 'listing_creation_primitives.dart';

/// Neighborhood profile proximity display for listing creation.
class UnifiedProximityDisplay extends StatelessWidget {
  const UnifiedProximityDisplay({
    super.key,
    required this.input,
    required this.showTier4,
    required this.onToggleTier4,
    this.enrichmentInFlight = false,
    this.resolved = false,
    this.editing = false,
    this.onToggleHide,
    this.onTogglePin,
    this.onAddCustom,
    this.onRemoveCustom,
  });

  final ProximityDisplayInput input;
  final bool showTier4;
  final VoidCallback onToggleTier4;
  final bool enrichmentInFlight;
  final bool resolved;
  final bool editing;
  final ValueChanged<String>? onToggleHide;
  final ValueChanged<String>? onTogglePin;
  final VoidCallback? onAddCustom;
  final ValueChanged<String>? onRemoveCustom;

  @override
  Widget build(BuildContext context) {
    final sections = ProximityDisplayBuilder.buildProfile(input);
    final outdoors = sections
        .where((section) => section.title == 'Outdoors & local')
        .toList();
    final primarySections = sections
        .where((section) => section.title != 'Outdoors & local')
        .toList();
    final hasOutdoors = outdoors.isNotEmpty;
    final hasPrimary = primarySections.isNotEmpty;

    if (!hasPrimary && !hasOutdoors) {
      if (enrichmentInFlight) {
        return const Phase2EnrichmentHint();
      }
      if (editing) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'No proximity chips yet — add a custom point or run auto-detect first.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            if (onAddCustom != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAddCustom,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add custom point'),
                ),
              ),
            ],
          ],
        );
      }
      if (resolved) {
        return Text(
          'No proximity details detected yet — tap ✏️ Edit Proximity to add a custom point.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        );
      }
      return Text(
        'Tap "Use current location" or type your Eircode to auto-detect, or add manually.',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
          height: 1.4,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < primarySections.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _ProfileSectionBlock(
            section: primarySections[i],
            editing: editing,
            onToggleHide: onToggleHide,
            onTogglePin: onTogglePin,
            onRemoveCustom: onRemoveCustom,
          ),
        ],
        if (hasOutdoors) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: onToggleTier4,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  showTier4 ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: const Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  showTier4
                      ? 'Hide outdoors & local'
                      : 'Outdoors & local (${outdoors.first.chips.length})',
                  style: listingFormHelperStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
          if (showTier4 || editing) ...[
            const SizedBox(height: 6),
            _ProfileSectionBlock(
              section: outdoors.first,
              subdued: !editing,
              editing: editing,
              onToggleHide: onToggleHide,
              onTogglePin: onTogglePin,
              onRemoveCustom: onRemoveCustom,
            ),
          ],
        ],
        if (editing && onAddCustom != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddCustom,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('➕ Add custom proximity point'),
            ),
          ),
        ],
        if (enrichmentInFlight) ...[
          const SizedBox(height: 8),
          const Phase2EnrichmentHint(),
        ],
      ],
    );
  }
}

class _ProfileSectionBlock extends StatelessWidget {
  const _ProfileSectionBlock({
    required this.section,
    this.subdued = false,
    this.editing = false,
    this.onToggleHide,
    this.onTogglePin,
    this.onRemoveCustom,
  });

  final ProximityProfileSection section;
  final bool subdued;
  final bool editing;
  final ValueChanged<String>? onToggleHide;
  final ValueChanged<String>? onTogglePin;
  final ValueChanged<String>? onRemoveCustom;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              section.icon,
              size: 16,
              color: subdued
                  ? const Color(0xFF6B7280)
                  : AppColors.accentDark,
            ),
            const SizedBox(width: 6),
            Text(
              section.title,
              style: listingFormHelperStyle.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final chip in section.chips)
              _ProximityTierChip(
                chip: chip,
                subdued: subdued || chip.isHidden,
                editing: editing,
                onToggleHide: onToggleHide,
                onTogglePin: onTogglePin,
                onRemoveCustom: section.title == 'Custom' ? onRemoveCustom : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _ProximityTierChip extends StatelessWidget {
  const _ProximityTierChip({
    required this.chip,
    this.subdued = false,
    this.editing = false,
    this.onToggleHide,
    this.onTogglePin,
    this.onRemoveCustom,
  });

  final ProximityDisplayChip chip;
  final bool subdued;
  final bool editing;
  final ValueChanged<String>? onToggleHide;
  final ValueChanged<String>? onTogglePin;
  final ValueChanged<String>? onRemoveCustom;

  String get _prefKey => ProximityChipKeys.fromChip(
        category: chip.chipCategory,
        matchName: chip.matchName,
        label: chip.label,
      );

  @override
  Widget build(BuildContext context) {
    final accent = chip.isPinned
        ? AppColors.accentDark
        : subdued
            ? const Color(0xFF6B7280)
            : AppColors.accentDark;
    final background = chip.isHidden
        ? const Color(0xFFF3F4F6)
        : chip.isPinned
            ? AppColors.accent.withValues(alpha: 0.16)
            : subdued
                ? const Color(0xFFF3F4F6)
                : AppColors.accent.withValues(alpha: 0.08);
    final border = chip.isPinned
        ? AppColors.accentDark
        : subdued
            ? const Color(0xFFE5E7EB)
            : AppColors.accent.withValues(alpha: 0.25);

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: editing ? 6 : 12,
        top: editing ? 6 : 8,
        bottom: editing ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            chip.isPinned ? Icons.push_pin : chip.icon,
            size: 16,
            color: accent,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              chip.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: subdued || chip.isHidden
                    ? FontWeight.w500
                    : FontWeight.w600,
                color: chip.isHidden
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF374151),
                decoration:
                    chip.isHidden ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (editing) ...[
            const SizedBox(width: 4),
            _ChipActionButton(
              tooltip: chip.isHidden ? 'Show' : 'Hide',
              icon: chip.isHidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              active: chip.isHidden,
              onPressed: _prefKey.isEmpty || onToggleHide == null
                  ? null
                  : () => onToggleHide!(_prefKey),
            ),
            _ChipActionButton(
              tooltip: chip.isPinned ? 'Unpin' : 'Pin',
              icon: Icons.push_pin_outlined,
              active: chip.isPinned,
              onPressed: _prefKey.isEmpty || onTogglePin == null
                  ? null
                  : () => onTogglePin!(_prefKey),
            ),
            if (onRemoveCustom != null)
              _ChipActionButton(
                tooltip: 'Remove',
                icon: Icons.close,
                active: false,
                onPressed: () => onRemoveCustom!(_prefKey),
              ),
          ],
        ],
      ),
    );
  }
}

class _ChipActionButton extends StatelessWidget {
  const _ChipActionButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      iconSize: 16,
      icon: Icon(
        icon,
        color: active ? AppColors.accentDark : const Color(0xFF6B7280),
      ),
    );
  }
}
