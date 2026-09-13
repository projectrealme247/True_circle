import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/marketplace_space.dart';
import '../utils/listing_data.dart';
import '../utils/listing_property_highlights.dart';
import '../utils/neighbourhood_highlights.dart';
import 'listing_detail_commute_section.dart';
import 'listing_detail_tokens.dart';
import 'listing_photo_gallery.dart';

/// Dual-column (desktop) / stacked (mobile) listing detail layout.
class ListingDetailPageLayout extends StatelessWidget {
  const ListingDetailPageLayout({
    super.key,
    required this.item,
    required this.userSession,
    required this.space,
    required this.hasApplied,
    this.applicationStateLabel,
    required this.isOwned,
    required this.displayPrice,
    required this.displayTitle,
    required this.formatHighlightLabel,
    required this.depositLabel,
    required this.mediaExtras,
    required this.onPitch,
    required this.onManage,
    required this.onStartReplacement,
    required this.onEdit,
    required this.matchChips,
    this.preferenceFitLabels = const [],
    this.listedOnLabel = '',
  });

  final Map<String, dynamic> item;
  final Map<String, dynamic>? userSession;
  final MarketplaceSpace space;
  final bool hasApplied;
  /// When set, replaces the Pitch CTA with a disabled lifecycle state label.
  final String? applicationStateLabel;
  final bool isOwned;
  final String displayPrice;
  final String displayTitle;
  final String Function(String) formatHighlightLabel;
  final String? depositLabel;
  final List<Widget> mediaExtras;
  final VoidCallback onPitch;
  final VoidCallback onManage;
  final VoidCallback onStartReplacement;
  final VoidCallback onEdit;
  final List<Widget> matchChips;
  /// Independent Places preference-fit labels (max 3) — rendered like Property Highlights.
  final List<String> preferenceFitLabels;
  /// Freshness Phase 1 — e.g. `Listed on 25 Aug 2026`; empty when unknown.
  final String listedOnLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= ListingDetailTokens.desktopBreakpoint;
        final viewportHeight = constraints.maxHeight;

        final story = _StoryColumn(
          item: item,
          userSession: userSession,
          space: space,
          mediaExtras: mediaExtras,
          matchChips: matchChips,
          preferenceFitLabels: preferenceFitLabels,
          displayTitle: displayTitle,
          formatHighlightLabel: formatHighlightLabel,
          listedOnLabel: listedOnLabel,
          isOwned: isOwned,
          onEdit: onEdit,
        );

        final panel = _ActionDashboardPanel(
          item: item,
          space: space,
          hasApplied: hasApplied,
          applicationStateLabel: applicationStateLabel,
          isOwned: isOwned,
          displayPrice: displayPrice,
          depositLabel: depositLabel,
          onPitch: onPitch,
          onManage: onManage,
          onStartReplacement: onStartReplacement,
          onEdit: onEdit,
          showHostBlock: false,
        );

