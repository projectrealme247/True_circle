import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/move_in_timing.dart';
import 'package:true_circle/models/seeker_onboarding_enums.dart';

void main() {
  final ref = DateTime(2026, 7, 15);

  group('SeekerMoveInWindow', () {
    test('parses new bucket tokens', () {
      expect(SeekerMoveInWindow.parse('this_month'), SeekerMoveInWindow.thisMonth);
      expect(SeekerMoveInWindow.parse('next_month'), SeekerMoveInWindow.nextMonth);
      expect(
        SeekerMoveInWindow.parse('within_3_months'),
        SeekerMoveInWindow.within3Months,
      );
      expect(SeekerMoveInWindow.parse('flexible'), SeekerMoveInWindow.flexible);
    });

    test('parses legacy bucket tokens', () {
      expect(SeekerMoveInWindow.parse('immediately'), SeekerMoveInWindow.thisMonth);
      expect(
        SeekerMoveInWindow.parse('within_1_3_months'),
        SeekerMoveInWindow.within3Months,
      );
    });

    test('fromSession prefers move_in_window over legacy ISO', () {
      final window = SeekerMoveInWindow.fromSession({
        'move_in_window': 'next_month',
        'earliest_move_in_date': '2026-12-01',
      });
      expect(window, SeekerMoveInWindow.nextMonth);
    });
  });

  group('MoveInTimingMigration', () {
    test('maps ISO date in current month to thisMonth', () {
      expect(
        MoveInTimingMigration.bucketFromDate(
          DateTime(2026, 7, 20),
          reference: ref,
        ),
        SeekerMoveInWindow.thisMonth,
      );
    });

    test('maps ISO date in next month to nextMonth', () {
      expect(
        MoveInTimingMigration.bucketFromDate(
          DateTime(2026, 8, 10),
          reference: ref,
        ),
        SeekerMoveInWindow.nextMonth,
      );
    });

    test('maps ISO date within 90 days to within3Months', () {
      expect(
        MoveInTimingMigration.bucketFromDate(
          DateTime(2026, 9, 30),
          reference: ref,
        ),
        SeekerMoveInWindow.within3Months,
      );
    });

    test('maps far-future ISO date to flexible', () {
      expect(
        MoveInTimingMigration.bucketFromDate(
          DateTime(2027, 1, 15),
          reference: ref,
        ),
        SeekerMoveInWindow.flexible,
      );
    });

    test('migrates legacy MoveInBucket session tokens', () {
      for (final bucket in MoveInBucket.values) {
        final migrated = MoveInTimingMigration.fromLegacySession({
          'move_in_window': bucket.storageToken,
        });
        expect(migrated, isNotNull);
      }
      expect(
        MoveInTimingMigration.fromLegacySession({
          'move_in_window': 'immediately',
        }),
        SeekerMoveInWindow.thisMonth,
      );
    });

    test('migrates earliest_move_in_date ISO when no window token', () {
      final migrated = MoveInTimingMigration.fromLegacySession({
        'earliest_move_in_date': '2026-08-05',
      });
      expect(migrated, SeekerMoveInWindow.nextMonth);
    });

    test('seekerPayload writes window token and version', () {
      expect(
        MoveInTimingMigration.seekerPayload(SeekerMoveInWindow.thisMonth),
        {
          'move_in_window': 'this_month',
          'move_in_timing_version': 2,
        },
      );
    });
  });

  group('MoveInTimingEngine', () {
    test('seeker thisMonth overlaps landlord exact date in same month', () {
      final eval = MoveInTimingEngine.evaluate(
        seekerSession: {'move_in_window': 'this_month'},
        listing: {
          'available_from': '2026-07-10',
          'availability_flexibility': 'plus_15_days',
        },
        reference: ref,
      );
      expect(eval.quality, TimingMatchQuality.strong);
      expect(eval.overlapDays, greaterThanOrEqualTo(14));
      expect(eval.earnsTimingScore, isTrue);
    });

    test('flexible seeker always earns flexible quality', () {
      final eval = MoveInTimingEngine.evaluate(
        seekerSession: {'move_in_window': 'flexible'},
        listing: {
          'available_from': '2028-01-01',
          'availability_flexibility': 'exact_date',
        },
        reference: ref,
      );
      expect(eval.quality, TimingMatchQuality.flexible);
      expect(eval.earnsTimingScore, isTrue);
    });

    test('large gap yields weak timing match', () {
      final eval = MoveInTimingEngine.evaluate(
        seekerSession: {'move_in_window': 'this_month'},
        listing: {
          'available_from': '2026-12-01',
          'availability_flexibility': 'exact_date',
        },
        reference: ref,
      );
      expect(eval.quality, TimingMatchQuality.weak);
      expect(eval.earnsTimingScore, isFalse);
    });

    test('landlord plus15Days extends window forward', () {
      final range = MoveInTimingEngine.landlordRange(
        DateTime(2026, 7, 1),
        LandlordAvailabilityFlexibility.plus15Days,
      );
      expect(range.end, DateTime(2026, 7, 16));
    });

    test('migrates legacy ISO seeker date for evaluation', () {
      final eval = MoveInTimingEngine.evaluate(
        seekerSession: {'earliest_move_in_date': '2026-08-01'},
        listing: {
          'available_from': '2026-08-05',
          'availability_flexibility': 'plus_15_days',
        },
        reference: ref,
      );
      expect(eval.seekerWindow, SeekerMoveInWindow.nextMonth);
      expect(eval.quality, isNot(TimingMatchQuality.none));
    });
  });

  group('TimingMatchQuality', () {
    test('earnsTimingScore excludes weak', () {
      expect(TimingMatchQuality.strong.earnsTimingScore, isTrue);
      expect(TimingMatchQuality.good.earnsTimingScore, isTrue);
      expect(TimingMatchQuality.flexible.earnsTimingScore, isTrue);
      expect(TimingMatchQuality.weak.earnsTimingScore, isFalse);
    });
  });
}
