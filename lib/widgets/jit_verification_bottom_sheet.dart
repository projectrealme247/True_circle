import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/app_button.dart';
import '../services/linkedin_oauth_service.dart';
import '../services/corporate_document_verify_service.dart';
import '../services/trust_service.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/viewer_profile.dart';
import '../screens/auth_screen.dart';

/// Phase 3 JIT gate for Working Professionals and Arriving Families.
class JitVerificationBottomSheet extends StatefulWidget {
  const JitVerificationBottomSheet({
    super.key,
    required this.cohort,
    required this.onVerified,
  });

  final SeekerCohort cohort;
  final VoidCallback onVerified;

  static Future<void> show(
    BuildContext context, {
    required SeekerCohort cohort,
    required VoidCallback onVerified,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => JitVerificationBottomSheet(
        cohort: cohort,
        onVerified: () {
          Navigator.pop(ctx);
          onVerified();
        },
      ),
    );
  }

  @override
  State<JitVerificationBottomSheet> createState() =>
      _JitVerificationBottomSheetState();
}

class _JitVerificationBottomSheetState extends State<JitVerificationBottomSheet> {
  static const _indigo = Color(0xFF4338CA);
  static const _teal = Color(0xFF008A7A);
  static const _tealSurface = Color(0xFFE6F7F5);

  bool _busy = false;
  String? _error;
  String? _uploadedFileName;

  bool get _isWorking =>
      widget.cohort == SeekerCohort.workingProfessional;

  Future<void> _verifyWithLinkedIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await LinkedInOAuthService.beginAuthorization();

      if (LinkedInOAuthService.usesMock) {
        final profile = await LinkedInOAuthService.loadPendingProfile();
        if (profile == null) {
          throw LinkedInOAuthException('LinkedIn connection did not complete.');
        }

        final session = AuthScreen.currentUserSession;
        final viewer = ViewerProfile.fromSession(session);
        final company = viewer?.company.isNotEmpty == true
            ? viewer!.company
            : 'Verified employer';
        final jobTitle = viewer?.jobTitle.isNotEmpty == true
            ? viewer!.jobTitle
            : profile.name;

        await TrustService.upgradeSocial(
          company: company,
          jobTitle: jobTitle,
          linkedinSub: profile.sub,
          linkedinEmail: profile.email,
          linkedinName: profile.name,
          linkedinPictureUrl: profile.picture,
        );
        await LinkedInOAuthService.clearPendingProfile();

        if (!mounted) return;
        widget.onVerified();
        return;
      }

      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete LinkedIn sign-in, then tap Contact Host again.',
          ),
        ),
      );
    } on LinkedInOAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not connect LinkedIn. Try again.';
        _busy = false;
      });
    }
  }

  Future<void> _pickEmploymentLetter() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _busy = false);
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw CorporateDocumentVerifyException(
          'Could not read this file. Try a PDF export from your employer.',
        );
      }

      await CorporateDocumentVerifyService.verifyCorporateDocument(
        fileBytes: Uint8List.fromList(bytes),
        fileName: file.name,
      );

      if (!mounted) return;
      setState(() => _uploadedFileName = file.name);
      widget.onVerified();
    } on CorporateDocumentVerifyException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not verify employment letter. Try again.';
        _busy = false;
      });
    }
  }

  Future<void> _pickFamilyBudgetProof() async {
    await _pickAndSubmit(
      label: 'bank statement summary',
      submit: TrustService.submitJitFamilyBudgetProof,
    );
  }

  Future<void> _pickAndSubmit({
    required String label,
    required Future<void> Function({required String localPath}) submit,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _busy = false);
        return;
      }

      final file = result.files.first;
      final path = file.path ?? file.name;
      await submit(localPath: path);

      if (!mounted) return;
      setState(() => _uploadedFileName = file.name);
      widget.onVerified();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not process $label. Try again.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: const EdgeInsets.only(top: 48),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_indigo, _teal],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Verify Your Profile to Connect',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1E21),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isWorking
                  ? 'Hosts trust verified professionals. Confirm your employment '
                      'before messaging.'
                  : 'Confirm your rental budget capability so hosts know you '
                      'are a serious match.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            if (_isWorking) ...[
              _linkedInCard(),
              const SizedBox(height: 12),
              _fallbackUploadCard(
                title: 'Or upload corporate employment letter',
                subtitle: 'Zero-retention Dublin processing · never stored',
                icon: Icons.description_outlined,
                onTap: _busy ? null : _pickEmploymentLetter,
              ),
            ] else ...[
              _familyBudgetCard(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ],
            if (_uploadedFileName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Received: $_uploadedFileName',
                style: const TextStyle(fontSize: 12, color: _teal),
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text(
                'Not now',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkedInCard() {
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: HomeMarketplaceTheme.border),
      ),
      child: InkWell(
        onTap: _busy ? null : _verifyWithLinkedIn,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.neutralBadgeFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.work_outline_rounded,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _busy ? 'Connecting…' : 'Verify Employment with LinkedIn',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'One-tap OpenID verification',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.linkedInBlue,
                  ),
                )
              else
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.primaryText,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _familyBudgetCard() {
    return Material(
      color: _tealSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _teal, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, color: _teal),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Confirm Rental Budget Capability',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F3D36),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '🔒 Scanned locally on your device. Raw files are never stored on our servers.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF2D6A62),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            AppButton(
              label: _busy ? 'Processing…' : 'Upload bank statement summary',
              onPressed: _busy ? null : _pickFamilyBudgetProof,
              isLoading: _busy,
              isDisabled: _busy,
              isFullWidth: true,
              variant: AppButtonVariant.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: HomeMarketplaceTheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: _indigo, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1E21),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.upload_file_rounded, color: _indigo, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
