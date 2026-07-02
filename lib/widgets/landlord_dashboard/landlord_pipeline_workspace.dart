import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/applicant_application_status.dart';
import '../../models/landlord_applicant_card_model.dart';
import '../../services/listing_contact_service.dart';
import '../trust_tier_badge.dart';
import 'affordability_multiplier_chip.dart';
import 'landlord_dashboard_theme.dart';
import 'lifestyle_match_score_ring.dart';

/// Split two-column pipeline: applicant preview feed + passport workspace.
class LandlordPipelineWorkspace extends StatelessWidget {
  const LandlordPipelineWorkspace({
    super.key,
    required this.applicants,
    required this.selectedId,
    required this.onSelect,
    required this.onInvite,
    required this.onArchive,
    this.actionLoadingId,
    this.onOptimizeListing,
    this.hostPhoneE164,
    this.hostPrefersWhatsapp = false,
    this.listingTitle = '',
  });

  final List<LandlordApplicantCardModel> applicants;
  final String? selectedId;
  final ValueChanged<LandlordApplicantCardModel> onSelect;
  final ValueChanged<LandlordApplicantCardModel> onInvite;
  final ValueChanged<LandlordApplicantCardModel> onArchive;
  final String? actionLoadingId;
  final VoidCallback? onOptimizeListing;
  final String? hostPhoneE164;
  final bool hostPrefersWhatsapp;
  final String listingTitle;

