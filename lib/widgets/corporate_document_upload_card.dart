import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../services/corporate_document_verify_service.dart';

/// Corporate Track document upload — streams to Dublin edge runtime (zero-retention).
class CorporateDocumentUploadCard extends StatefulWidget {
  const CorporateDocumentUploadCard({
    super.key,
    required this.onVerified,
  });

  final VoidCallback onVerified;

  @override
  State<CorporateDocumentUploadCard> createState() =>
      _CorporateDocumentUploadCardState();
}

class _CorporateDocumentUploadCardState extends State<CorporateDocumentUploadCard> {
  bool _busy = false;
  String? _error;
  String? _successFileName;

  Future<void> _pickAndVerify() async {
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
          'Could not read this file. Try exporting a PDF from your employer.',
        );
      }

      final payload = Uint8List.fromList(bytes);
      await CorporateDocumentVerifyService.verifyCorporateDocument(
        fileBytes: payload,
        fileName: file.name,
      );

      if (!mounted) return;
      setState(() {
        _successFileName = file.name;
        _busy = false;
      });
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
        _error =
            'We could not verify this document. Try a clearer PDF or offer letter.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Corporate Verification',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryText,
                        ),
                      ),
                      Text(
                        'Upload contract or offer letter (PDF / image)',
                        style: AppTypography.caption.copyWith(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '🔒 Processed in-memory in our Dublin datacenter. Raw files are never stored.',
              style: AppTypography.caption.copyWith(
                fontSize: 11.5,
                color: AppColors.secondaryText,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _pickAndVerify,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(_busy ? 'Verifying…' : 'Upload employment document'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.error,
                  height: 1.4,
                ),
              ),
            ],
            if (_successFileName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Verified: $_successFileName · 👍 Grand tier active',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
