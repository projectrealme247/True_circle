import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Calm selection styling — no coral fills on choice controls.
const Color listingChoiceBorderSelected = Color(0xFF6B7280);
const Color listingChoiceBorderUnselected = Color(0xFFE5E7EB);
const Color listingChoiceCheckColor = Color(0xFF6B7280);

/// Subtle 3D lift for selected choice tiles.
const List<BoxShadow> listingChoiceSelectedShadow = [
  BoxShadow(
    color: Color(0x14111827),
    blurRadius: 10,
    offset: Offset(0, 3),
  ),
  BoxShadow(
    color: Color(0x0A111827),
    blurRadius: 2,
    offset: Offset(0, 1),
  ),
];

/// Shared box decoration for premium selected/unselected choice surfaces.
BoxDecoration listingChoiceBoxDecoration({
  required bool selected,
  Color backgroundColor = Colors.white,
  double borderRadius = 10,
}) {
  return BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: selected ? listingChoiceBorderSelected : listingChoiceBorderUnselected,
      width: selected ? 1.25 : 1.0,
    ),
    boxShadow: selected ? listingChoiceSelectedShadow : null,
  );
}

/// Uniform Daft-style border for listing form surfaces.
Color get listingDaftBorderColor => Colors.grey.shade300;
const double listingDaftBorderWidth = 1.0;

Border listingDaftBorder({bool selected = false}) => Border.all(
      color: selected ? listingChoiceBorderSelected : listingDaftBorderColor,
      width: listingDaftBorderWidth,
    );
const double listingFieldHeight = 44;

/// Spacing tokens — 8px grid (compact).
const double listingSectionSpacing = 28;
const double listingFieldSpacing = 16;
const double listingLabelSpacing = 8;
const double listingCardPadding = 12;

/// Typography hierarchy — page → section → label → sub-label → value.
const TextStyle listingPageTitleStyle = TextStyle(
  fontSize: 26,
  fontWeight: FontWeight.w600,
  color: Color(0xFF111827),
  letterSpacing: -0.4,
  height: 1.15,
);

const TextStyle listingSectionTitleStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: Color(0xFF1F2937),
  letterSpacing: -0.2,
  height: 1.25,
);

const TextStyle listingPageSubtitleStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: Color(0xFF6B7280),
  height: 1.45,
);

/// Field labels (e.g. Tenant composition, BER rating).
const TextStyle listingFieldLabelStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w500,
  color: Color(0xFF4B5563),
  height: 1.35,
);

/// Informational / helper copy beneath labels.
const TextStyle listingSubLabelStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w400,
  color: Color(0xFF9CA3AF),
  height: 1.45,
);

const TextStyle listingFieldValueStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w500,
  color: Color(0xFF111827),
);

/// Monochromatic icon tint for form choice tiles (matches utility icons).
const Color listingChoiceIconColor = Color(0xFF6B7280);
const double listingChoiceIconSize = 17;

/// Option callout above paired location inputs (Eircode vs GPS).
const TextStyle listingOptionLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: Color(0xFF374151),
  letterSpacing: 0.2,
);

const TextStyle listingOptionHintStyle = listingSubLabelStyle;

class ListingSectionHeader extends StatelessWidget {
  const ListingSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: listingLabelSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: listingSectionTitleStyle),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: listingSubLabelStyle),
          ],
        ],
      ),
    );
  }
}

/// Collapsed-by-default panel for optional listing enhancements.
class ListingCollapsibleSection extends StatelessWidget {
  const ListingCollapsibleSection({
    super.key,
    required this.title,
    required this.expanded,
    required this.onExpandedChanged,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: expanded ? listingChoiceBorderSelected : listingChoiceBorderUnselected,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onExpandedChanged(!expanded),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(listingCardPadding),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: listingSectionTitleStyle),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(subtitle!, style: listingSubLabelStyle),
                          ],
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: expanded
                            ? const Color(0xFF374151)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                listingCardPadding,
                0,
                listingCardPadding,
                listingCardPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: listingFieldSpacing),
                    children[i],
                  ],
                ],
              ),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOutCubic,
          ),
        ],
      ),
    );
  }
}

