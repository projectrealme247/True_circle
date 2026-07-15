import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../utils/ireland_language_catalog.dart';
import 'onboarding_design_tokens.dart';

/// Dismissible spoken-language chips with deduplication and add-language affordance.
class OnboardingSpokenLanguageChips extends StatelessWidget {
  const OnboardingSpokenLanguageChips({
    super.key,
    required this.languages,
    required this.motherTongue,
    required this.onRemove,
    required this.onAdd,
  });

  final List<String> languages;
  final String motherTongue;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💬 Languages spoken',
          style: OnboardingTokens.sectionLabelStyle,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: OnboardingTokens.chipSpacing,
          runSpacing: OnboardingTokens.chipSpacing,
          children: [
            for (final language in languages)
              _LanguageChip(
                label: language,
                dismissible: language != motherTongue || languages.length > 1,
                onDismiss: () => onRemove(language),
              ),
            _AddLanguageChip(onTap: () => _showAddLanguageSheet(context)),
          ],
        ),
      ],
    );
  }

  Future<void> _showAddLanguageSheet(BuildContext context) async {
    final controller = TextEditingController();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        var filtered = IrelandLanguageCatalog.all
            .where((l) => !languages.any((s) => s.toLowerCase() == l.toLowerCase()))
            .toList();

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void applyFilter(String query) {
              setSheetState(() {
                filtered = IrelandLanguageCatalog.filterByQuery(query)
                    .where((l) =>
                        !languages.any((s) => s.toLowerCase() == l.toLowerCase()))
                    .toList();
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add a language',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: OnboardingTokens.inputDecoration(
                      hint: 'Search languages…',
                    ),
                    onChanged: applyFilter,
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final language = filtered[index];
                        return Material(
                          color: Colors.white,
                          child: ListTile(
                            dense: true,
                            title: Text(language),
                            onTap: () => Navigator.pop(ctx, language),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    controller.dispose();
    if (selected != null && selected.trim().isNotEmpty) {
      onAdd(selected.trim());
    }
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.dismissible,
    required this.onDismiss,
  });

  final String label;
  final bool dismissible;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          if (dismissible) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddLanguageChip extends StatelessWidget {
  const _AddLanguageChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.45),
            ),
          ),
          child: const Text(
            '+ Add Language',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}
