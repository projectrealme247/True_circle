import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../utils/target_search_areas.dart';
import 'area_macro_filter_sheet.dart';

/// Premium tap-target that opens a coral-branded area checklist sheet.
class TargetSearchAreaField extends StatelessWidget {
  const TargetSearchAreaField({
    super.key,
    required this.selectedKeys,
    required this.onChanged,
  });

  final List<String> selectedKeys;
  final ValueChanged<List<String>> onChanged;

  static const _fieldLabel = 'Target Search Areas (Where you want to live)';
  static const _emptyHint = 'Tap to select areas...';

  Future<void> _openPicker(BuildContext context) async {
    final result = await showAreaMacroFilterSheet(
      context,
      initialSelection: selectedKeys.isEmpty
          ? TargetSearchAreas.allDublinFilterTokens
          : selectedKeys,
    );
    if (result != null) {
      onChanged(TargetSearchAreas.normalizeMacroTokens(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedKeys.isNotEmpty;
    final preview = hasSelection
        ? TargetSearchAreas.displaySummary(selectedKeys)
        : _emptyHint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          _fieldLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openPicker(context),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF9CA3AF)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        fontWeight:
                            hasSelection ? FontWeight.w500 : FontWeight.w400,
                        color: hasSelection
                            ? AppColors.primaryText
                            : AppColors.secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: hasSelection
                        ? AppColors.accent
                        : AppColors.secondaryText,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