        if (isWide) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ListingDetailTokens.maxContentWidth,
                maxHeight: viewportHeight,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: story),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 20, 24),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: panel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: story),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: ListingDetailTokens.surface,
                border: Border(top: BorderSide(color: ListingDetailTokens.border)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: panel,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StoryColumn extends StatelessWidget {
  const _StoryColumn({
    required this.item,
    required this.userSession,
    required this.space,
    required this.mediaExtras,
    required this.matchChips,
    required this.preferenceFitLabels,
    required this.displayTitle,
    required this.formatHighlightLabel,
    required this.listedOnLabel,
    required this.isOwned,
    required this.onEdit,
  });

  final Map<String, dynamic> item;
  final Map<String, dynamic>? userSession;
  final MarketplaceSpace space;
  final List<Widget> mediaExtras;
  final List<Widget> matchChips;
  final List<String> preferenceFitLabels;
  final String displayTitle;
  final String Function(String) formatHighlightLabel;
  final String listedOnLabel;
  final bool isOwned;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final description = ListingData.description(item);
    final location = ListingData.location(item);
    final isShare = space == MarketplaceSpace.sharedSpace;
    final imageHeight = isShare ? 240.0 : 280.0;

    if (isShare) {
      return _buildSharedStory(
        description: description,
        location: location,
        imageHeight: imageHeight,
      );
    }

    return _buildIndependentPlaceStory(
      description: description,
      location: location,
      imageHeight: imageHeight,
    );
  }

  Widget _buildSharedStory({
    required String description,
    required String location,
    required double imageHeight,
  }) {
    final roomCells =
        ListingPropertyHighlights.sharedLivingRoomSnapshotCells(item);
    final householdCells =
        ListingPropertyHighlights.sharedLivingHouseholdSnapshotCells(item);
    final cultureCells =
        ListingPropertyHighlights.sharedLivingCultureCells(item);
    final propertyCells =
        ListingPropertyHighlights.sharedLivingPropertyDetailCells(item);
    final preferenceReasons = preferenceFitLabels.take(3).toList();
    final hostName = ListingData.hostName(item);
    final hostCity = ListingData.hostCity(item);
    final hostLanguage = ListingData.hostLanguage(item);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListingPhotoGallery(
            listing: item,
            height: imageHeight,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            showQuickEdit: isOwned,
            onQuickEdit: onEdit,
          ),
          const SizedBox(height: 20),
          Text(
            displayTitle,
            style: ListingDetailTokens.heroTitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(location, style: ListingDetailTokens.locationSubtitle),
          ],
          if (listedOnLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(listedOnLabel, style: ListingDetailTokens.locationSubtitle),
          ],
          if (roomCells.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionLabel(text: 'ROOM SNAPSHOT'),
            const SizedBox(height: 10),
            _FeatureMatrixGrid(
              cells: roomCells,
              // Keep emoji-led snapshot labels exact (no title-case rewrite).
              formatHighlightLabel: (label) => label,
            ),
          ],
          if (preferenceReasons.isNotEmpty) ...[
            const SizedBox(height: 20),
            _PreferenceInsightCard(reasons: preferenceReasons),
          ],
          if (householdCells.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionLabel(text: 'HOUSEHOLD SNAPSHOT'),
            const SizedBox(height: 10),
            _FeatureMatrixGrid(
              cells: householdCells,
              formatHighlightLabel: formatHighlightLabel,
            ),
          ],
          if (cultureCells.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionLabel(text: 'HOUSEHOLD CULTURE'),
            const SizedBox(height: 10),
            _FeatureMatrixGrid(
              cells: cultureCells,
              formatHighlightLabel: formatHighlightLabel,
            ),
          ],
          const SizedBox(height: 18),
          ListingDetailCommuteSection(
            listing: item,
            userSession: userSession,
          ),
          if (NeighbourhoodHighlights.groupedForDetail(item).isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SectionLabel(text: 'NEIGHBOURHOOD HIGHLIGHTS'),
            const SizedBox(height: 12),
            _NeighbourhoodHighlightsBlock(listing: item),
          ],
          if (propertyCells.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SectionLabel(text: 'PROPERTY DETAILS'),
            const SizedBox(height: 10),
            _FeatureMatrixGrid(
              cells: propertyCells,
              formatHighlightLabel: formatHighlightLabel,
            ),
          ],
          const SizedBox(height: 22),
          const _SectionLabel(text: 'DESCRIPTION'),
          const SizedBox(height: 8),
          Text(
            description.isEmpty ? 'No description provided.' : description,
            style: ListingDetailTokens.body,
          ),
          const SizedBox(height: 22),
          _HostBlock(
            hostName: hostName,
            hostCity: hostCity,
            hostLanguage: hostLanguage,
          ),
        ],
      ),
    );
  }

  /// Independent Places Detail Page V1 hierarchy.
  Widget _buildIndependentPlaceStory({
    required String description,
    required String location,
    required double imageHeight,
  }) {
    final highlightCells =
        ListingPropertyHighlights.independentPlaceFactCells(item);
    final preferenceReasons = preferenceFitLabels.take(3).toList();
    final hostName = ListingData.hostName(item);
    final hostCity = ListingData.hostCity(item);
    final hostLanguage = ListingData.hostLanguage(item);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListingPhotoGallery(
            listing: item,
            height: imageHeight,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            showQuickEdit: isOwned,
            onQuickEdit: onEdit,
          ),
          const SizedBox(height: 20),
          Text(
            displayTitle,
            style: ListingDetailTokens.heroTitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(location, style: ListingDetailTokens.locationSubtitle),
          ],
          if (listedOnLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(listedOnLabel, style: ListingDetailTokens.locationSubtitle),
          ],
          if (preferenceReasons.isNotEmpty) ...[
            const SizedBox(height: 20),
            _PreferenceInsightCard(reasons: preferenceReasons),
          ],
          if (highlightCells.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionLabel(text: 'PROPERTY HIGHLIGHTS'),
            const SizedBox(height: 10),
            _PropertyHighlightsWrap(
              cells: highlightCells,
              formatHighlightLabel: formatHighlightLabel,
            ),
          ],
          const SizedBox(height: 18),
          ListingDetailCommuteSection(
            listing: item,
            userSession: userSession,
          ),
          if (NeighbourhoodHighlights.groupedForDetail(item).isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SectionLabel(text: 'NEIGHBOURHOOD HIGHLIGHTS'),
            const SizedBox(height: 12),
            _NeighbourhoodHighlightsBlock(listing: item),
          ],
          const SizedBox(height: 22),
          const _SectionLabel(text: 'DESCRIPTION'),
          const SizedBox(height: 8),
          Text(
            description.isEmpty ? 'No description provided.' : description,
            style: ListingDetailTokens.body,
          ),
          const SizedBox(height: 22),
          _HostBlock(
            hostName: hostName,
            hostCity: hostCity,
            hostLanguage: hostLanguage,
          ),
        ],
      ),
    );
  }
}