/// Flat white grid with radio dot — horizontal or vertical Daft-style bricks.
class ListingDaftRadioChoiceList<T extends Object> extends StatelessWidget {
  const ListingDaftRadioChoiceList({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.horizontal = true,
    this.emojis = const {},
    this.icons = const {},
  });

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final bool horizontal;
  final Map<T, String> emojis;
  final Map<T, IconData> icons;

  @override
  Widget build(BuildContext context) {
    final entries = options.entries.toList();
    if (horizontal && entries.length <= 4) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _DaftRadioBrick(
                label: entries[i].value,
                emoji: emojis[entries[i].key],
                icon: icons[entries[i].key],
                selected: entries[i].key == selected,
                enabled: enabled,
                compact: true,
                onTap: () => onChanged(entries[i].key),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _DaftRadioBrick(
            label: entries[i].value,
            emoji: emojis[entries[i].key],
            icon: icons[entries[i].key],
            selected: entries[i].key == selected,
            enabled: enabled,
            onTap: () => onChanged(entries[i].key),
          ),
        ],
      ],
    );
  }
}

class _DaftRadioBrick extends StatelessWidget {
  const _DaftRadioBrick({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.emoji,
    this.icon,
    this.compact = false,
  });

  final String label;
  final String? emoji;
  final IconData? icon;
  final bool selected;
  final bool enabled;
  final bool compact;
  final VoidCallback onTap;

  static const _bg = Colors.white;
  static const _labelColor = Color(0xFF374151);
  static const _labelDisabled = Color(0xFF9CA3AF);

  Widget? _leading() {
    if (icon != null) {
      return Icon(
        icon,
        size: listingChoiceIconSize,
        color: enabled ? listingChoiceIconColor : _labelDisabled,
      );
    }
    if (emoji != null && emoji!.isNotEmpty) {
      return Text(emoji!, style: const TextStyle(fontSize: 17, height: 1));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = enabled ? _labelColor : _labelDisabled;
    final leading = _leading();

    final labelWidget = Expanded(
      child: Text(
        label,
        style: listingFieldValueStyle.copyWith(
          fontSize: compact ? 14 : 16,
          fontWeight: FontWeight.w500,
          color: labelColor,
          height: compact ? 1.25 : 1.3,
        ),
      ),
    );

    final content = compact
        ? Row(
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: 8),
              ],
              labelWidget,
              if (selected)
                Icon(
                  Icons.check_rounded,
                  size: compact ? 16 : 18,
                  color: enabled ? listingChoiceCheckColor : _labelDisabled,
                ),
            ],
          )
        : Row(
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: 10),
              ],
              labelWidget,
              if (selected)
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: enabled ? listingChoiceCheckColor : _labelDisabled,
                ),
            ],
          );

    return Material(
      color: _bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 10 : 12,
          ),
          decoration: listingChoiceBoxDecoration(selected: selected),
          child: content,
        ),
      ),
    );
  }
}

class _DaftRadioDot extends StatelessWidget {
  const _DaftRadioDot({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: enabled
              ? (selected ? AppColors.accent : listingDaftBorderColor)
              : const Color(0xFFE5E7EB),
          width: selected ? 2 : 1,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
              ),
            )
          : null,
    );
  }
}

