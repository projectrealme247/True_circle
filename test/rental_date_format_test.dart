import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/rental_date_format.dart';

void main() {
  group('RentalDateFormat', () {
    test('formats ISO date as day + abbreviated month without year', () {
      expect(
        RentalDateFormat.formatRentalAvailabilityDate('2026-08-04'),
        '4 Aug',
      );
      expect(
        RentalDateFormat.formatRentalAvailabilityDate('2026-09-07'),
        '7 Sep',
      );
      expect(
        RentalDateFormat.formatRentalAvailabilityDate('2026-10-10'),
        '10 Oct',
      );
      expect(
        RentalDateFormat.formatRentalAvailabilityDate('2026-11-13'),
        '13 Nov',
      );
    });

    test('returns empty for missing or invalid input', () {
      expect(RentalDateFormat.formatRentalAvailabilityDate(null), '');
      expect(RentalDateFormat.formatRentalAvailabilityDate(''), '');
      expect(RentalDateFormat.formatRentalAvailabilityDate('not-a-date'), '');
    });

    test('formatMoveInWindowDisplay preserves bucket labels', () {
      expect(
        RentalDateFormat.formatMoveInWindowDisplay('this_month'),
        'This Month',
      );
      expect(
        RentalDateFormat.formatMoveInWindowDisplay('immediately'),
        'This Month',
      );
      expect(
        RentalDateFormat.formatMoveInWindowDisplay('next_month'),
        'Next Month',
      );
      expect(
        RentalDateFormat.formatMoveInWindowDisplay('within_3_months'),
        'Within 3 Months',
      );
      expect(
        RentalDateFormat.formatMoveInWindowDisplay('within_1_3_months'),
        'Within 3 Months',
      );
      expect(
        RentalDateFormat.formatMoveInWindowDisplay('flexible'),
        'Flexible',
      );
    });

    test('formatMoveInWindowDisplay formats ISO move-in dates', () {
      expect(
        RentalDateFormat.formatMoveInWindowDisplay('2026-08-04'),
        '4 Aug',
      );
    });

    test('parseIsoDate treats yyyy-MM-dd as local calendar date', () {
      final parsed = RentalDateFormat.parseIsoDate('2026-08-04');
      expect(parsed, isNotNull);
      expect(parsed!.year, 2026);
      expect(parsed.month, 8);
      expect(parsed.day, 4);
    });
  });
}
