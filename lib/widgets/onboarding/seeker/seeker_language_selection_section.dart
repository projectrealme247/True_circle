import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../theme/app_scroll_behavior.dart';
import '../../../utils/ireland_language_catalog.dart';
import '../../shadcn_select.dart';
import '../onboarding_choice_chip.dart';
import '../onboarding_design_tokens.dart';
import '../onboarding_field_block.dart';

/// English baseline + primary language + suggested related chips + custom add.
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

  bool _isEnglish(String language) => language.toLowerCase() == 'english';

  bool _isSelected(String language) => selectedSecondaryLanguages.any(
        (selected) => selected.toLowerCase() == language.toLowerCase(),
      );

  @override
  Widget build(BuildContext context) {
    final suggestionChips = [
      for (final language in suggestedLanguages)
        if (!_matchesPrimary(language) &&
            !_isEnglish(language) &&
            !_isSelected(language))
          language,
    ];
    final selectedChips = [
      for (final language in selectedSecondaryLanguages)
        if (!_isEnglish(language) && !_matchesPrimary(language)) language,
    ];

    return SeekerOnboardingLayout.constrainOptionCluster(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: OnboardingTokens.space12,
              vertical: OnboardingTokens.space8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OnboardingTokens.inputBorder),
            ),
            child: Text(
              'English — default communication language',
              style: SeekerOnboardingLayout.fieldLabel.copyWith(
                color: const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(height: OnboardingTokens.space8),
          ShadcnSelect(
            label: 'Additional primary language',
            value: primaryLanguage.isEmpty || _isEnglish(primaryLanguage)
                ? ''
                : primaryLanguage,
            hint: 'e.g. Telugu, Polish, Spanish',
            options: [
              for (final language in IrelandLanguageCatalog.all)
                if (!_isEnglish(language)) language,
            ],
            onChanged: onPrimaryLanguageChanged,
            seekerTypography: true,
          ),
          if (suggestionChips.isNotEmpty) ...[
            const SizedBox(height: OnboardingTokens.space8),
            OnboardingFieldBlock(
              label: '💬 Suggested related languages',
              child: Wrap(
                key: ValueKey(
                  'fluent-wrap-$primaryLanguage-${suggestionChips.join('|')}-'
                  '${selectedSecondaryLanguages.join('|')}',
                ),
                spacing: OnboardingTokens.chipSpacing,
                runSpacing: OnboardingTokens.chipSpacing,
                children: [
                  for (final language in suggestionChips)
                    OnboardingLanguageToggleChip(
                      key: ValueKey('fluent-chip-$primaryLanguage-$language'),
                      label: language,
                      selected: false,
                      onTap: () => onAddSecondaryLanguage(language),
                    ),
                  _AddCustomLanguageButton(
                    onTap: () => _showAddLanguageSheet(context),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: OnboardingTokens.space8),
            Align(
              alignment: Alignment.centerLeft,
              child: _AddCustomLanguageButton(
                onTap: () => _showAddLanguageSheet(context),
              ),
            ),
          ],
          if (selectedChips.isNotEmpty) ...[
            const SizedBox(height: OnboardingTokens.space8),
            Wrap(
              spacing: OnboardingTokens.chipSpacing,
              runSpacing: OnboardingTokens.chipSpacing,
              children: [
                for (final language in selectedChips)
                  _DismissibleLanguageChip(
                    label: language,
                    onDismiss: () => onToggleSecondaryLanguage(language),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddLanguageSheet(BuildContext context) async {
    final controller = TextEditingController();
    final excluded = {
      'english',
      if (primaryLanguage.isNotEmpty) primaryLanguage.toLowerCase(),
      for (final language in suggestedLanguages) language.toLowerCase(),
      for (final language in selectedSecondaryLanguages)
        language.toLowerCase(),
    };

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(OnboardingTokens.space16),
        ),
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
                left: OnboardingTokens.space16,
                right: OnboardingTokens.space16,
                top: OnboardingTokens.space16,
                bottom: MediaQuery.viewInsetsOf(context).bottom +
                    OnboardingTokens.space16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add another language',
                    style: SeekerOnboardingLayout.sectionLabel,
                  ),
                  const SizedBox(height: OnboardingTokens.space12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: SeekerOnboardingLayout.inputValue,
                    decoration: OnboardingTokens.inputDecoration(
                      hint: 'Search languages…',
                    ),
                    onChanged: applyFilter,
                  ),
                  const SizedBox(height: OnboardingTokens.space12),
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
                                  title: Text(
                                    language,
                                    style: SeekerOnboardingLayout.inputValue,
                                  ),
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
      final token = selected.trim();
      if (_isEnglish(token)) return;
      if (primaryLanguage.isEmpty || _isEnglish(primaryLanguage)) {
        onPrimaryLanguageChanged(token);
      } else if (!_matchesPrimary(token)) {
        onAddSecondaryLanguage(token);
      }
    }
  }
}

class _AddCustomLanguageButton extends StatelessWidget {
  const _AddCustomLanguageButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: OnboardingTokens.space12,
            vertical: OnboardingTokens.space4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            '+ Add Custom Language',
            style: SeekerOnboardingLayout.chipText.copyWith(
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _DismissibleLanguageChip extends StatelessWidget {
  const _DismissibleLanguageChip({
    required this.label,
    required this.onDismiss,
  });

  final String label;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 28,
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.accent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: SeekerOnboardingLayout.chipText.copyWith(
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: OnboardingTokens.space4),
            InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(OnboardingTokens.space4),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
