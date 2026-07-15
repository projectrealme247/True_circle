import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../utils/target_search_areas.dart';

/// Area-first macro region picker (Dublin v2 primary filter).
Future<List<String>?> showAreaMacroFilterSheet(
  BuildContext context, {
  required List<String> initialSelection,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _AreaMacroFilterSheet(
      initialSelection: initialSelection.isEmpty
          ? TargetSearchAreas.allDublinFilterTokens
          : initialSelection,
    ),
  );
}

class _AreaMacroFilterSheet extends StatefulWidget {
  const _AreaMacroFilterSheet({required this.initialSelection});

  final List<String> initialSelection;

  @override
  State<_AreaMacroFilterSheet> createState() => _AreaMacroFilterSheetState();
}

class _AreaMacroFilterSheetState extends State<_AreaMacroFilterSheet> {
  late List<String> _draft;

  @override
  void initState() {
    super.initState();
    _draft = List<String>.from(widget.initialSelection);
    if (_draft.isEmpty) _draft = TargetSearchAreas.allDublinFilterTokens;
  }

  void _toggle(String key) {
    setState(() {
      _draft = TargetSearchAreas.toggleMacroSelection(_draft, key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = TargetSearchAreas.primaryFilterOptions;
    final allDublinActive = TargetSearchAreas.hasAllDublin(_draft);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.55;

    return SafeArea(
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
              Text('Area', style: AppTypography.h3),
              const SizedBox(height: 4),
              Text(
                'Choose one or more regions. All Dublin searches city-wide.',
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
                    final isAll = key == TargetSearchAreas.allDublinToken;
                    return CheckboxListTile(
                      value: _draft.contains(key) ||
                          (isAll && allDublinActive),
                      onChanged: (_) => _toggle(key),
                      activeColor: AppColors.accent,
                      checkColor: Colors.white,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        isAll ? '✅ $label' : label,
                        style: TextStyle(
                          fontWeight: isAll || _draft.contains(key)
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: !isAll && allDublinActive
                              ? AppColors.disabled
                              : AppColors.primaryText,
                        ),
                      ),
                      secondary: isAll
                          ? Icon(
                              Icons.travel_explore_rounded,
                              size: 20,
                              color: allDublinActive
                                  ? AppColors.accent
                                  : AppColors.secondaryText,
                            )
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, List<String>.from(_draft)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<List<String>?> showAreaRefinementFilterSheet(
  BuildContext context, {
  required List<String> initialSelection,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _AreaRefinementFilterSheet(
      initialSelection: initialSelection,
    ),
  );
}

class _AreaRefinementFilterSheet extends StatefulWidget {
  const _AreaRefinementFilterSheet({required this.initialSelection});

  final List<String> initialSelection;

  @override
  State<_AreaRefinementFilterSheet> createState() =>
      _AreaRefinementFilterSheetState();
}

class _AreaRefinementFilterSheetState extends State<_AreaRefinementFilterSheet> {
  late List<String> _draft;

  @override
  void initState() {
    super.initState();
    _draft = List<String>.from(widget.initialSelection);
  }

  void _toggle(String key) {
    setState(() {
      _draft = TargetSearchAreas.toggleRefinementSelection(_draft, key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = TargetSearchAreas.postcodeRefinementOptions;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.72;

    return SafeArea(
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
              Text('Refine Area', style: AppTypography.h3),
              const SizedBox(height: 4),
              Text(
                'Optional postcode refinement within your selected regions.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final (key, label) = options[index];
                    return CheckboxListTile(
                      value: _draft.contains(key),
                      onChanged: (_) => _toggle(key),
                      activeColor: AppColors.accent,
                      checkColor: Colors.white,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(label),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, List<String>.from(_draft)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
