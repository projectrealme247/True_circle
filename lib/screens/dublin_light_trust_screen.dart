import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/market/market_config.dart';
import '../services/trust_service.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/viewer_profile.dart';

/// Dublin light trust hub — two student tracks plus future options.
class DublinLightTrustScreen extends StatelessWidget {
  const DublinLightTrustScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stage = TrustService.currentStage();
    final preArrivalReady = TrustService.preArrivalContactReady();

    return Scaffold(
      appBar: AppBar(
        title: Text('Verify your profile', style: AppTypography.appBarBrand()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Community trust for Dublin',
              style: AppTypography.sectionTitle(),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the path that fits your situation. Browsing is always '
              'free — verification unlocks contacting hosts.',
              style: AppTypography.detail().copyWith(
                color: HomeMarketplaceTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _StageChip(stage: stage, preArrivalReady: preArrivalReady),
            const SizedBox(height: 24),
            Text(
              'Choose your path',
              style: AppTypography.detail().copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _TrackCard(
              icon: Icons.school_outlined,
              title: 'I have a college email',
              subtitle:
                  'Verify with your .ac.ie or university inbox → Community Verified (Stage 3)',
              badge: stage.level >= TrustStage.idVerified.level
                  ? 'Complete'
                  : 'Track A',
              onTap: stage.level >= TrustStage.idVerified.level
                  ? null
                  : () => context.push('/verify/id/university-email'),
            ),
            _TrackCard(
              icon: Icons.flight_takeoff_outlined,
              title: 'Joining from abroad',
              subtitle:
                  'Invite code + university offer letter → contact hosts at Stage 2 (Pre-Arrival)',
              badge: preArrivalReady
                  ? 'Contact unlocked'
                  : stage.level >= TrustStage.idVerified.level
                      ? 'N/A'
                      : 'Track B',
              onTap: stage.level >= TrustStage.idVerified.level
                  ? null
                  : () => context.push('/verify/pre-arrival'),
            ),
            const SizedBox(height: 24),
            Text(
              'Coming soon',
              style: AppTypography.detail().copyWith(
                color: HomeMarketplaceTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const _TrustOption(
              icon: Icons.link_rounded,
              title: 'LinkedIn',
              subtitle: 'Stage 2 social verification — connect your profile',
              onTapRoute: '/verify/social',
            ),
            const _TrustOption(
              icon: Icons.sms_outlined,
              title: 'Irish mobile (+353)',
              subtitle: 'SMS confirmation for local reachability',
            ),
            const _TrustOption(
              icon: Icons.verified_user_outlined,
              title: 'References',
              subtitle: 'Someone vouches via confirmed email or phone',
            ),
            const SizedBox(height: 32),
            Text(
              'Market: ${MarketConfig.current.appTitle}',
              textAlign: TextAlign.center,
              style: AppTypography.detail().copyWith(
                color: HomeMarketplaceTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage, required this.preArrivalReady});

  final TrustStage stage;
  final bool preArrivalReady;

  @override
  Widget build(BuildContext context) {
    final label = switch (stage) {
      TrustStage.idVerified => 'Stage 3 · Community Verified · 1.0×',
      TrustStage.socialVerified when preArrivalReady =>
        'Stage 2 · Pre-Arrival contact · 0.9×',
      TrustStage.socialVerified => 'Stage 2 · Social Verified · 0.9×',
      TrustStage.casual => 'Stage 1 · Casual · 0.7×',
      TrustStage.anonymous => 'Stage 0 · Anonymous',
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: HomeMarketplaceTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HomeMarketplaceTheme.border),
        ),
        child: Text(label, style: AppTypography.detail()),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: HomeMarketplaceTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: onTap == null
                ? HomeMarketplaceTheme.border
                : HomeMarketplaceTheme.primary.withValues(alpha: 0.4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ListTile(
            leading: Icon(icon, color: HomeMarketplaceTheme.primary),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.detail()
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: HomeMarketplaceTheme.accentSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: AppTypography.detail().copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: HomeMarketplaceTheme.accent,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(subtitle, style: AppTypography.detail()),
            trailing: onTap != null
                ? const Icon(Icons.chevron_right_rounded)
                : const Icon(Icons.check_circle_outline,
                    color: Color(0xFF008A05)),
          ),
        ),
      ),
    );
  }
}

class _TrustOption extends StatelessWidget {
  const _TrustOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTapRoute,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? onTapRoute;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: HomeMarketplaceTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: HomeMarketplaceTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTapRoute == null ? null : () => context.push(onTapRoute!),
          leading: Icon(icon, color: HomeMarketplaceTheme.textMuted),
          title: Text(
            title,
            style: AppTypography.detail().copyWith(
              fontWeight: FontWeight.w600,
              color: HomeMarketplaceTheme.textSecondary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: AppTypography.detail().copyWith(
              color: HomeMarketplaceTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
