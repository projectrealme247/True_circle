import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/listing_report.dart';
import '../screens/auth_screen.dart';
import '../services/listing_report_service.dart';
import '../widgets/listing_detail_tokens.dart';

/// Trust & Safety Phase 1 — capture a listing report for later admin review.
class ReportListingBottomSheet extends StatefulWidget {
  const ReportListingBottomSheet({
    super.key,
    required this.listingId,
  });

  final String listingId;

  static Future<void> show(
    BuildContext context, {
    required String listingId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReportListingBottomSheet(listingId: listingId),
    );
  }

  @override
  State<ReportListingBottomSheet> createState() =>
      _ReportListingBottomSheetState();
}

class _ReportListingBottomSheetState extends State<ReportListingBottomSheet> {
  ListingReportReason? _reason;
  final _detailsController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'Select a reason to continue.');
      return;
    }
    if (_submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ListingReportService.submitListingReport(
        listingId: widget.listingId,
        reason: reason,
        details: _detailsController.text,
        session: AuthScreen.currentUserSession,
      );
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not send your report. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: _submitted ? _buildSuccess() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.check_circle_outline, size: 40, color: AppColors.success),
        const SizedBox(height: 16),
        const Text(
          'Thank you. We have received your report and will review it.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: ListingDetailTokens.charcoal,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: AppButtonStyles.primaryFilled,
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Report Listing',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ListingDetailTokens.charcoal,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tell us what is wrong. Reports stay private and help keep TrueCircle safe.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          for (final reason in ListingReportReason.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              enabled: !_submitting,
              onTap: _submitting
                  ? null
                  : () => setState(() {
                        _reason = reason;
                        _error = null;
                      }),
              leading: Icon(
                _reason == reason
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: _reason == reason
                    ? AppColors.accent
                    : AppColors.secondaryText,
                size: 22,
              ),
              title: Text(
                reason.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: ListingDetailTokens.charcoal,
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _detailsController,
            enabled: !_submitting,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Additional details',
              hintText: 'Optional',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: AppButtonStyles.primaryFilled,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit report'),
          ),
        ],
      ),
    );
  }
}
