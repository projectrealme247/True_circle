import 'package:intl/intl.dart';

import '../models/move_in_timing.dart';
import '../models/seeker_onboarding_enums.dart';

/// Human-friendly rental availability dates for cards, chips, and summaries.
///
/// Storage stays ISO (`yyyy-MM-dd`); use these helpers only at display time.
abstract final class RentalDateFormat {
  static final DateFormat _dayMonth = DateFormat('d MMM');

  /// Parses `yyyy-MM-dd` (and other [DateTime.tryParse] shapes) as a local date.
  static DateTime? parseIsoDate(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(trimmed);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }

    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// `4 Aug` — empty when input is missing or unparseable.
  static String formatRentalAvailabilityDate(String? raw) {
    return formatRentalAvailabilityDateTime(parseIsoDate(raw));
  }

  /// `4 Aug` — empty when [date] is null.
  static String formatRentalAvailabilityDateTime(DateTime? date) {
    if (date == null) return '';
    return _dayMonth.format(date);
  }

  /// Seeker window chip label — empty when unset.
  static String formatSeekerMoveInWindow(SeekerMoveInWindow? window) {
    return window?.label ?? '';
  }

  /// Move-in filter / chip label — bucket tokens stay readable, ISO becomes `4 Aug`.
  static String formatMoveInWindowDisplay(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return '';

    final bucket = MoveInBucket.fromSession({'move_in_window': trimmed});
    if (bucket != null) return bucket.label;

    final formatted = formatRentalAvailabilityDate(trimmed);
    if (formatted.isNotEmpty) return formatted;

    return trimmed;
  }
}
