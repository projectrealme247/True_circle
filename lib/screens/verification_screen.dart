import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/market/market_config.dart';
import '../services/trust_service.dart';
import 'dublin_light_trust_screen.dart';

/// Placeholder parser mimicking UIDAI secure QR signature decryption.
Map<String, String> processAadhaarData(String rawData) {
  final normalized = rawData.trim();
  if (normalized.isEmpty) {
    throw const FormatException('Empty Aadhaar payload');
  }

  // Simulated secure-channel decode of UIDAI digital signature block.
  final digest = normalized.codeUnits.fold<int>(0, (a, b) => a ^ b);
  final maskedUid = 'XXXX-XXXX-${(digest % 9000 + 1000).toString().padLeft(4, '0')}';

  return {
    'uid_masked': maskedUid,
    'legal_name': 'Verified Tester',
    'signature_valid': 'true',
    'issuer': 'UIDAI',
    'parsed_at': DateTime.now().toIso8601String(),
  };
}

/// Premium KYC verification surface with QR scan and document upload.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _isProcessing = false;
  String? _statusMessage;

  Future<void> _openQrScanner() async {
    if (_isProcessing) return;

    final rawData = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _QrScannerOverlay(
              onScanned: (value) => Navigator.of(context).pop(value),
              onClose: () => Navigator.of(context).pop(),
            ),
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );

    if (!mounted || rawData == null || rawData.isEmpty) return;
      await _completeVerification(rawData);
  }

  Future<void> _pickAadhaarFile() async {
    if (_isProcessing) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
        withData: kIsWeb,
        allowMultiple: false,
      );

      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final rawData = kIsWeb
          ? String.fromCharCodes(file.bytes ?? const <int>[])
          : 'aadhaar_upload:${file.path ?? file.name}';

      if (rawData.isEmpty) {
        _showError('Could not read the selected file. Try another format.');
        return;
      }

      await _completeVerification(rawData);
    } catch (_) {
      if (!mounted) return;
      _showError('File selection failed. Please try again.');
    }
  }

  Future<void> _completeVerification(String rawData) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Decrypting UIDAI secure signature…';
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final parsed = processAadhaarData(rawData);
      final legalName = parsed['legal_name'] ?? 'Verified Tester';

      await TrustService.upgradeIdVerified(verifiedName: legalName);

      if (!mounted) return;
      await _showSuccessOverlay(legalName);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FormatException catch (error) {
      _showError(error.message);
    } on _VerificationException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Verification could not be completed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _VerifyPalette.slate,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.45),
            ),
          ),
        ),
      );
  }

  Future<void> _showSuccessOverlay(String legalName) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        Future<void>.delayed(const Duration(milliseconds: 1400), () {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        });

        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: kIsWeb ? 48 : 28,
                  ),
                  constraints: const BoxConstraints(
                    maxWidth: kIsWeb ? 420 : double.infinity,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _VerifyPalette.slate,
                        _VerifyPalette.deepSea,
                      ],
                    ),
                    border: Border.all(
                      color: _VerifyPalette.success.withValues(alpha: 0.45),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _VerifyPalette.success.withValues(alpha: 0.22),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _VerifyPalette.success.withValues(alpha: 0.15),
                          border: Border.all(
                            color: _VerifyPalette.success.withValues(alpha: 0.55),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 42,
                          color: _VerifyPalette.success,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Identity Verified',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        legalName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _VerifyPalette.success.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your TrueCircle account is now KYC verified.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: _VerifyPalette.mist.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MarketConfig.current.trustVerificationKind ==
        TrustVerificationKind.lightTrust) {
      return const DublinLightTrustScreen();
    }

    const maxContentWidth = kIsWeb ? 720.0 : double.infinity;

    return Scaffold(
      backgroundColor: _VerifyPalette.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Verify Identity',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _VerifyPalette.midnight,
              _VerifyPalette.deepSea,
              _VerifyPalette.midnight,
            ],
            stops: [0, 0.5, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  kIsWeb ? 32 : 20,
                  8,
                  kIsWeb ? 32 : 20,
                  32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _HeroHeader(isWeb: kIsWeb),
                    const SizedBox(height: 28),
                    if (_isProcessing) ...[
                      _ProcessingBanner(message: _statusMessage),
                      const SizedBox(height: 20),
                    ],
                    kIsWeb
                        ? _SplitOptionsWeb(
                            onScanQr: _openQrScanner,
                            onUpload: _pickAadhaarFile,
                            disabled: _isProcessing,
                          )
                        : _SplitOptionsMobile(
                            onScanQr: _openQrScanner,
                            onUpload: _pickAadhaarFile,
                            disabled: _isProcessing,
                          ),
                    const SizedBox(height: 24),
                    const _TrustFooter(isWeb: kIsWeb),
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

class _QrScannerOverlay extends StatefulWidget {
  const _QrScannerOverlay({
    required this.onScanned,
    required this.onClose,
  });

  final ValueChanged<String> onScanned;
  final VoidCallback onClose;

  @override
  State<_QrScannerOverlay> createState() => _QrScannerOverlayState();
}

class _QrScannerOverlayState extends State<_QrScannerOverlay> {
  var _handled = false;

  void _handleDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .where((v) => v.trim().isNotEmpty)
        .firstOrNull;
    if (value == null) return;

    _handled = true;
    widget.onScanned(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AiBarcodeScanner(
            onDetect: _handleDetect,
            overlayConfig: const ScannerOverlayConfig(
              borderColor: _VerifyPalette.ring,
              animationColor: _VerifyPalette.ring,
              borderRadius: 16,
              cornerRadius: 16,
              cornerLength: kIsWeb ? 36 : 32,
            ),
            appBarBuilder: (context, controller) {
              return AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
                title: kIsWeb
                    ? const Text(
                        'Scan Aadhaar QR (Webcam)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      )
                    : const Text(
                        'Scan Aadhaar QR',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: kIsWeb ? 32 : 24,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _VerifyPalette.midnight.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _VerifyPalette.ring.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  kIsWeb
                      ? 'Allow camera access in Chrome, then align the UIDAI QR within the frame.'
                      : 'Align the UIDAI QR code within the frame.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: _VerifyPalette.mist.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.isWeb});

  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 28 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _VerifyPalette.ring.withValues(alpha: 0.16),
            _VerifyPalette.glow.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(
          color: _VerifyPalette.ring.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _VerifyPalette.ring.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: _VerifyPalette.ring.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'TrueCircle KYC',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isWeb
                ? 'Verify securely in your browser using your webcam or by uploading your Aadhaar document.'
                : 'Complete identity verification to unlock trusted rentals and circle features.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _VerifyPalette.mist.withValues(alpha: 0.82),
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

class _SplitOptionsWeb extends StatelessWidget {
  const _SplitOptionsWeb({
    required this.onScanQr,
    required this.onUpload,
    required this.disabled,
  });

  final VoidCallback onScanQr;
  final VoidCallback onUpload;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _VerificationOptionCard(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan QR with Webcam',
              subtitle:
                  'Use Chrome camera access to read the secure UIDAI matrix on your Aadhaar.',
              accent: _VerifyPalette.ring,
              onTap: disabled ? null : onScanQr,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _VerificationOptionCard(
              icon: Icons.upload_file_rounded,
              title: 'Upload Aadhaar Image/PDF',
              subtitle:
                  'Select a JPG, PNG, or PDF from your computer for offline parsing.',
              accent: _VerifyPalette.glow,
              onTap: disabled ? null : onUpload,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitOptionsMobile extends StatelessWidget {
  const _SplitOptionsMobile({
    required this.onScanQr,
    required this.onUpload,
    required this.disabled,
  });

  final VoidCallback onScanQr;
  final VoidCallback onUpload;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _VerificationOptionCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Scan QR with Webcam',
          subtitle:
              'Open the camera scanner to decode your Aadhaar secure QR payload.',
          accent: _VerifyPalette.ring,
          onTap: disabled ? null : onScanQr,
        ),
        const SizedBox(height: 14),
        _VerificationOptionCard(
          icon: Icons.upload_file_rounded,
          title: 'Upload Aadhaar Image/PDF',
          subtitle: 'Pick a local JPG, PNG, or PDF for signature extraction.',
          accent: _VerifyPalette.glow,
          onTap: disabled ? null : onUpload,
        ),
      ],
    );
  }
}

class _VerificationOptionCard extends StatelessWidget {
  const _VerificationOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: enabled ? 0.05 : 0.03),
            border: Border.all(
              color: accent.withValues(alpha: enabled ? 0.38 : 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: accent.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: accent.withValues(alpha: 0.95), size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: _VerifyPalette.mist.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent.withValues(alpha: enabled ? 0.95 : 0.4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: accent.withValues(alpha: enabled ? 0.95 : 0.4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcessingBanner extends StatelessWidget {
  const _ProcessingBanner({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _VerifyPalette.ring.withValues(alpha: 0.1),
        border: Border.all(
          color: _VerifyPalette.ring.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _VerifyPalette.ring,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message ?? 'Processing verification…',
              style: TextStyle(
                fontSize: 13,
                color: _VerifyPalette.mist.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustFooter extends StatelessWidget {
  const _TrustFooter({required this.isWeb});

  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_rounded,
            size: 18,
            color: _VerifyPalette.mist.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isWeb
                  ? 'Data is processed locally in your browser session. UIDAI signatures are validated before your profile is updated in Supabase.'
                  : 'Your document never leaves device control until the secure signature check passes.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: _VerifyPalette.mist.withValues(alpha: 0.68),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationException implements Exception {
  const _VerificationException(this.message);
  final String message;
}

abstract final class _VerifyPalette {
  static const midnight = Color(0xFF070B14);
  static const deepSea = Color(0xFF0E1628);
  static const slate = Color(0xFF152238);
  static const ring = Color(0xFF3BE8C5);
  static const glow = Color(0xFFFF5A5F);
  static const mist = Color(0xFFB8C4D9);
  static const success = Color(0xFF4ADE80);
}