  LandlordApplicantCardModel? get _selected {
    if (selectedId == null) return applicants.isNotEmpty ? applicants.first : null;
    return applicants.cast<LandlordApplicantCardModel?>().firstWhere(
          (a) => a!.applicationId == selectedId,
          orElse: () => applicants.isNotEmpty ? applicants.first : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    if (applicants.isEmpty) {
      return _EmptyPipeline(onOptimizeListing: onOptimizeListing);
    }

    final selected = _selected!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 220,
                child: _ApplicantPreviewFeed(
                  applicants: applicants,
                  selectedId: selected.applicationId,
                  onSelect: onSelect,
                  horizontal: true,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _ApplicantPassport(
                  applicant: selected,
                  onInvite: onInvite,
                  onArchive: onArchive,
                  actionLoadingId: actionLoadingId,
                  hostPhoneE164: hostPhoneE164,
                  hostPrefersWhatsapp: hostPrefersWhatsapp,
                  listingTitle: listingTitle,
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 380,
              child: _ApplicantPreviewFeed(
                applicants: applicants,
                selectedId: selected.applicationId,
                onSelect: onSelect,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _ApplicantPassport(
                applicant: selected,
                onInvite: onInvite,
                onArchive: onArchive,
                actionLoadingId: actionLoadingId,
                hostPhoneE164: hostPhoneE164,
                hostPrefersWhatsapp: hostPrefersWhatsapp,
                listingTitle: listingTitle,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ApplicantPreviewFeed extends StatelessWidget {
  const _ApplicantPreviewFeed({
    required this.applicants,
    required this.selectedId,
    required this.onSelect,
    this.horizontal = false,
  });

  final List<LandlordApplicantCardModel> applicants;
  final String selectedId;
  final ValueChanged<LandlordApplicantCardModel> onSelect;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    if (horizontal) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: applicants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final row = applicants[index];
          return SizedBox(
            width: 300,
            child: _PreviewCard(
              applicant: row,
              selected: row.applicationId == selectedId,
              onTap: () => onSelect(row),
            ),
          );
        },
      );
    }

    return _verticalFeedWithScrollFade(
      ListView.separated(
        padding: const EdgeInsets.only(right: 4, bottom: 8),
        itemCount: applicants.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final row = applicants[index];
          return _PreviewCard(
            applicant: row,
            selected: row.applicationId == selectedId,
            onTap: () => onSelect(row),
          );
        },
      ),
    );
  }

  Widget _verticalFeedWithScrollFade(Widget list) {
    return Stack(
      children: [
        list,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 40,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.applicant,
    required this.selected,
    required this.onTap,
  });

  final LandlordApplicantCardModel applicant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: LandlordDashboardTheme.cardDecoration(selected: selected),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      applicant.seekerName,
                      style: LandlordDashboardTheme.sectionTitle(size: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${applicant.matchPercent}% Match',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: LandlordDashboardTheme.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AffordabilityMultiplierChip(
                multiplier: applicant.affordabilityMultiplier,
                fullWidth: true,
                compact: true,
              ),
              if (applicant.budgetLabel != null ||
                  applicant.commuteLabel != null ||
                  applicant.moveInLabel != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (applicant.budgetLabel != null)
                      _ApplicantMetaChip(label: applicant.budgetLabel!),
                    if (applicant.commuteLabel != null)
                      _ApplicantMetaChip(label: applicant.commuteLabel!),
                    if (applicant.moveInLabel != null)
                      _ApplicantMetaChip(label: applicant.moveInLabel!),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              TrustTierBadge(
                tier: applicant.trustTier,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicantPassport extends StatelessWidget {
  const _ApplicantPassport({
    required this.applicant,
    required this.onInvite,
    required this.onArchive,
    this.actionLoadingId,
    this.hostPhoneE164,
    this.hostPrefersWhatsapp = false,
    this.listingTitle = '',
  });

  final LandlordApplicantCardModel applicant;
  final ValueChanged<LandlordApplicantCardModel> onInvite;
  final ValueChanged<LandlordApplicantCardModel> onArchive;
  final String? actionLoadingId;
  final String? hostPhoneE164;
  final bool hostPrefersWhatsapp;
  final String listingTitle;

  bool get _contactUnlocked =>
      applicant.status == ApplicantApplicationStatus.viewingScheduled ||
      applicant.status == ApplicantApplicationStatus.accepted;

  Future<void> _openWhatsAppHandoff(BuildContext context) async {
    final phone = hostPhoneE164 ?? '';
    final uri = ListingContactService.whatsAppHandoffUri(
      phoneE164: phone,
      listingTitle: listingTitle,
      applicantName: applicant.seekerName,
    );
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a phone number with WhatsApp enabled in your profile.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: uri));
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Continue on WhatsApp'),
        content: const Text(
          'WhatsApp link copied. TrueCircle does not monitor external messages.\n\n'
          'Open WhatsApp and paste the link, or use your usual chat app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = actionLoadingId == applicant.applicationId;

    return Container(
      decoration: LandlordDashboardTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          applicant.seekerName,
                          style: LandlordDashboardTheme.sectionTitle(size: 26),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _StatusBadge(label: applicant.statusLabel),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Applicant Passport',
                    style: LandlordDashboardTheme.cardSubtext().copyWith(
                      fontSize: 12,
                      color: LandlordDashboardTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ScoreSplitSection(applicant: applicant),
                  const SizedBox(height: 20),
                  _AffordabilityProfileCard(
                    multiplier: applicant.affordabilityMultiplier,
                  ),
                  if (_contactUnlocked && hostPrefersWhatsapp) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Contact milestone reached',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF166534),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'You can coordinate the viewing off-platform. '
                            'TrueCircle does not monitor external messages.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF15803D),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => _openWhatsAppHandoff(context),
                            icon: const Icon(Icons.chat_outlined, size: 18),
                            label: const Text('Copy WhatsApp link'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: LandlordDashboardTheme.border),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 180,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: loading
                        ? null
                        : () => onArchive(applicant),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LandlordDashboardTheme.textSecondary,
                      side: const BorderSide(
                        color: LandlordDashboardTheme.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Archive',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  height: 44,
                  child: FilledButton(
                    onPressed: loading ? null : () => onInvite(applicant),
                    style: FilledButton.styleFrom(
                      backgroundColor: LandlordDashboardTheme.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Invite Match',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicantMetaChip extends StatelessWidget {
  const _ApplicantMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: LandlordDashboardTheme.canvas,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LandlordDashboardTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: LandlordDashboardTheme.textSecondary,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: LandlordDashboardTheme.canvas,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LandlordDashboardTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: LandlordDashboardTheme.textSecondary,
        ),
      ),
    );
  }
}

class _ScoreSplitSection extends StatelessWidget {
  const _ScoreSplitSection({required this.applicant});

  final LandlordApplicantCardModel applicant;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 520;
        final matchMetrics = MatchBreakdownMetrics.forApplicant(applicant);
        final verifyTokens = TrustVerificationTokens.forTier(applicant.trustTier);

        final matchPanel = _Panel(
          title: 'Match Breakdown',
          expandContent: !stacked,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: stacked ? MainAxisSize.min : MainAxisSize.max,
            children: [
              MatchScoreWithAffordabilityChip(
                percent: applicant.matchPercent,
                affordabilityMultiplier: applicant.affordabilityMultiplier,
                ringSize: 56,
                stackChip: true,
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < matchMetrics.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == matchMetrics.length - 1 ? 0 : 10,
                  ),
                  child: _MicroMetricTile(
                    emoji: matchMetrics[i].emoji,
                    title: matchMetrics[i].title,
                    subtitle: matchMetrics[i].subtitle,
                  ),
                ),
            ],
          ),
        );
        final verifyPanel = _Panel(
          title: 'Cryptographic verification tokens',
          expandContent: !stacked,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: stacked ? MainAxisSize.min : MainAxisSize.max,
            children: [
              TrustTierBadge(
                tier: applicant.trustTier,
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < verifyTokens.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == verifyTokens.length - 1 ? 0 : 10,
                  ),
                  child: _MicroMetricTile(
                    emoji: verifyTokens[i].emoji,
                    title: verifyTokens[i].title,
                    subtitle: verifyTokens[i].subtitle,
                  ),
                ),
              if (applicant.languages.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Languages: ${applicant.languages.join(' · ')}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                    height: 1.35,
                  ),
                ),
              ],
              if (!stacked) const Spacer(),
              if (stacked) const SizedBox(height: 10),
              Text(
                'Raw document uploads are withheld per Irish Data Protection guidelines. Only verification tokens are surfaced.',
                style: LandlordDashboardTheme.cardSubtext().copyWith(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        );

        if (stacked) {
          return Column(
            children: [
              matchPanel,
              const SizedBox(height: 12),
              verifyPanel,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: matchPanel),
              const SizedBox(width: 12),
              Expanded(child: verifyPanel),
            ],
          ),
        );
      },
    );
  }
}

class MatchBreakdownMetricItem {
  const MatchBreakdownMetricItem({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String emoji;
  final String title;
  final String subtitle;
}

abstract final class MatchBreakdownMetrics {
  static List<MatchBreakdownMetricItem> forApplicant(
    LandlordApplicantCardModel applicant,
  ) {
    final multiplierLabel =
        applicant.affordabilityMultiplier.toStringAsFixed(1);

    return [
      const MatchBreakdownMetricItem(
        emoji: '🏡',
        title: 'Lifestyle Compatibility',
        subtitle: 'Shared household rhythm & vibe alignment',
      ),
      const MatchBreakdownMetricItem(
        emoji: '🍳',
        title: 'Shared Kitchen Culture',
        subtitle: 'Co-living cooking window & space match',
      ),
      MatchBreakdownMetricItem(
        emoji: '💼',
        title: 'Financial Security',
        subtitle:
            'Salary exceeds ${multiplierLabel}x rent target baseline',
      ),
    ];
  }
}

class _MicroMetricTile extends StatelessWidget {
  const _MicroMetricTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String emoji;
  final String title;
  final String subtitle;

  static const _titleColor = Color(0xFF1E293B);
  static const _subtitleColor = Color(0xFF64748B);
  static const _emojiStyle = TextStyle(fontSize: 18, height: 1.1);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LandlordDashboardTheme.commuteTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LandlordDashboardTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: _emojiStyle),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _titleColor,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _subtitleColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.expandContent = false,
  });

