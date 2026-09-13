import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Landlord-matched chip chrome for Shared Spaces seeker onboarding.
abstract final class SeekerSharedChipStyle {
  static const borderOn = Color(0xFF1A1A1A);
  static const borderOff = Color(0xFFE0E0E0);
  static const labelOn = Color(0xFF1A1A1A);
  static const labelOff = Color(0xFF666666);
  static const subtitle = Color(0xFF888888);
  static const sectionGap = 12.0;
  static const headerToContent = 6.0;
  static const chipGap = 8.0;
  static const groupInnerGap = 12.0;

  static const sectionTitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1A1A1A),
    height: 1.25,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  static const sectionSubtitleStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: subtitle,
    height: 1.35,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  static const fieldLabelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Color(0xFF1A1A1A),
    height: 1.25,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  static const chipLabelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.2,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );
}

class SeekerSharedSectionHeader extends StatelessWidget {
  const SeekerSharedSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: SeekerSharedChipStyle.sectionTitleStyle),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: SeekerSharedChipStyle.sectionSubtitleStyle),
        ],
      ],
    );
  }
}

class SeekerSharedFieldLabel extends StatelessWidget {
  const SeekerSharedFieldLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: SeekerSharedChipStyle.fieldLabelStyle);
  }
}

class SeekerSharedChoiceBrick extends StatelessWidget {
  const SeekerSharedChoiceBrick({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.textAlign = TextAlign.center,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? SeekerSharedChipStyle.borderOn
                  : SeekerSharedChipStyle.borderOff,
              width: selected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: textAlign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SeekerSharedChipStyle.chipLabelStyle.copyWith(
              color: selected
                  ? SeekerSharedChipStyle.labelOn
                  : SeekerSharedChipStyle.labelOff,
            ),
          ),
        ),
      ),
    );
  }
}

class SeekerSharedChoiceRow<T extends Object> extends StatelessWidget {
  const SeekerSharedChoiceRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> options;
  final T? selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = options.entries.toList();
    return Row(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(width: SeekerSharedChipStyle.chipGap),
          Expanded(
            child: SeekerSharedChoiceBrick(
              label: entries[i].value,
              selected: entries[i].key == selected,
              onTap: () => onChanged(entries[i].key),
            ),
          ),
        ],
      ],
    );
  }
}

class SeekerSharedChoiceGrid<T extends Object> extends StatelessWidget {
  const SeekerSharedChoiceGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.columns = 2,
  });

  final Map<T, String> options;
  final T? selected;
  final ValueChanged<T> onChanged;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final entries = options.entries.toList();
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i += columns) {
      final slice = entries.skip(i).take(columns).toList();
      rows.add(
        Row(
          children: [
            for (var j = 0; j < columns; j++) ...[
              if (j > 0) const SizedBox(width: SeekerSharedChipStyle.chipGap),
              Expanded(
                child: j < slice.length
                    ? SeekerSharedChoiceBrick(
                        label: slice[j].value,
                        selected: slice[j].key == selected,
                        onTap: () => onChanged(slice[j].key),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
      if (i + columns < entries.length) {
        rows.add(const SizedBox(height: SeekerSharedChipStyle.chipGap));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Field group: 14sp medium label + chips (not a top-level section header).
class SeekerSharedSection extends StatelessWidget {
  const SeekerSharedSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeekerSharedFieldLabel(title),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: SeekerSharedChipStyle.sectionSubtitleStyle),
        ],
        const SizedBox(height: SeekerSharedChipStyle.headerToContent),
        child,
      ],
    );
  }
}
