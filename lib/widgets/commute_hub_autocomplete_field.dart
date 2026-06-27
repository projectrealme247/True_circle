import 'package:flutter/material.dart';

import '../config/market/dublin_commuter_hubs.dart';
import '../core/theme/app_theme.dart';

/// Predictive hub picker — only canonical Dublin commuter anchors are accepted.
class CommuteHubAutocompleteField extends StatelessWidget {
  const CommuteHubAutocompleteField({
    super.key,
    required this.selectedHub,
    required this.onHubSelected,
    this.onCleared,
    this.label = 'Commute Destination',
  });

  final DublinCommuterHub? selectedHub;
  final ValueChanged<DublinCommuterHub> onHubSelected;
  final VoidCallback? onCleared;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<DublinCommuterHub>(
      key: ValueKey(selectedHub?.id ?? 'commute_hub_empty'),
      initialValue: selectedHub == null
          ? null
          : TextEditingValue(text: selectedHub!.label),
      displayStringForOption: (hub) => hub.label,
      optionsBuilder: (textEditingValue) {
        return DublinCommuterHubs.filterByQuery(textEditingValue.text);
      },
      onSelected: onHubSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: AppFormFields.decoration(
            labelText: label,
            hintText: 'Search Dublin commuter hubs…',
          ),
          onFieldSubmitted: (_) => onFieldSubmitted(),
          onChanged: (value) {
            if (value.trim().isEmpty) {
              onCleared?.call();
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: AppColors.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final hub = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      hub.label,
                      style: const TextStyle(fontSize: 15),
                    ),
                    onTap: () => onSelected(hub),
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
