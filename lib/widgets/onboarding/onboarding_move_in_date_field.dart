import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../listing_creation/listing_creation_primitives.dart';
import 'onboarding_design_tokens.dart';

/// Inline calendar field for seeker earliest move-in date.
class OnboardingMoveInDateField extends StatelessWidget {
  const OnboardingMoveInDateField({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.placeholder = 'Select a date',
  });

  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final String placeholder;

  static DateTime get todayDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate(BuildContext context) async {
    final today = todayDate;
    final initial = selectedDate == null || selectedDate!.isBefore(today)
        ? today
        : selectedDate!;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
      helpText: 'Earliest move-in',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.accent,
                  onPrimary: Colors.white,
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      onDateChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = selectedDate != null;
    final displayText = hasDate
        ? DateFormat('d MMM yyyy').format(selectedDate!)
        : placeholder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pickDate(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: listingFieldHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: OnboardingTokens.inputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OnboardingTokens.inputBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayText,
                  style: hasDate
                      ? listingFieldValueStyle
                      : listingFieldValueStyle.copyWith(
                          color: OnboardingTokens.subtitleColor,
                        ),
                ),
              ),
              const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: Color(0xFF6B7280),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
