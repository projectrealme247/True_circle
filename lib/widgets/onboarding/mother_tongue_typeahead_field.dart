import 'package:flutter/material.dart';

import '../../utils/ireland_language_catalog.dart';
import 'onboarding_design_tokens.dart';

/// Searchable mother-tongue picker covering common languages in Ireland.
class MotherTongueTypeaheadField extends StatelessWidget {
  const MotherTongueTypeaheadField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      key: ValueKey(value),
      initialValue: TextEditingValue(text: value),
      displayStringForOption: (option) => option,
      optionsBuilder: (textEditingValue) {
        return IrelandLanguageCatalog.filterByQuery(textEditingValue.text);
      },
      onSelected: onChanged,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🗣️ Mother tongue',
              style: OnboardingTokens.sectionLabelStyle,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              focusNode: focusNode,
              onFieldSubmitted: (_) => onFieldSubmitted(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
              decoration: OnboardingTokens.inputDecoration(
                hint: 'Search languages…',
              ),
              onChanged: (text) {
                final match = IrelandLanguageCatalog.all
                    .where((l) => l.toLowerCase() == text.trim().toLowerCase())
                    .firstOrNull;
                if (match != null && match != value) {
                  onChanged(match);
                }
              },
            ),
          ],
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final language = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      language,
                      style: const TextStyle(fontSize: 15),
                    ),
                    onTap: () => onSelected(language),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
