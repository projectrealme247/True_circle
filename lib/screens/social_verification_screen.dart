import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/trust_service.dart';
import '../utils/viewer_profile.dart';

/// Stage 2: Social verification via LinkedIn.
/// In production, this would use LinkedIn OAuth to pull real data.
/// Currently simulates the flow with manual input.
class SocialVerificationScreen extends StatefulWidget {
  const SocialVerificationScreen({super.key});

  @override
  State<SocialVerificationScreen> createState() =>
      _SocialVerificationScreenState();
}

class _SocialVerificationScreenState extends State<SocialVerificationScreen> {
  final _companyController = TextEditingController();
  final _titleController = TextEditingController();
  bool _verifying = false;
  bool _verified = false;

  @override
  void dispose() {
    _companyController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _simulateLinkedInVerification() async {
    if (_companyController.text.trim().isEmpty ||
        _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your company and job title')),
      );
      return;
    }

    setState(() => _verifying = true);

    // Simulate OAuth delay
    await Future.delayed(const Duration(milliseconds: 1500));

    await TrustService.upgradeSocial(
      company: _companyController.text.trim(),
      jobTitle: _titleController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _verifying = false;
      _verified = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentStage = TrustService.currentStage();
    final alreadyVerified =
        currentStage.level >= TrustStage.socialVerified.level;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Social Verification'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1E21),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A66C2).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: Color(0xFF0A66C2),
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
                                    color: Color(0xFF1C1E21),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  alreadyVerified || _verified
                                      ? 'Stage 2 verified — 0.9x trust multiplier'
                                      : 'Boost your trust score to 0.9x',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF606770),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (alreadyVerified || _verified) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF16A34A), size: 22),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Social verification complete. Your listings now rank higher.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF166534),
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
                          child: FilledButton(
                            onPressed: () => context.go('/profile'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0EA5E9),
                            ),
                            child: const Text('Back to profile'),
                          ),
                        ),
                      ] else ...[
                        TextField(
                          controller: _companyController,
                          decoration: InputDecoration(
                            labelText: 'Company',
                            hintText: 'e.g. Google, TCS, Infosys',
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
                        const SizedBox(height: 8),
                        const Text(
                          'In production, this connects via LinkedIn OAuth. '
                          'Your company and title will be shown as a trust badge on your listings.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _verifying
                                ? null
                                : _simulateLinkedInVerification,
                            icon: _verifying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.link_rounded),
                            label: Text(
                              _verifying
                                  ? 'Verifying...'
                                  : 'Verify with LinkedIn',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0A66C2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your trust level',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF606770),
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
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFD1D5DB),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Stage ${s.level}: ${s.label}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: stage == s
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: stage.level >= s.level
                            ? const Color(0xFF1C1E21)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${s.multiplier}x',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: stage.level >= s.level
                            ? const Color(0xFF0EA5E9)
                            : const Color(0xFFD1D5DB),
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