/// Horizontal segmented control — premium pill track (Airbnb-style).
class ListingSegmentedControl<T extends Object> extends StatelessWidget {
  const ListingSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.height = 44,
  });

  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final double height;

  static const _trackFill = Color(0xFFF3F4F6);
  static const _mutedText = Color(0xFF6B7280);
  static const _selectedText = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    final entries = segments.entries.toList();
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _trackFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _PremiumSegment(
                label: entries[i].value,
                selected: entries[i].key == selected,
                enabled: enabled,
                onTap: () => onChanged(entries[i].key),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PremiumSegment extends StatelessWidget {
  const _PremiumSegment({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(color: listingChoiceBorderSelected, width: 1.25)
                : Border.all(color: Colors.transparent, width: 1.25),
            boxShadow: selected
                ? listingChoiceSelectedShadow
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: listingFieldValueStyle.copyWith(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              height: 1.2,
              color: enabled
                  ? (selected
                      ? ListingSegmentedControl._selectedText
                      : ListingSegmentedControl._mutedText)
                  : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrapping chip selector — compact cohort / multi-option pickers.
class ListingWrapSegmentedControl<T extends Object> extends StatelessWidget {
  const ListingWrapSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in segments.entries)
          _WrapSegmentChip(
            label: entry.value,
            selected: entry.key == selected,
            enabled: enabled,
            onTap: () => onChanged(entry.key),
          ),
      ],
    );
  }
}

class _WrapSegmentChip extends StatelessWidget {
  const _WrapSegmentChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? listingChoiceBorderSelected
                  : listingChoiceBorderUnselected,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: listingFieldValueStyle.copyWith(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: enabled
                      ? (selected
                          ? const Color(0xFF111827)
                          : const Color(0xFF4B5563))
                      : const Color(0xFF9CA3AF),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: enabled
                      ? listingChoiceCheckColor
                      : const Color(0xFF9CA3AF),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Outlined choice tile — grey border unselected, charcoal border selected.
class ListingOutlineChoiceTile extends StatelessWidget {
  const ListingOutlineChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.height = 44,
    this.textAlign = TextAlign.center,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;
  final double height;
  final TextAlign textAlign;
  final EdgeInsets padding;

  static const _textColor = Color(0xFF374151);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          height: height,
          alignment: Alignment.center,
          padding: padding,
          decoration: listingChoiceBoxDecoration(selected: selected),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: textAlign,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: listingFieldValueStyle.copyWith(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    height: 1.2,
                    color: enabled ? _textColor : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: enabled
                      ? listingChoiceCheckColor
                      : const Color(0xFF9CA3AF),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid of outlined choice tiles for multi-option single-select (e.g. room type).
class ListingOutlineChoiceGrid<T extends Object> extends StatelessWidget {
  const ListingOutlineChoiceGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.columns = 1,
  });

  final Map<T, String> options;
  final T? selected;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final entries = options.entries.toList();

    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            ListingOutlineChoiceTile(
              label: entries[i].value,
              selected: entries[i].key == selected,
              enabled: enabled,
              height: 44,
              textAlign: TextAlign.left,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onTap: () => onChanged(entries[i].key),
            ),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in entries)
              SizedBox(
                width: tileWidth,
                child: ListingOutlineChoiceTile(
                  label: entry.value,
                  selected: entry.key == selected,
                  enabled: enabled,
                  height: 52,
                  onTap: () => onChanged(entry.key),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Label above field — avoids cramped inline floating labels in rows.
class ListingLabeledField extends StatelessWidget {
  const ListingLabeledField({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: listingFieldLabelStyle),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Bounded inline stepper for bedroom / bathroom counts.
class ListingCompactCounter extends StatelessWidget {
  const ListingCompactCounter({
    super.key,
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    this.min = 0,
    this.max = 12,
    this.compact = false,
  });

  final String label;
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final int min;
  final int max;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final stepper = _InlineStepper(
      value: value,
      min: min,
      max: max,
      onDecrement: onDecrement,
      onIncrement: onIncrement,
    );

    if (compact) {
      return Row(
        children: [
          Expanded(
            child: Text(label, style: listingFieldLabelStyle),
          ),
          stepper,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: listingFieldLabelStyle,
        ),
        const SizedBox(height: 6),
        stepper,
      ],
    );
  }
}

class _InlineStepper extends StatelessWidget {
  const _InlineStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int value;
  final int min;
  final int max;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: listingChoiceBorderUnselected),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CounterIconButton(
            icon: Icons.remove_rounded,
            enabled: value > min,
            onTap: onDecrement,
            size: 32,
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: listingFieldValueStyle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _CounterIconButton(
            icon: Icons.add_rounded,
            enabled: value < max,
            onTap: onIncrement,
            size: 32,
          ),
        ],
      ),
    );
  }
}

class _CounterIconButton extends StatelessWidget {
  const _CounterIconButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.size = 36,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: 16,
            color: enabled
                ? const Color(0xFF374151)
                : const Color(0xFFD1D5DB),
          ),
        ),
      ),
    );
  }
}

