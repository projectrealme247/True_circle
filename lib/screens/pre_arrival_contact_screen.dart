import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart' show AppColors;
import '../screens/auth_screen.dart';
import '../services/trust_service.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../widgets/narrow_form_scroll_body.dart';

/// Path B — pre-arrival student declaration (no invite code or document upload).
class PreArrivalContactScreen extends StatefulWidget {
  const PreArrivalContactScreen({super.key});

  @override
  State<PreArrivalContactScreen> createState() =>
      _PreArrivalContactScreenState();
}

class _PreArrivalContactScreenState extends State<PreArrivalContactScreen> {
  bool _acceptedOffer = false;
  bool _busy = false;

  bool get _alreadyDeclared => TrustService.preArrivalContactReady();

  Future<void> _continue() async {
    if (!_acceptedOffer || _busy) return;
    if (AuthScreen.currentUserSession == null) {
      _snack('Please sign in to continue.');
      return;
    }

    setState(() => _busy = true);
    try {
      await TrustService.submitPreArrivalStudentDeclaration();
      if (!mounted) return;
      setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthScreen.currentUserSession;
    final alreadyUniversityVerified =
        session?['light_trust_verified'] == true ||
            (session?['verified_university_email']?.toString().trim().isNotEmpty ??
                false);

    if (alreadyUniversityVerified) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Pre-arrival Student', style: AppTypography.appBarBrand()),
        ),
        body: NarrowFormScrollBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DoneCard(
                title: 'Already verified',
                subtitle:
                    'You verified with a university email. Full contact access is active.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to listings'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Pre-arrival Student', style: AppTypography.appBarBrand()),
      ),
      body: NarrowFormScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pre-arrival Student',
              style: AppTypography.sectionTitle(),
            ),
            const SizedBox(height: 8),
            Text(
              "I don't have a university email yet.",
              style: AppTypography.detail().copyWith(
                fontWeight: FontWeight.w700,
                color: HomeMarketplaceTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'If you have accepted a university offer and will be relocating '
              'to Dublin for study, you can continue using the declaration below.',
              style: AppTypography.detail().copyWith(
                color: HomeMarketplaceTheme.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            if (_alreadyDeclared) ...[
              const _DoneCard(
                title: 'Pre-arrival student declared',
                subtitle:
                    'You can contact hosts. After you have a college email, '
                    'verify it to keep Verified User status.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Browse listings'),
              ),
            ] else ...[
              CheckboxListTile(
                value: _acceptedOffer,
                onChanged: _busy
                    ? null
                    : (value) =>
                        setState(() => _acceptedOffer = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'I have accepted a university offer and will be relocating '
                  'to Dublin for study.',
                  style: AppTypography.detail(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: (_acceptedOffer && !_busy) ? _continue : null,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.flight_takeoff_rounded, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.detail().copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTypography.detail()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
