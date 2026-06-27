import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';

/// Premium verification path picker — upgrades users toward the 👍 Grand tier.
class VerificationGatewayBottomSheet extends StatelessWidget {
  const VerificationGatewayBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const VerificationGatewayBottomSheet(),
    );
  }

  void _openCorporate(BuildContext context) {
    Navigator.pop(context);
    context.push('/verify/social');
  }

  void _openBankLink(BuildContext context) {
    Navigator.pop(context);
    context.push('/verify/open-banking');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: AppColors.surface,
            elevation: 12,
            shadowColor: Colors.black26,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: sheetHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + bottomInset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.accent.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: const Text(
                                  '👍 Grand',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accentDark,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded),
                                color: AppColors.secondaryText,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Verification Gateway',
                            style: AppTypography.h2.copyWith(
                              fontSize: 22,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose a secure path to upgrade your trust tier. '
                            'Both options unlock the Grand badge for hosts and seekers.',
                            style: AppTypography.bodySecondary.copyWith(
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _GatewayChoiceCard(
                            icon: Icons.work_outline_rounded,
                            badge: 'Recommended · Pre-Arrival & International',
                            title: 'Corporate Verification',
                            subtitle:
                                'Connect LinkedIn or upload your corporate employment '
                                'contract / offer letter. Perfect for international '
                                'relocators arriving from abroad.',
                            onTap: () => _openCorporate(context),
                          ),
                          const SizedBox(height: 14),
                          _GatewayChoiceCard(
                            icon: Icons.account_balance_rounded,
                            badge: 'Recommended · Local Residents',
                            title: 'Instant Bank Link',
                            subtitle:
                                'Securely connect your Irish/EU bank account '
                                '(AIB, BOI, Revolut) via Open Banking. Zero paperwork, '
                                'instant approval.',
                            onTap: () => _openBankLink(context),
                          ),
                          const SizedBox(height: 22),
                          const _PrivacyShieldFooter(),
                        ],
                      ),
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

class _GatewayChoiceCard extends StatefulWidget {
  const _GatewayChoiceCard({
    required this.icon,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String badge;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  static const _cardFill = Color(0xFFF8FAFC);
  static const _borderRest = Color(0xFFE2E8F0);
  static const _badgeFill = Color(0xFFEDF2F7);
  static const _badgeText = Color(0xFF4A5568);
  static const _iconFill = Color(0xFFEDF2F7);

  @override
  State<_GatewayChoiceCard> createState() => _GatewayChoiceCardState();
}

class _GatewayChoiceCardState extends State<_GatewayChoiceCard> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _active => _hovered || _pressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _GatewayChoiceCard._cardFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _active ? AppColors.accent : _GatewayChoiceCard._borderRest,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _GatewayChoiceCard._iconFill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.icon,
                        color: _GatewayChoiceCard._badgeText,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _GatewayChoiceCard._badgeFill,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.badge,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _GatewayChoiceCard._badgeText,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryText,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: _active
                          ? AppColors.accent
                          : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.subtitle,
                  style: AppTypography.caption.copyWith(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                    height: 1.5,
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

class _PrivacyShieldFooter extends StatelessWidget {
  const _PrivacyShieldFooter();

  static const _bodyColor = Color(0xFF4A5568);
  static const _surfaceTint = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 20,
            color: _bodyColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '🔒 Dublin Data Privacy Shield: TrueCircle utilizes zero-retention '
              'ephemeral processing. Your private documentation and banking records '
              'are read strictly in memory to verify trust signals and instantly '
              'destroyed. We never store your raw files, transaction histories, or '
              'log data on our servers.',
              style: AppTypography.caption.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: _bodyColor,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
