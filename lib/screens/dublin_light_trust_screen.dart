import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/market/market_config.dart';
import '../services/trust_service.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../widgets/trust_badge.dart';

/// Dublin verification hub — college email or pre-arrival paths.
class DublinLightTrustScreen extends StatelessWidget {
  const DublinLightTrustScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isVerified = TrustService.canContact();
    final fullyVerified = isVerified;
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
              'Verify your profile',
              style: AppTypography.sectionTitle(),
            ),
            const SizedBox(height: 8),
            Text(
              'Browsing is always free. Verification unlocks contacting hosts.',
              style: AppTypography.detail().copyWith(
                color: HomeMarketplaceTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: isVerified
                  ? const TrustBadge(isVerified: true, compact: true)
                  : Text(
                      'Verification pending',
                      style: AppTypography.detail().copyWith(
                        color: HomeMarketplaceTheme.textSecondary,
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            Text(
              'How do you want to verify?',
              style: AppTypography.detail().copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _TrackCard(
              icon: Icons.school_outlined,
              title: 'I have a university email',
              subtitle: 'Verify with your university inbox.',
              badge: fullyVerified ? 'Complete' : null,
              onTap: fullyVerified
                  ? null
                  : () => context.push('/verify/id/university-email'),
            ),
            _TrackCard(
              icon: Icons.flight_takeoff_outlined,
              title: "I don't have a university email yet",
              subtitle:
                  'For students relocating to Dublin before university accounts are issued.',
              badge: preArrivalReady
                  ? 'Contact unlocked'
                  : fullyVerified
                      ? 'Complete'
                      : null,
              onTap: fullyVerified
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
              subtitle: 'Connect your profile to become a Verified User',
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

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: HomeMarketplaceTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: enabled
                        ? HomeMarketplaceTheme.textPrimary
                        : HomeMarketplaceTheme.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.detail().copyWith(
                            fontWeight: FontWeight.w700,
                            color: enabled
                                ? HomeMarketplaceTheme.textPrimary
                                : HomeMarketplaceTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: AppTypography.detail().copyWith(
                            color: HomeMarketplaceTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (badge != null)
                    Text(
                      badge!,
                      style: AppTypography.detail().copyWith(
                        fontWeight: FontWeight.w700,
                        color: HomeMarketplaceTheme.textMuted,
                      ),
                    ),
                ],
              ),
            ),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: HomeMarketplaceTheme.textMuted),
      title: Text(title, style: AppTypography.detail()),
      subtitle: Text(
        subtitle,
        style: AppTypography.detail().copyWith(
          color: HomeMarketplaceTheme.textMuted,
        ),
      ),
      onTap: onTapRoute == null ? null : () => context.push(onTapRoute!),
    );
  }
}
