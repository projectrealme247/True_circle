import 'package:flutter/material.dart';

import '../content/legal_copy.dart';
import '../core/theme/app_theme.dart';

/// Public scrollable legal document (Terms / Privacy).
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final List<LegalSection> sections;

  factory LegalDocumentScreen.terms({Key? key}) {
    return LegalDocumentScreen(
      key: key,
      title: LegalCopy.termsTitle,
      sections: LegalCopy.termsSections,
    );
  }

  factory LegalDocumentScreen.privacy({Key? key}) {
    return LegalDocumentScreen(
      key: key,
      title: LegalCopy.privacyTitle,
      sections: LegalCopy.privacySections,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryText,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Text(
              LegalCopy.draftBanner,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 22),
            Text(
              sections[i].heading,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sections[i].body,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
