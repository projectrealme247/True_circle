import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/marketplace_space.dart';
import '../utils/listing_data.dart';
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
    required this.isOwned,
    required this.displayPrice,
    required this.displayTitle,
    required this.formatHighlightLabel,
    required this.depositLabel,
    required this.mediaExtras,
    required this.onPitch,
    required this.onRequestViewing,
    required this.onManage,
    required this.onStartReplacement,
    required this.onEdit,
    required this.matchChips,
  });

  final Map<String, dynamic> item;
  final Map<String, dynamic>? userSession;
  final MarketplaceSpace space;
  final bool hasApplied;
  final bool isOwned;
  final String displayPrice;
  final String displayTitle;
  final String Function(String) formatHighlightLabel;
  final String? depositLabel;
  final List<Widget> mediaExtras;
  final VoidCallback onPitch;
  final VoidCallback onRequestViewing;
  final VoidCallback onManage;
  final VoidCallback onStartReplacement;
  final VoidCallback onEdit;
  final List<Widget> matchChips;

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
          displayTitle: displayTitle,
          formatHighlightLabel: formatHighlightLabel,
          isOwned: isOwned,
          onEdit: onEdit,
        );

        final panel = _ActionDashboardPanel(
          item: item,
          space: space,
          hasApplied: hasApplied,
          isOwned: isOwned,
          displayPrice: displayPrice,
          depositLabel: depositLabel,
          onPitch: onPitch,
          onRequestViewing: onRequestViewing,
          onManage: onManage,
          onStartReplacement: onStartReplacement,
          onEdit: onEdit,
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
    required this.displayTitle,
    required this.formatHighlightLabel,
    required this.isOwned,
    required this.onEdit,
  });

  final Map<String, dynamic> item;
  final Map<String, dynamic>? userSession;
  final MarketplaceSpace space;
  final List<Widget> mediaExtras;
  final List<Widget> matchChips;
  final String displayTitle;
  final String Function(String) formatHighlightLabel;
  final bool isOwned;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final description = ListingData.description(item);
    final location = ListingData.location(item);
    final isShare = space == MarketplaceSpace.sharedSpace;
    final imageHeight = isShare ? 240.0 : 280.0;

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
          const SizedBox(height: 20),
          const _SectionLabel(text: 'PROPERTY HIGHLIGHTS'),
          const SizedBox(height: 10),
          _FeatureMatrixGrid(
            listing: item,
            space: space,
            formatHighlightLabel: formatHighlightLabel,
          ),
          const SizedBox(height: 18),
          ListingDetailCommuteSection(
            listing: item,
            userSession: userSession,
          ),
          const SizedBox(height: 22),
          const _SectionLabel(text: 'DESCRIPTION'),
          const SizedBox(height: 8),
          Text(
            description.isEmpty ? 'No description provided.' : description,
            style: ListingDetailTokens.body,
          ),
          if (matchChips.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionLabel(text: 'YOUR MATCH'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: matchChips),
          ],
        ],
      ),
    );
  }
}

class _ActionDashboardPanel extends StatelessWidget {
  const _ActionDashboardPanel({
    required this.item,
    required this.space,
    required this.hasApplied,
    required this.isOwned,
    required this.displayPrice,
    required this.depositLabel,
    required this.onPitch,
    required this.onRequestViewing,
    required this.onManage,
    required this.onStartReplacement,
    required this.onEdit,
  });

  final Map<String, dynamic> item;
  final MarketplaceSpace space;
  final bool hasApplied;
  final bool isOwned;
  final String displayPrice;
  final String? depositLabel;
  final VoidCallback onPitch;
  final VoidCallback onRequestViewing;
  final VoidCallback onManage;
  final VoidCallback onStartReplacement;
  final VoidCallback onEdit;

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
            ] else if (hasApplied) ...[
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: null,
                  style: AppButtonStyles.primaryFilled,
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('Story sent — awaiting host'),
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
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onRequestViewing,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ListingDetailTokens.charcoal,
                    side: const BorderSide(color: ListingDetailTokens.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: const Text(
                    'Request a Viewing',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _HostBlock(
              hostName: hostName,
              hostCity: hostCity,
              hostLanguage: hostLanguage,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureMatrixGrid extends StatelessWidget {
  const _FeatureMatrixGrid({
    required this.listing,
    required this.space,
    required this.formatHighlightLabel,
  });

  final Map<String, dynamic> listing;
  final MarketplaceSpace space;
  final String Function(String) formatHighlightLabel;

  @override
  Widget build(BuildContext context) {
    final cells = space == MarketplaceSpace.fullRental
        ? [
            _MatrixCell(
              icon: Icons.home_work_outlined,
              label: formatHighlightLabel(
                'Entire Place (Independent Flat/House)',
              ),
            ),
            _MatrixCell(
              icon: Icons.king_bed_outlined,
              label: formatHighlightLabel(ListingData.bedsHighlightLabel(listing)),
            ),
            _MatrixCell(
              icon: Icons.verified_user_outlined,
              label: formatHighlightLabel(ListingData.rtbMatrixLabel(listing)),
            ),
            _MatrixCell(
              icon: Icons.local_parking_outlined,
              label: formatHighlightLabel(ListingData.parkingMatrixLabel(listing)),
            ),
          ]
        : [
            _MatrixCell(
              icon: Icons.bed_outlined,
              label: formatHighlightLabel(ListingData.shareRoomMatrixLabel(listing)),
            ),
            _MatrixCell(
              icon: Icons.groups_outlined,
              label: formatHighlightLabel(
                ListingData.householdCultureMatrixLabel(listing),
              ),
            ),
            _MatrixCell(
              icon: Icons.restaurant_outlined,
              label: formatHighlightLabel(
                ListingData.dietaryKitchenMatrixLabel(listing),
              ),
            ),
            _MatrixCell(
              icon: Icons.translate_outlined,
              label: formatHighlightLabel(
                ListingData.houseLanguagesMatrixLabel(listing),
              ),
            ),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth >= 520 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 72,
          ),
          itemCount: cells.length,
          itemBuilder: (context, index) => cells[index],
        );
      },
    );
  }
}

class _MatrixCell extends StatelessWidget {
  const _MatrixCell({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ListingDetailTokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ListingDetailTokens.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: ListingDetailTokens.highlightMeta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: ListingDetailTokens.sectionLabel);
  }
}
