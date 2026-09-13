import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../screens/auth_screen.dart';
import '../services/profile_state_notifier.dart';
import '../services/verification_gateway_recommendation.dart';
import 'emoji_leading_row.dart';

/// Premium verification path picker — persona-driven Grand-tier recommendations.
class VerificationGatewayBottomSheet extends StatefulWidget {
  const VerificationGatewayBottomSheet({
    super.key,
    this.session,
  });

  final Map<String, dynamic>? session;

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? session,
  }) {
    final resolved = session ??
        profileStateNotifier.session ??
        AuthScreen.currentUserSession;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VerificationGatewayBottomSheet(session: resolved),
    );
  }

  @override
  State<VerificationGatewayBottomSheet> createState() =>
      _VerificationGatewayBottomSheetState();
}

class _VerificationGatewayBottomSheetState
    extends State<VerificationGatewayBottomSheet> {
  void _openRoute(BuildContext context, String route) {
    Navigator.pop(context);
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.88;
    final layout = verificationGatewayLayoutForSession(widget.session);
    final recommendedDef =
        verificationGatewayCatalog[layout.recommended]!;

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
                      padding:
                          EdgeInsets.fromLTRB(20, 20, 20, 16 + bottomInset),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
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
                                        color: AppColors.accent
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: const EmojiLeadingRow(
                                      emoji: '✅',
                                      text: 'Verified User',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.accentDark,
                                      ),
                                      emojiWidth: 18,
                                      emojiFontSize: 13,
                                      gap: 4,
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
                                layout.subtitle,
                                style: AppTypography.bodySecondary.copyWith(
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _GatewayChoiceCard(
                                icon: recommendedDef.icon,
                                leadingEmoji: recommendedDef.leadingEmoji,
                                title: recommendedDef.pathTitle,
                                description: recommendedDef.description,
                                highlighted: true,
                                onTap: () => _openRoute(
                                  context,
                                  recommendedDef.route,
                                ),
                              ),
                              if (layout.alternates.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                Text(
                                  'Other ways to verify',
                                  style: AppTypography.caption.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.secondaryText,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                for (final path in layout.alternates) ...[
                                  _GatewayChoiceCard(
                                    icon: verificationGatewayCatalog[path]!
                                        .icon,
                                    leadingEmoji:
                                        verificationGatewayCatalog[path]!
                                            .leadingEmoji,
                                    title: verificationGatewayCatalog[path]!
                                        .pathTitle,
                                    description:
                                        verificationGatewayCatalog[path]!
                                            .description,
                                    onTap: () => _openRoute(
                                      context,
                                      verificationGatewayCatalog[path]!.route,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                              const SizedBox(height: 12),
                              const _PrivacyShieldFooter(),
                            ],
                          ),
                        ),
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
    required this.leadingEmoji,
    required this.title,
    required this.description,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String leadingEmoji;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool highlighted;

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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.highlighted
                  ? AppColors.accent.withValues(alpha: 0.45)
                  : _active
                      ? Colors.grey.shade300
                      : Colors.grey.shade200,
              width: widget.highlighted ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 2),
                blurRadius: 12,
                color: Colors.black.withValues(alpha: _active ? 0.06 : 0.04),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  widget.icon,
                  color: Colors.grey.shade500,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EmojiLeadingRow(
                        emoji: widget.leadingEmoji,
                        text: widget.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                          letterSpacing: -0.2,
                        ),
                        crossAxisAlignment: CrossAxisAlignment.start,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: _active ? AppColors.primaryText : Colors.grey.shade400,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 18,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Dublin Data Privacy Shield: TrueCircle utilizes zero-retention '
              'ephemeral processing. Your private documentation is read '
              'strictly in memory to verify identity signals and instantly '
              'destroyed. We never store your raw files or log data on our '
              'servers.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