/// Tappable date field using the same visual pattern as other inputs.
class ListingDateInputField extends StatelessWidget {
  const ListingDateInputField({
    super.key,
    this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
    this.placeholder = 'Select date',
    this.externalLabel = false,
  });

  final String? label;
  final DateTime? value;
  final VoidCallback? onTap;
  final bool enabled;
  final String placeholder;
  /// When true, label is rendered by [ListingLabeledField] above this widget.
  final bool externalLabel;

  static String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final displayText = _formatDate(value);

    return SizedBox(
      height: listingFieldHeight,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          decoration: (externalLabel
                  ? listingInlineInputDecoration(
                      hint: hasValue ? null : placeholder,
                    )
                  : listingInputDecoration(
                      label: label ?? 'Date',
                      hint: placeholder,
                    ))
              .copyWith(
            suffixIcon: Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: enabled
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFFD1D5DB),
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
          isEmpty: !hasValue,
          child: hasValue
              ? Text(
                  displayText,
                  style: listingFieldValueStyle.copyWith(
                    color: const Color(0xFF111827),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// BER rating picker — Daft-style sharp-edged selector with a fixed
/// downward-expanding overlay menu (never flips upward like a native dropdown).
class ListingBerRatingField extends StatefulWidget {
  const ListingBerRatingField({
    super.key,
    required this.value,
    required this.ratings,
    required this.onChanged,
    this.enabled = true,
  });

  final String? value;
  final List<String> ratings;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  State<ListingBerRatingField> createState() => _ListingBerRatingFieldState();
}

class _ListingBerRatingFieldState extends State<ListingBerRatingField> {
  final _layerLink = LayerLink();
  final _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _open = false;

  static const _itemStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Color(0xFF111827),
  );

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  void didUpdateWidget(ListingBerRatingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _open) _closeMenu();
  }

  void _toggleMenu() {
    if (!widget.enabled) return;
    if (_open) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    _removeOverlay();
    final renderBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? 260.0;
    final height = renderBox?.size.height ?? listingFieldHeight;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeMenu,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, height + 6),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black87, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: widget.ratings.length + 1,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.grey.shade200,
                        ),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final isEmpty =
                                widget.value == null || widget.value!.isEmpty;
                            return _menuRow(
                              label: 'Select option',
                              selected: isEmpty,
                              muted: true,
                              onTap: _closeMenu,
                            );
                          }
                          final rating = widget.ratings[index - 1];
                          return _menuRow(
                            label: rating,
                            selected: rating == widget.value,
                            onTap: () {
                              widget.onChanged(rating);
                              _closeMenu();
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _open = true);
  }