  final String title;
  final Widget child;
  final bool expandContent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LandlordDashboardTheme.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LandlordDashboardTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: LandlordDashboardTheme.cardLabel()),
          const SizedBox(height: 12),
          if (expandContent) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _AffordabilityProfileCard extends StatelessWidget {
  const _AffordabilityProfileCard({required this.multiplier});

  final double multiplier;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LandlordDashboardTheme.commuteTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LandlordDashboardTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: LandlordDashboardTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: LandlordDashboardTheme.border),
            ),
            child: const Icon(
              Icons.euro_rounded,
              size: 20,
              color: LandlordDashboardTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gross income coverage',
                  style: LandlordDashboardTheme.cardLabel().copyWith(
                    fontSize: 13,
                    color: LandlordDashboardTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${multiplier.toStringAsFixed(1)}x Affordability Multiplier',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: LandlordDashboardTheme.textPrimary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verified gross income relative to monthly rent target.',
                  style: LandlordDashboardTheme.cardSubtext().copyWith(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPipeline extends StatelessWidget {
  const _EmptyPipeline({this.onOptimizeListing});

  final VoidCallback? onOptimizeListing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: LandlordDashboardTheme.cardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 48,
            color: LandlordDashboardTheme.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'No matches in this cohort yet',
            style: LandlordDashboardTheme.sectionTitle(size: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tune your listing preferences or check another trust tier tab.',
            style: LandlordDashboardTheme.cardSubtext(),
            textAlign: TextAlign.center,
          ),
          if (onOptimizeListing != null) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: onOptimizeListing,
              child: const Text('Optimize listing'),
            ),
          ],
        ],
      ),
    );
  }
}
