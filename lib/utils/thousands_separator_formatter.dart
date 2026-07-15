import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats integer currency inputs with thousands separators as the user types.
class ThousandsSeparatorFormatter extends TextInputFormatter {
  ThousandsSeparatorFormatter({String locale = 'en_US'})
      : _formatter = NumberFormat('#,##0', locale);

  final NumberFormat _formatter;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final numText = newValue.text.replaceAll(',', '');
    final intValue = int.tryParse(numText);
    if (intValue == null) return oldValue;

    final newString = _formatter.format(intValue);
    final selectionIndex = newValue.selection.end +
        (newString.length - newValue.text.length);

    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(
        offset: selectionIndex.clamp(0, newString.length),
      ),
    );
  }
}

/// Formats a raw digit string for display in thousand-separated inputs.
String formatThousandsForInput(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return '';
  final value = int.tryParse(digits);
  if (value == null) return raw;
  return NumberFormat('#,##0', 'en_US').format(value);
}

/// Strips display formatting and returns digits only.
String stripThousandsFormatting(String formatted) =>
    formatted.replaceAll(',', '').trim();