/// Single personalized guidance card for listing preference fit (IP + Shared).
class _PreferenceInsightCard extends StatelessWidget {
  const _PreferenceInsightCard({required this.reasons});

  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ListingDetailTokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '✨ Why this could work for you',
              style: ListingDetailTokens.highlightMeta.copyWith(
                fontWeight: FontWeight.w700,
                color: ListingDetailTokens.charcoal,
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < reasons.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              Text(
                reasons[i],
                style: ListingDetailTokens.body.copyWith(
                  fontSize: 14,
                  height: 1.4,
                  color: ListingDetailTokens.charcoal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionDashboardPanel extends StatelessWidget {
  const _ActionDashboardPanel({
    required this.item,
    required this.space,
    required this.hasApplied,
    this.applicationStateLabel,
    required this.isOwned,
    required this.displayPrice,
    required this.depositLabel,
    required this.onPitch,
    required this.onManage,
    required this.onStartReplacement,
    required this.onEdit,
    required this.showHostBlock,
  });

  final Map<String, dynamic> item;
  final MarketplaceSpace space;
  final bool hasApplied;
  final String? applicationStateLabel;
  final bool isOwned;
  final String displayPrice;
  final String? depositLabel;
  final VoidCallback onPitch;
  final VoidCallback onManage;
  final VoidCallback onStartReplacement;
  final VoidCallback onEdit;
  final bool showHostBlock;

  @override
  Widget build(BuildContext context) {
    final hostName = ListingData.hostName(item);
    final hostCity = ListingData.hostCity(item);
    final hostLanguage = ListingData.hostLanguage(item);
    final location = ListingData.location(item);
    final pitchName = hostName.trim().isEmpty
        ? 'the Host'
        : hostName.split(' ').first;
    final isShare = space == MarketplaceSpace.sharedSpace;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ListingDetailTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ListingDetailTokens.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (location.isNotEmpty) ...[
              Text(location, style: ListingDetailTokens.locationSubtitle),
              const SizedBox(height: 8),
            ],
            Text(displayPrice, style: ListingDetailTokens.price),
            if (depositLabel != null) ...[
              const SizedBox(height: 4),
              Text(depositLabel!, style: ListingDetailTokens.deposit),
            ],
            const SizedBox(height: 18),
            if (isOwned) ...[
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: onManage,
                  style: AppButtonStyles.primaryFilled,
                  icon: const Icon(Icons.groups_outlined, size: 20),
                  label: Text(isShare ? 'View matches' : 'View applicants'),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit listing'),
              ),
              if (isShare) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onStartReplacement,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Start lease replacement'),
                ),
              ],
            ] else if (hasApplied || applicationStateLabel != null) ...[
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: null,
                  style: AppButtonStyles.primaryFilled,
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    applicationStateLabel ?? 'Story Sent — Awaiting Host',
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: onPitch,
                  style: AppButtonStyles.primaryFilled,
                  child: Text(
                    'Pitch Your Story to $pitchName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ],
            if (showHostBlock) ...[
              const SizedBox(height: 24),
              _HostBlock(
                hostName: hostName,
                hostCity: hostCity,
                hostLanguage: hostLanguage,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureMatrixGrid extends StatelessWidget {
  const _FeatureMatrixGrid({
    required this.cells,
    required this.formatHighlightLabel,
  });

  final List<ListingHighlightCell> cells;
  final String Function(String) formatHighlightLabel;

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) return const SizedBox.shrink();
    return _PropertyHighlightsWrap(
      cells: cells,
      formatHighlightLabel: formatHighlightLabel,
    );
  }
}

class _PropertyHighlightsWrap extends StatelessWidget {
  const _PropertyHighlightsWrap({
    required this.cells,
    required this.formatHighlightLabel,
  });

  final List<ListingHighlightCell> cells;
  final String Function(String) formatHighlightLabel;

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final cell in cells)
          _HighlightChip(
            icon: cell.icon,
            label: formatHighlightLabel(cell.label),
            muted: cell.isPlatformFallback,
            coral: false,
          ),
      ],
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({
    required this.label,
    this.icon,
    this.emoji,
    this.muted = false,
    this.coral = false,
  });

  final String label;
  final IconData? icon;
  final String? emoji;
  final bool muted;
  final bool coral;

  static const _coralFill = Color(0xFFFFF1F2);
  static const _neutralFill = Color(0xFFF7F7F7);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: muted
            ? const Color(0xFFF8FAFC)
            : (coral ? _coralFill : _neutralFill),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: muted
              ? const Color(0xFFE2E8F0)
              : ListingDetailTokens.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null && emoji!.isNotEmpty) ...[
              Text(emoji!, style: const TextStyle(fontSize: 13, height: 1)),
              const SizedBox(width: 5),
            ] else if (icon != null) ...[
              Icon(icon, size: 14, color: ListingDetailTokens.muted),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: ListingDetailTokens.highlightMeta.copyWith(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _HostBlock extends StatelessWidget {
  const _HostBlock({
    required this.hostName,
    required this.hostCity,
    required this.hostLanguage,
  });

  final String hostName;
  final String hostCity;
  final String hostLanguage;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = hostName.trim().isEmpty ? 'Your host' : hostName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'HOSTED BY'),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.accent.withValues(alpha: 0.12),
              child: Text(
                _initials(displayName),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ListingDetailTokens.charcoal,
                    ),
                  ),
                  if (hostCity.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(hostCity, style: ListingDetailTokens.deposit),
                  ],
                  if (hostLanguage.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(hostLanguage, style: ListingDetailTokens.deposit),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NeighbourhoodHighlightsBlock extends StatefulWidget {
  const _NeighbourhoodHighlightsBlock({required this.listing});

  final Map<String, dynamic> listing;

  @override
  State<_NeighbourhoodHighlightsBlock> createState() =>
      _NeighbourhoodHighlightsBlockState();
}

class _NeighbourhoodHighlightsBlockState
    extends State<_NeighbourhoodHighlightsBlock> {
  bool _lifestyleExpanded = false;

  @override
  Widget build(BuildContext context) {
    final sections = NeighbourhoodHighlights.groupedForDetail(widget.listing);
    if (sections.isEmpty) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFEE2E2)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              _NeighbourhoodSection(
                section: sections[i],
                lifestyleExpanded: _lifestyleExpanded,
                onToggleLifestyle: () => setState(
                  () => _lifestyleExpanded = !_lifestyleExpanded,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NeighbourhoodSection extends StatelessWidget {
  const _NeighbourhoodSection({
    required this.section,
    required this.lifestyleExpanded,
    required this.onToggleLifestyle,
  });

  final NeighbourhoodHighlightSection section;
  final bool lifestyleExpanded;
  final VoidCallback onToggleLifestyle;

  @override
  Widget build(BuildContext context) {
    final isLifestyle = section.title == 'Lifestyle';
    const previewMax = NeighbourhoodHighlights.lifestylePreviewMax;
    final overflow =
        isLifestyle && !lifestyleExpanded && section.items.length > previewMax;
    final visible = overflow
        ? section.items.take(previewMax).toList()
        : section.items;
    final hiddenCount = overflow ? section.items.length - previewMax : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title.toUpperCase(),
          style: ListingDetailTokens.sectionLabel.copyWith(
            fontSize: 11,
            letterSpacing: 1.1,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final item in visible)
              _HighlightChip(
                emoji: item.emoji,
                label: _chipText(item),
                coral: true,
              ),
          ],
        ),
        if (overflow) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onToggleLifestyle,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text('Show $hiddenCount more'),
            ),
          ),
        ] else if (isLifestyle &&
            lifestyleExpanded &&
            section.items.length > previewMax) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onToggleLifestyle,
              style: TextButton.styleFrom(
                foregroundColor: ListingDetailTokens.muted,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Show less'),
            ),
          ),
        ],
      ],
    );
  }

  String _chipText(NeighbourhoodHighlight item) {
    // Education: name only (category clear from section). Walk when useful.
    if (section.title == 'Education') {
      return item.compactChipLabel.replaceFirst(RegExp(r'^[^\s]+\s'), '');
    }
    // Strip leading emoji from compact label since chip renders emoji separately.
    final compact = item.compactChipLabel;
    final space = compact.indexOf(' ');
    if (space <= 0) return item.placeName;
    return compact.substring(space + 1);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: ListingDetailTokens.sectionLabel);
  }
}