  void _closeMenu() {
    _removeOverlay();
    if (mounted) setState(() => _open = false);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _menuRow({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool muted = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: selected ? const Color(0xFFF3F4F6) : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: _itemStyle.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: muted
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF111827),
                ),
              ),
            ),
            if (selected && !muted)
              const Icon(Icons.check, size: 18, color: Colors.black87),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null && widget.value!.isNotEmpty;

    return ListingLabeledField(
      label: 'BER rating',
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.enabled ? _toggleMenu : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              key: _fieldKey,
              height: listingFieldHeight,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.enabled
                      ? Colors.black87
                      : const Color(0xFFD1D5DB),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasValue ? widget.value! : 'Select option',
                      style: _itemStyle.copyWith(
                        color: hasValue
                            ? const Color(0xFF111827)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: 22,
                    color: widget.enabled
                        ? Colors.black87
                        : const Color(0xFFD1D5DB),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ListingToggleAspectCard extends StatelessWidget {
  const ListingToggleAspectCard({
    super.key,
    required this.offLabel,
    required this.onLabel,
    required this.active,
    required this.onChanged,
  });

  final String offLabel;
  final String onLabel;
  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListingOutlineChoiceTile(
      label: active ? onLabel : offLabel,
      selected: active,
      height: 48,
      onTap: () => onChanged(!active),
    );
  }
}

/// Read-only pill for inherited house rules on listing step 3.
class ListingRuleChip extends StatelessWidget {
  const ListingRuleChip({
    super.key,
    required this.label,
    this.icon,
    this.emoji,
    this.active = true,
    this.expand = false,
  });

  final String label;
  final IconData? icon;
  final String? emoji;
  final bool active;
  final bool expand;

  static const _textColor = Color(0xFF374151);

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: listingChoiceBoxDecoration(selected: active),
      child: Row(
        mainAxisAlignment:
            expand ? MainAxisAlignment.center : MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: listingChoiceIconColor),
            const SizedBox(width: 6),
          ] else if (emoji != null && emoji!.isNotEmpty) ...[
            Text(emoji!, style: const TextStyle(fontSize: 14, height: 1)),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: expand ? TextAlign.center : TextAlign.start,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _textColor,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
    return chip;
  }
}

/// Compact horizontal rule toggle — low profile, grey inactive / coral active.
class ListingCompactRuleTile extends StatelessWidget {
  const ListingCompactRuleTile({
    super.key,
    required this.offLabel,
    required this.onLabel,
    required this.active,
    required this.onChanged,
    this.enabled = true,
  });

  final String offLabel;
  final String onLabel;
  final bool active;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListingOutlineChoiceTile(
      label: active ? onLabel : offLabel,
      selected: active,
      enabled: enabled,
      height: 40,
      textAlign: TextAlign.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      onTap: () => onChanged(!active),
    );
  }
}

/// Premium monthly rent field — static € prefix, large numeric typography.
class ListingPremiumRentField extends StatelessWidget {
  const ListingPremiumRentField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.validator,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? Function(String?)? validator;

  static const _surfaceBg = Color(0xFFF9FAFB);
  static const _borderColor = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Monthly rent', style: listingFieldLabelStyle),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: _surfaceBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    '€',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                      height: 1,
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(vertical: 12),
                color: _borderColor,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextFormField(
                    controller: controller,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    textAlignVertical: TextAlignVertical.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                      letterSpacing: -0.3,
                      height: 1.0,
                    ),
                    decoration: const InputDecoration(
                      hintText: '1,850',
                      hintStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF9CA3AF),
                        height: 1.0,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      errorStyle: TextStyle(height: 0, fontSize: 0),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      isCollapsed: false,
                    ),
                    validator: validator,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

InputDecoration listingInputDecoration({
  required String label,
  String? hint,
  String? prefixText,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: listingFieldLabelStyle,
    floatingLabelStyle: listingFieldLabelStyle,
    hintText: hint,
    hintStyle: listingFieldLabelStyle.copyWith(color: const Color(0xFF9CA3AF)),
    prefixText: prefixText,
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: listingDaftBorderColor,
        width: listingDaftBorderWidth,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: AppColors.accent,
        width: listingDaftBorderWidth,
      ),
    ),
  );
}

/// Inline input without a floating label (label rendered externally).
InputDecoration listingInlineInputDecoration({String? hint, Widget? prefixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: listingFieldLabelStyle.copyWith(color: const Color(0xFF9CA3AF)),
    prefixIcon: prefixIcon,
    prefixIconConstraints: prefixIcon != null
        ? const BoxConstraints(minWidth: 40, minHeight: 20)
        : null,
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: listingDaftBorderColor,
        width: listingDaftBorderWidth,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: AppColors.accent,
        width: listingDaftBorderWidth,
      ),
    ),
  );
}

/// Fixed-height row fields — label is supplied via [ListingLabeledField].
InputDecoration listingCompactInputDecoration({
  required String label,
  String? hint,
}) {
  return listingInlineInputDecoration(hint: hint ?? label);
}
