import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../services/invite_code_service.dart';
import '../services/trust_service.dart';
import '../utils/viewer_profile.dart';

/// Lets Stage 3 users generate and share invite codes for pre-arrival students.
class ProfileInviteCodeSection extends StatefulWidget {
  const ProfileInviteCodeSection({super.key});

  @override
  State<ProfileInviteCodeSection> createState() =>
      _ProfileInviteCodeSectionState();
}

class _ProfileInviteCodeSectionState extends State<ProfileInviteCodeSection> {
  List<InviteCodeRecord> _codes = const [];
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadCodes();
  }

  Future<void> _loadCodes() async {
    setState(() => _loading = true);
    final codes = await InviteCodeService.listForCurrentUser();
    if (!mounted) return;
    setState(() {
      _codes = codes;
      _loading = false;
    });
  }

  Future<void> _generateCode() async {
    setState(() => _generating = true);
    try {
      final code = await InviteCodeService.generateForCurrentUser();
      if (!mounted) return;
      await _loadCodes();
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('Code $code copied — share with pre-arrival students')),
        );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('Copied $code')));
  }

  @override
  Widget build(BuildContext context) {
    if (TrustService.currentStage().level < TrustStage.idVerified.level) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.group_add_outlined, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Invite pre-arrival students',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1E21),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Share a code plus they upload their offer letter to contact hosts.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_codes.isEmpty)
              const Text(
                'No codes yet — generate one to vouch for someone joining from abroad.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
              )
            else
              ..._codes.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CodeRow(
                    record: record,
                    onCopy: () => _copyCode(record.code),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: _generating ? null : _generateCode,
              icon: _generating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_rounded, size: 18),
              label: Text(_generating ? 'Generating…' : 'Generate new code'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.record, required this.onCopy});

  final InviteCodeRecord record;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final exhausted = record.isExhausted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        title: Text(
          record.code,
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: exhausted ? const Color(0xFF9CA3AF) : const Color(0xFF1C1E21),
          ),
        ),
        subtitle: Text(
          exhausted
              ? 'Used ${record.maxRedemptions} times — generate a new code'
              : '${record.remaining} of ${record.maxRedemptions} uses left',
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        trailing: exhausted
            ? null
            : IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: 'Copy code',
                onPressed: onCopy,
              ),
      ),
    );
  }
}
