import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../utils/target_search_areas.dart';

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
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _TargetSearchAreaPickerSheet(
        initialSelection: List<String>.from(selectedKeys),
      ),
    );
    if (result != null) {
      onChanged(TargetSearchAreas.normalizeTokens(result));
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

class _TargetSearchAreaPickerSheet extends StatefulWidget {
  const _TargetSearchAreaPickerSheet({required this.initialSelection});

  final List<String> initialSelection;

  @override
  State<_TargetSearchAreaPickerSheet> createState() =>
      _TargetSearchAreaPickerSheetState();
}

class _TargetSearchAreaPickerSheetState
    extends State<_TargetSearchAreaPickerSheet> {
  late List<String> _draft;

  @override
  void initState() {
    super.initState();
    _draft = List<String>.from(widget.initialSelection);
  }

  void _toggle(String key) {
    setState(() {
      _draft = TargetSearchAreas.toggleSelection(_draft, key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = TargetSearchAreas.selectableOptions;
    final allDublinActive = TargetSearchAreas.hasAllDublin(_draft);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.72;

    return Theme(
      data: Theme.of(context).copyWith(
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.accent;
            }
            return Colors.transparent;
          }),
          checkColor: WidgetStateProperty.all(Colors.white),
          side: const BorderSide(color: AppColors.divider, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Target Search Areas', style: AppTypography.h3),
                const SizedBox(height: 4),
                Text(
                  'Choose where you want to live. "All of Dublin" searches city-wide.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (context, index) =>
                        index == 0 ? const Divider(height: 1) : const SizedBox(),
                    itemBuilder: (context, index) {
                      final (key, label) = options[index];
                      return _AreaCheckTile(
                        optionKey: key,
                        label: label,
                        isMacro: key == TargetSearchAreas.allDublinToken,
                        checked: _draft.contains(key),
                        enabled: key == TargetSearchAreas.allDublinToken ||
                            !allDublinActive,
                        onToggle: () => _toggle(key),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, List<String>.from(_draft)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AreaCheckTile extends StatelessWidget {
  const _AreaCheckTile({
    required this.optionKey,
    required this.label,
    required this.isMacro,
    required this.checked,
    required this.enabled,
    required this.onToggle,
  });

  final String optionKey;
  final String label;
  final bool isMacro;
  final bool checked;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: checked,
      onChanged: enabled ? (_) => onToggle() : null,
      activeColor: AppColors.accent,
      checkColor: Colors.white,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(
          fontSize: isMacro ? 15 : 14,
          fontWeight: isMacro || checked ? FontWeight.w600 : FontWeight.w500,
          color: enabled
              ? (checked ? AppColors.accentDark : AppColors.primaryText)
              : AppColors.disabled,
        ),
      ),
      secondary: isMacro
          ? Icon(
              Icons.travel_explore_rounded,
              size: 20,
              color: checked ? AppColors.accent : AppColors.secondaryText,
            )
          : null,
    );
  }
}
