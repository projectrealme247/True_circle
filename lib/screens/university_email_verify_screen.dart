import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/trust_service.dart';
import '../services/university_email_verify_service.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/irish_university_domains.dart';
import '../utils/profile_data.dart';
import '../widgets/narrow_form_scroll_body.dart';
import 'auth_screen.dart';

/// Track A — verify with Irish university email OTP.
class UniversityEmailVerifyScreen extends StatefulWidget {
  const UniversityEmailVerifyScreen({super.key});

  @override
  State<UniversityEmailVerifyScreen> createState() =>
      _UniversityEmailVerifyScreenState();
}

class _UniversityEmailVerifyScreenState
    extends State<UniversityEmailVerifyScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  bool _otpSent = false;
  bool _busy = false;
  bool _verified = false;
  String? _debugOtp;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (!IrishUniversityDomains.isAllowedUniversityEmail(email)) {
      _snack(
        'Enter a valid college email (.ac.ie or known university domain).',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await UniversityEmailVerifyService.sendOtp(email);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _debugOtp = UniversityEmailVerifyService.debugOtpHint();
      });
      _snack('Verification code sent to your college email.');
    } on UniversityEmailVerifyException catch (e) {
      _snack(e.message);
    } on FormatException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _snack('Enter the 6-digit code from your email.');
      return;
    }

    setState(() => _busy = true);
    try {
      final ok = await UniversityEmailVerifyService.verifyOtp(
        email: email,
        otp: otp,
      );
      if (!ok) {
        _snack('Invalid or expired code. Request a new one.');
        return;
      }

      await TrustService.upgradeLightTrust(
        method: 'university_email',
        verifiedEmail: email,
      );
      UniversityEmailVerifyService.clearPending();

      if (!mounted) return;
      setState(() {
        _busy = false;
        _verified = true;
      });
    } on UniversityEmailVerifyException catch (e) {
      _snack(e.message);
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
            ProfileData.text(session?['verified_university_email']).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('University email', style: AppTypography.appBarBrand()),
      ),
      body: NarrowFormScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Verify with your college email',
              style: AppTypography.sectionTitle(),
            ),
            const SizedBox(height: 8),
            Text(
              'Use your active .ac.ie or university inbox. This unlocks '
              'Verified User status and full contact access.',
              style: AppTypography.detail().copyWith(
                color: HomeMarketplaceTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            if (alreadyUniversityVerified || _verified) ...[
              const _SuccessCard(
                title: 'Verified User',
                subtitle: 'You can contact hosts with university email verification.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to listings'),
              ),
            ] else ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enabled: !_otpSent,
                decoration: const InputDecoration(
                  labelText: 'University email',
                  hintText: 'you@ucdconnect.ie',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (!_otpSent)
                FilledButton(
                  onPressed: _busy ? null : _sendOtp,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send verification code'),
                )
              else ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '6-digit code',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (UniversityEmailVerifyService.usesMockBackend &&
                    kDebugMode &&
                    _debugOtp != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Debug OTP: $_debugOtp',
                    style: AppTypography.detail().copyWith(
                      color: HomeMarketplaceTheme.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : _confirmOtp,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm and verify'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() {
                            _otpSent = false;
                            _otpController.clear();
                          });
                        },
                  child: const Text('Use a different email'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF008A05).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: Color(0xFF008A05)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.detail().copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF008A05),
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
