import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart' show AppColors;
import '../screens/auth_screen.dart';
import '../services/invite_code_service.dart';
import '../services/trust_service.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/viewer_profile.dart';
import '../widgets/narrow_form_scroll_body.dart';

/// Track B — pre-arrival contact: invite code + onboarding letter at Stage 2.
class PreArrivalContactScreen extends StatefulWidget {
  const PreArrivalContactScreen({super.key});

  @override
  State<PreArrivalContactScreen> createState() =>
      _PreArrivalContactScreenState();
}

class _PreArrivalContactScreenState extends State<PreArrivalContactScreen> {
  final _inviteController = TextEditingController();
  int _step = 0;
  bool _busy = false;
  String? _letterFileName;

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  bool get _inviteDone =>
      AuthScreen.currentUserSession?['invite_code_verified'] == true;

  bool get _letterDone =>
      AuthScreen.currentUserSession?['onboarding_letter_verified'] == true;

  bool get _contactReady => TrustService.preArrivalContactReady();

  @override
  void initState() {
    super.initState();
    _step = _inviteDone ? (_letterDone ? 2 : 1) : 0;
    _letterFileName =
        AuthScreen.currentUserSession?['onboarding_letter_path']?.toString();
  }

  Future<void> _redeemInvite() async {
    final code = _inviteController.text.trim();
    if (code.isEmpty) {
      _snack('Enter an invite code from a verified community member.');
      return;
    }

    setState(() => _busy = true);
    try {
      final inviterId = await InviteCodeService.validateCode(code);
      if (inviterId == null) {
        _snack('Invalid or expired invite code.');
        return;
      }

      await TrustService.completeInviteCodeRedemption(
        code: code,
        invitedByUserId: inviterId,
      );
      await InviteCodeService.recordRedemption(code);

      if (!mounted) return;
      setState(() => _step = 1);
      _snack('Invite code accepted.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadLetter() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final path = file.path ?? file.name;

      await TrustService.submitOnboardingLetter(localPath: path);

      if (!mounted) return;
      setState(() {
        _letterFileName = file.name;
        _step = 2;
      });
      _snack('Onboarding letter received.');
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
    final stage = TrustService.currentStage();
    if (stage.level < TrustStage.socialVerified.level) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Pre-arrival contact', style: AppTypography.appBarBrand()),
        ),
        body: NarrowFormScrollBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Complete social verification first',
                style: AppTypography.sectionTitle(),
              ),
              const SizedBox(height: 8),
              Text(
                'Pre-arrival contact unlock requires Stage 2 (LinkedIn) '
                'before invite code and onboarding letter.',
                style: AppTypography.detail().copyWith(
                  color: HomeMarketplaceTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.push('/verify/social'),
                child: const Text('Start social verification'),
              ),
            ],
          ),
        ),
      );
    }

    if (stage.level >= TrustStage.idVerified.level) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Pre-arrival contact', style: AppTypography.appBarBrand()),
        ),
        body: NarrowFormScrollBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DoneCard(
                title: 'Already Community Verified',
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
        title: Text('Pre-arrival contact', style: AppTypography.appBarBrand()),
      ),
      body: NarrowFormScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Joining from abroad',
              style: AppTypography.sectionTitle(),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your university offer letter and enter an invite code '
              'from someone verified in Dublin. This unlocks contact with hosts '
              'while you stay at Stage 2 (Pre-Arrival badge).',
              style: AppTypography.detail().copyWith(
                color: HomeMarketplaceTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            _StepIndicator(current: _step),
            const SizedBox(height: 24),
            if (_contactReady) ...[
              const _DoneCard(
                title: 'Pre-arrival contact unlocked',
                subtitle:
                    'You can contact hosts. After arrival, verify your college email for Community Verified status.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Browse listings'),
              ),
            ] else if (_step == 0) ...[
              TextField(
                controller: _inviteController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Invite code',
                  hintText: 'CK-XXXXXX or DUBLIN-DEMO',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ask a Community Verified member in Dublin for their code.',
                style: AppTypography.detail().copyWith(
                  color: HomeMarketplaceTheme.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _redeemInvite,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ] else if (_step == 1) ...[
              const _DoneCard(
                title: 'Invite code accepted',
                subtitle: 'Next: upload your university onboarding or offer letter.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _busy ? null : _uploadLetter,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(
                  _letterFileName == null
                      ? 'Upload offer / enrollment letter'
                      : 'Replace letter ($_letterFileName)',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PDF or image accepted. POC auto-approves; production will review manually.',
                style: AppTypography.detail().copyWith(
                  color: HomeMarketplaceTheme.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(0, 'Invite'),
        Expanded(child: Divider(color: current >= 1 ? HomeMarketplaceTheme.primary : HomeMarketplaceTheme.border)),
        _dot(1, 'Letter'),
        Expanded(child: Divider(color: current >= 2 ? HomeMarketplaceTheme.primary : HomeMarketplaceTheme.border)),
        _dot(2, 'Done'),
      ],
    );
  }

  Widget _dot(int index, String label) {
    final active = current >= index;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? HomeMarketplaceTheme.primary
                  : HomeMarketplaceTheme.border,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: active ? Colors.white : HomeMarketplaceTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.detail()),
      ],
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
