import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../theme/app_scroll_behavior.dart';
import '../../../utils/ireland_language_catalog.dart';
import '../../shadcn_select.dart';
import '../onboarding_design_tokens.dart';
import '../onboarding_field_block.dart';
import '../onboarding_choice_chip.dart';

/// Two-tier language selection — primary dropdown + fluent secondary chips.
class SeekerLanguageSelectionSection extends StatelessWidget {
  const SeekerLanguageSelectionSection({
    super.key,
    required this.primaryLanguage,
    required this.onPrimaryLanguageChanged,
    required this.suggestedLanguages,
    required this.selectedSecondaryLanguages,
    required this.onToggleSecondaryLanguage,
    required this.onAddSecondaryLanguage,
  });

  final String primaryLanguage;
  final ValueChanged<String> onPrimaryLanguageChanged;
  final List<String> suggestedLanguages;
  final Set<String> selectedSecondaryLanguages;
  final ValueChanged<String> onToggleSecondaryLanguage;
  final ValueChanged<String> onAddSecondaryLanguage;

  bool _matchesPrimary(String language) =>
      primaryLanguage.isNotEmpty &&
      primaryLanguage.toLowerCase() == language.toLowerCase();

  bool _isSelected(String language) => selectedSecondaryLanguages.any(
        (selected) => selected.toLowerCase() == language.toLowerCase(),
      );

  @override
  Widget build(BuildContext context) {
    final chipLanguages = [
      for (final language in suggestedLanguages)
        if (!_matchesPrimary(language)) language,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadcnSelect(
          label: 'Primary language',
          value: primaryLanguage,
          hint: 'Select your primary language',
          options: IrelandLanguageCatalog.all,
          onChanged: onPrimaryLanguageChanged,
        ),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        OnboardingFieldBlock(
          label: '💬 Other languages you speak fluently',
          child: Wrap(
            key: ValueKey(
              'fluent-wrap-$primaryLanguage-${suggestedLanguages.join('|')}-'
              '${selectedSecondaryLanguages.join('|')}',
            ),
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final language in chipLanguages)
                OnboardingLanguageToggleChip(
                  key: ValueKey('fluent-chip-$primaryLanguage-$language'),
                  label: language,
                  selected: _isSelected(language),
                  onTap: () => onToggleSecondaryLanguage(language),
                ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showAddLanguageSheet(context),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Text(
                      '+ Add Other',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAddLanguageSheet(BuildContext context) async {
    final controller = TextEditingController();
    final excluded = {
      if (primaryLanguage.isNotEmpty) primaryLanguage.toLowerCase(),
      for (final language in suggestedLanguages) language.toLowerCase(),
    };

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        var options = IrelandLanguageCatalog.all;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void applyFilter(String query) {
              setSheetState(() {
                options = IrelandLanguageCatalog.filterByQuery(query);
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
                    'Add another language',
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
                    decoration: const InputDecoration(
                      hintText: 'Search languages…',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: applyFilter,
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ScrollConfiguration(
                      behavior: const OnboardingFormScrollBehavior(),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final language in options)
                            if (!excluded.contains(language.toLowerCase()))
                              Material(
                                color: Colors.white,
                                child: ListTile(
                                  dense: true,
                                  title: Text(language),
                                  onTap: () => Navigator.pop(ctx, language),
                                ),
                              ),
                        ],
                      ),
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
      onAddSecondaryLanguage(selected.trim());
    }
  }
}
