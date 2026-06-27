import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/linkedin_oauth_service.dart';
import '../services/trust_service.dart';
import '../widgets/corporate_document_upload_card.dart';
import '../utils/viewer_profile.dart';

import '../core/theme/app_theme.dart';
import '../theme/home_marketplace_theme.dart';

/// Stage 2: Social verification via LinkedIn OpenID Connect.
class SocialVerificationScreen extends StatefulWidget {
  const SocialVerificationScreen({super.key});

  @override
  State<SocialVerificationScreen> createState() =>
      _SocialVerificationScreenState();
}

class _SocialVerificationScreenState extends State<SocialVerificationScreen> {
  final _companyController = TextEditingController();
  final _titleController = TextEditingController();

  LinkedInProfile? _linkedInProfile;
  bool _isLinkedInAuthenticated = false;
  bool _connecting = false;
  bool _completing = false;
  bool _verified = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final uri = GoRouterState.of(context).uri;
    final linkedinError = uri.queryParameters['linkedin_error'];
    if (linkedinError != null && linkedinError.isNotEmpty) {
      setState(() => _error = Uri.decodeComponent(linkedinError));
      return;
    }

    // Only restore profile after an explicit OAuth return — not on cold load.
    final linkedinConnected = uri.queryParameters['linkedin'] == 'connected';
    if (!linkedinConnected) return;

    final pending = await LinkedInOAuthService.loadPendingProfile();
    if (!mounted) return;
    if (pending != null) {
      setState(() {
        _linkedInProfile = pending;
        _isLinkedInAuthenticated = true;
      });
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _connectLinkedIn() async {
    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      await LinkedInOAuthService.beginAuthorization();
      if (LinkedInOAuthService.usesMock) {
        final profile = await LinkedInOAuthService.loadPendingProfile();
        if (!mounted) return;
        setState(() {
          _linkedInProfile = profile;
          _isLinkedInAuthenticated = profile != null;
          _connecting = false;
        });
      }
    } on LinkedInOAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _connecting = false;
      });
    }
  }

  Future<void> _completeVerification() async {
    if (_linkedInProfile == null) {
      _snack('Connect LinkedIn first.');
      return;
    }

    if (_companyController.text.trim().isEmpty ||
        _titleController.text.trim().isEmpty) {
      _snack('Enter your company and job title.');
      return;
    }

    setState(() => _completing = true);

    await TrustService.upgradeSocial(
      company: _companyController.text.trim(),
      jobTitle: _titleController.text.trim(),
      linkedinSub: _linkedInProfile!.sub,
      linkedinEmail: _linkedInProfile!.email,
      linkedinName: _linkedInProfile!.name,
      linkedinPictureUrl: _linkedInProfile!.picture,
    );
    await LinkedInOAuthService.clearPendingProfile();

    if (!mounted) return;
    setState(() {
      _completing = false;
      _verified = true;
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final currentStage = TrustService.currentStage();
    final alreadyVerified =
        currentStage.level >= TrustStage.socialVerified.level;

    return Scaffold(
      backgroundColor: HomeMarketplaceTheme.canvas,
      appBar: AppBar(
        title: const Text('Social Verification'),
        backgroundColor: HomeMarketplaceTheme.surface,
        foregroundColor: HomeMarketplaceTheme.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: HomeMarketplaceTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: HomeMarketplaceTheme.border),
                    boxShadow: HomeMarketplaceTheme.cardShadowRest,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: AppColors.accent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Verify with LinkedIn',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  alreadyVerified || _verified
                                      ? 'Stage 2 verified — 0.9× trust multiplier'
                                      : 'Connect LinkedIn, then confirm your role',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.error,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (alreadyVerified || _verified) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.trustMutedSurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: AppColors.trustMuted,
                                  size: 22),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Social verification complete. Your listings now rank higher.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.trustMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => context.go('/profile'),
                            child: const Text('Back to profile'),
                          ),
                        ),
                      ] else if (!_isLinkedInAuthenticated) ...[
                        const Text(
                          'Sign in with LinkedIn to prove your professional identity. '
                          'LinkedIn OpenID does not share employer details — you will '
                          'confirm company and title next.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed:
                                _connecting ? null : _connectLinkedIn,
                            icon: _connecting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accent,
                                    ),
                                  )
                                : const Icon(Icons.lock_outline_rounded),
                            label: Text(
                              _connecting
                                  ? 'Connecting…'
                                  : 'Securely Link LinkedIn Account',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accent,
                              side: const BorderSide(
                                color: AppColors.accent,
                                width: 1.5,
                              ),
                              disabledForegroundColor:
                                  AppColors.accent.withValues(alpha: 0.45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        if (LinkedInOAuthService.usesMock) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Mock mode: no LinkedIn redirect.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ] else ...[
                        _LinkedInConnectedCard(profile: _linkedInProfile!),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _companyController,
                          decoration: InputDecoration(
                            labelText: 'Company',
                            hintText: 'e.g. Google, Deloitte, TCS',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Job title',
                            hintText: 'e.g. Software Engineer',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _completing ? null : _completeVerification,
                            icon: _completing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.verified_rounded),
                            label: Text(
                              _completing
                                  ? 'Saving…'
                                  : 'Complete social verification',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.accent.withValues(alpha: 0.45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _connecting ? null : _connectLinkedIn,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.secondaryText,
                          ),
                          child: const Text('Use a different LinkedIn account'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!alreadyVerified && !_verified) ...[
                  CorporateDocumentUploadCard(
                    onVerified: () => setState(() => _verified = true),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildTrustStageIndicator(currentStage),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustStageIndicator(TrustStage current) {
    final stage = _verified ? TrustStage.socialVerified : current;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeMarketplaceTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your trust level',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 10),
          for (final s in TrustStage.values)
            if (s != TrustStage.anonymous)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      stage.level >= s.level
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 18,
                      color: stage.level >= s.level
                          ? AppColors.trustMuted
                          : AppColors.disabled,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Stage ${s.level}: ${s.label}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            stage == s ? FontWeight.w700 : FontWeight.w400,
                        color: stage.level >= s.level
                            ? AppColors.primaryText
                            : AppColors.secondaryText,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${s.multiplier}x',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: stage.level >= s.level
                            ? AppColors.trustMuted
                            : AppColors.disabled,
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

class _LinkedInConnectedCard extends StatelessWidget {
  const _LinkedInConnectedCard({required this.profile});

  final LinkedInProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          if (profile.picture.isNotEmpty)
            CircleAvatar(
              backgroundImage: NetworkImage(profile.picture),
              radius: 22,
            )
          else
            const CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accent,
              child: Icon(Icons.person, color: Colors.white),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.primaryText,
                  ),
                ),
                if (profile.email.isNotEmpty)
                  Text(
                    profile.email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                const Text(
                  'LinkedIn connected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle,
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}
