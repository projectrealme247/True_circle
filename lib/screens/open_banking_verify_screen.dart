import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/open_banking_controller.dart';
import '../core/theme/app_theme.dart';
import '../services/open_banking_provider.dart';

/// Open Banking AIS layout — AIB, BOI, Revolut institution picker.
/// Phase 1: legacy/deferred financial-signal check — not income or affordability verification.
class OpenBankingVerifyScreen extends StatefulWidget {
  const OpenBankingVerifyScreen({super.key});

  @override
  State<OpenBankingVerifyScreen> createState() =>
      _OpenBankingVerifyScreenState();
}

class _OpenBankingVerifyScreenState extends State<OpenBankingVerifyScreen> {
  IrishOpenBankInstitution? _connectingBank;
  String? _error;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _bootstrap() {
    final uri = GoRouter.of(context).state.uri;
    final err = uri.queryParameters['error'];
    if (err != null && err.isNotEmpty) {
      setState(() => _error = Uri.decodeComponent(err));
    }
    if (uri.queryParameters['verified'] == '1') {
      setState(() => _verified = true);
    }
  }

  Future<void> _connect(IrishOpenBankInstitution bank) async {
    setState(() {
      _connectingBank = bank;
      _error = null;
    });

    try {
      await OpenBankingController.beginInstitutionLink(bank);
      if (!mounted) return;
      setState(() => _connectingBank = null);
    } on OpenBankingException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _connectingBank = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not open the bank connection. Try again.';
        _connectingBank = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Instant Bank Link',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.primaryText,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_outlined,
                        color: AppColors.accentDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _verified
                              ? 'Banking verification completed. Additional financial signals collected.'
                              : 'Optional banking check — collect additional financial signals with a secure bank link.',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentDark,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_verified)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.successSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppColors.success),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Financial check completed. This does not verify income or rent affordability.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  const Text(
                    'Select your Irish bank',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Read-only PSD2 redirect · optional financial signals (not income or affordability verification)',
                    style: AppTypography.caption.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  for (final bank in IrishOpenBankInstitution.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _InstitutionCard(
                        bank: bank,
                        busy: _connectingBank == bank,
                        disabled: _connectingBank != null,
                        onTap: () => _connect(bank),
                      ),
                    ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.error,
                      height: 1.4,
                    ),
                  ),
                ],
                if (OpenBankingController.usesMock) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Mock mode: simulated AIS handshake.',
                    style: AppTypography.caption.copyWith(fontSize: 11),
                  ),
                ],
                const SizedBox(height: 16),
                const _OpenBankingPrivacyFooter(),
                if (_verified) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.go('/profile'),
                    child: const Text('Back to profile'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InstitutionCard extends StatelessWidget {
  const _InstitutionCard({
    required this.bank,
    required this.busy,
    required this.disabled,
    required this.onTap,
  });

  final IrishOpenBankInstitution bank;
  final bool busy;
  final bool disabled;
  final VoidCallback onTap;

  IconData get _icon => switch (bank) {
        IrishOpenBankInstitution.aib => Icons.account_balance_rounded,
        IrishOpenBankInstitution.boi => Icons.savings_outlined,
        IrishOpenBankInstitution.revolut => Icons.credit_card_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: AppColors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bank.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      busy ? 'Opening secure session…' : 'PSD2 account information (read-only)',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenBankingPrivacyFooter extends StatelessWidget {
  const _OpenBankingPrivacyFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        '🔒 Dublin Data Privacy Shield: TrueCircle uses zero-retention '
        'ephemeral processing. Banking records are read in memory for an '
        'optional financial check and then destroyed. We never store raw '
        'files, transaction histories, or salary figures. This check does '
        'not verify income or rent affordability.',
        style: AppTypography.caption.copyWith(
          fontSize: 11.5,
          color: AppColors.secondaryText,
          height: 1.55,
        ),
      ),
    );
  }
}
