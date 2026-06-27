import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart' show AppColors, AppTypography;
import '../models/marketplace_space.dart';
import '../services/marketplace_context_notifier.dart';
import '../theme/home_marketplace_theme.dart';

/// First-time space selection after login when no prior choice is stored.
class SpaceGatewayScreen extends StatelessWidget {
  const SpaceGatewayScreen({super.key});

  Future<void> _selectSpace(
    BuildContext context,
    MarketplaceSpace space,
  ) async {
    await marketplaceContextNotifier.setActiveSpace(space);
    if (!context.mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final enabled = MarketplaceSpace.enabledForMarket();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Where are you looking?',
                      textAlign: TextAlign.center,
                      style: AppTypography.h1,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose your preference',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySecondary,
                    ),
                    const SizedBox(height: 40),
                    if (enabled.contains(MarketplaceSpace.fullRental))
                      _SpaceOptionCard(
                        title: MarketplaceSpace.fullRental.option2Title,
                        subtitle: MarketplaceSpace.fullRental.option2Subtitle,
                        icon: Icons.home,
                        onTap: () => _selectSpace(
                          context,
                          MarketplaceSpace.fullRental,
                        ),
                      ),
                    if (enabled.contains(MarketplaceSpace.fullRental) &&
                        enabled.contains(MarketplaceSpace.sharedSpace))
                      const SizedBox(height: 16),
                    if (enabled.contains(MarketplaceSpace.sharedSpace))
                      _SpaceOptionCard(
                        title: MarketplaceSpace.sharedSpace.option2Title,
                        subtitle: MarketplaceSpace.sharedSpace.option2Subtitle,
                        icon: Icons.people,
                        onTap: () => _selectSpace(
                          context,
                          MarketplaceSpace.sharedSpace,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpaceOptionCard extends StatelessWidget {
  const _SpaceOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeMarketplaceTheme.surface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: HomeMarketplaceTheme.accentSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 28, color: HomeMarketplaceTheme.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.h3,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTypography.bodySecondary,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: HomeMarketplaceTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
