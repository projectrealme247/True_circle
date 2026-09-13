import '../utils/profile_data.dart';
import '../utils/rental_date_format.dart';
import 'seeker_onboarding_enums.dart';

/// Seeker move-in intent — month windows, never exact dates.
enum SeekerMoveInWindow {
  thisMonth('this_month', 'This Month'),
  nextMonth('next_month', 'Next Month'),
  within3Months('within_3_months', 'Within 3 Months'),
  flexible('flexible', 'Flexible');

  const SeekerMoveInWindow(this.storageToken, this.label);

  final String storageToken;
  final String label;

  static SeekerMoveInWindow? parse(String? raw) {
    final token = raw?.trim() ?? '';
    if (token.isEmpty) return null;
    for (final value in SeekerMoveInWindow.values) {
      if (value.storageToken == token) return value;
    }
    return switch (token) {
      'immediately' => thisMonth,
      'within_1_3_months' => within3Months,
      _ => null,
    };
  }

  static SeekerMoveInWindow? fromSession(Map<String, dynamic>? session) {
    if (session == null) return null;
    final direct = parse(session['move_in_window']?.toString());
    if (direct != null) return direct;
    return MoveInTimingMigration.fromLegacySession(session);
  }
}

/// Landlord availability flexibility — extends forward from [available_from].
///
/// Independent Place create/edit uses [independentPlaceValues] only
/// (+15 Days / +1 Month / Flexible). [fixed] remains for Shared Living UI and
/// for matching existing listings until re-saved (IP migrate → [flexible]).
enum LandlordAvailabilityFlexibility {
  /// Shared Living + legacy IP — single-day window from Available From.
  fixed('fixed', 'Fixed'),
  plus15Days('plus_15_days', '+15 Days'),
  plus1Month('plus_1_month', '+1 Month'),
  flexible('flexible', 'Flexible');

  const LandlordAvailabilityFlexibility(this.storageToken, this.label);

  final String storageToken;
  final String label;

  /// Shared Spaces listing create/edit — Within 1 Month + Flexible only.
  static const sharedSpacesValues = <LandlordAvailabilityFlexibility>[
    plus1Month,
    flexible,
  ];

  /// Independent Place listing create/edit — no Fixed.
  static const independentPlaceValues = <LandlordAvailabilityFlexibility>[
    plus15Days,
    plus1Month,
    flexible,
  ];

  /// @Deprecated — use [independentPlaceValues].
  static const selectableValues = independentPlaceValues;

  static LandlordAvailabilityFlexibility parse(String? raw) {
    final token = raw?.trim().toLowerCase() ?? '';
    return switch (token) {
      'fixed' || 'exact_date' => fixed,
      'plus_15_days' => plus15Days,
      'plus_1_month' => plus1Month,
      'flexible' => flexible,
      // Unknown/missing keeps fixed for matching; IP form migrates → flexible.
      _ => fixed,
    };
  }

  /// IP listings: legacy `fixed` / `exact_date` → [flexible].
  static LandlordAvailabilityFlexibility migrateIndependentPlace(
    LandlordAvailabilityFlexibility value,
  ) {
    if (value == fixed) return flexible;
    return value;
  }

  static LandlordAvailabilityFlexibility fromListing(Map<String, dynamic> listing) {
    return parse(listing['availability_flexibility']?.toString());
  }
}

/// Overlap quality between seeker and landlord timing windows.
enum TimingMatchQuality {
  strong('Strong Timing Match'),
  good('Good Timing Match'),
  flexible('Flexible Timing Match'),
  weak('Weak Timing Match'),
  none('');

  const TimingMatchQuality(this.label);

  final String label;

  /// Earns the timing scoring bucket (weights unchanged).
  bool get earnsTimingScore =>
      this == strong || this == good || this == flexible;

  bool get showTimingWarning => this == weak;
}

/// Inclusive date range; [end] null means open-ended forward.
class MoveInDateRange {
  const MoveInDateRange({
    required this.start,
    this.end,
    this.isOpenEnded = false,
  });

  final DateTime start;
  final DateTime? end;
  final bool isOpenEnded;

  bool get isFlexibleOpen => isOpenEnded;

  int? overlapDaysWith(MoveInDateRange other) {
    final thisEnd = end ?? DateTime(9999, 12, 31);
    final otherEnd = other.end ?? DateTime(9999, 12, 31);
    final overlapStart = _maxDate(start, other.start);
    final overlapEnd = _minDate(thisEnd, otherEnd);
    if (overlapStart.isAfter(overlapEnd)) return 0;
    return overlapEnd.difference(overlapStart).inDays + 1;
  }

  /// Positive when [other] starts after this range ends.
  int gapDaysBefore(MoveInDateRange other) {
    final thisEnd = end ?? DateTime(9999, 12, 31);
    if (!other.start.isAfter(thisEnd)) return 0;
    return other.start.difference(thisEnd).inDays - 1;
  }

  static DateTime _maxDate(DateTime a, DateTime b) =>
      a.isAfter(b) ? a : b;

  static DateTime _minDate(DateTime a, DateTime b) =>
      a.isBefore(b) ? a : b;
}

/// Result of evaluating seeker ↔ listing timing alignment.
class TimingMatchEvaluation {
  const TimingMatchEvaluation({
    required this.quality,
    required this.seekerWindow,
    required this.landlordWindow,
    this.overlapDays = 0,
    this.gapDays = 0,
  });

  final TimingMatchQuality quality;
  final SeekerMoveInWindow? seekerWindow;
  final MoveInDateRange? landlordWindow;
  final int overlapDays;
  final int gapDays;

  bool get earnsTimingScore => quality.earnsTimingScore;
}

/// Migrates legacy exact-date profiles to window tokens.
abstract final class MoveInTimingMigration {
  static SeekerMoveInWindow? fromLegacySession(Map<String, dynamic> session) {
    final legacyBucket = MoveInBucket.fromSession(session);
    if (legacyBucket != null) {
      return switch (legacyBucket) {
        MoveInBucket.thisMonth => SeekerMoveInWindow.thisMonth,
        MoveInBucket.nextMonth => SeekerMoveInWindow.nextMonth,
        MoveInBucket.within3Months => SeekerMoveInWindow.within3Months,
        MoveInBucket.flexible => SeekerMoveInWindow.flexible,
      };
    }

    final iso = ProfileData.text(session['earliest_move_in_date']);
    final date = RentalDateFormat.parseIsoDate(iso);
    if (date == null) return null;
    return bucketFromDate(date, reference: DateTime.now());
  }

  static SeekerMoveInWindow bucketFromDate(
    DateTime date, {
    required DateTime reference,
  }) {
    final today = _dateOnly(reference);
    final target = _dateOnly(date);
    if (!_isAfterMonth(target, today) && !_isBeforeMonth(target, today)) {
      return SeekerMoveInWindow.thisMonth;
    }
    final nextMonthStart = DateTime(today.year, today.month + 1, 1);
    final nextMonthEnd = DateTime(today.year, today.month + 2, 0);
    if (!target.isBefore(nextMonthStart) && !target.isAfter(nextMonthEnd)) {
      return SeekerMoveInWindow.nextMonth;
    }
    final horizon = today.add(const Duration(days: 90));
    if (!target.isAfter(horizon)) {
      return SeekerMoveInWindow.within3Months;
    }
    return SeekerMoveInWindow.flexible;
  }

  static Map<String, dynamic> seekerPayload(SeekerMoveInWindow window) => {
        'move_in_window': window.storageToken,
        'move_in_timing_version': 2,
      };

  static bool _isBeforeMonth(DateTime a, DateTime b) =>
      a.year < b.year || (a.year == b.year && a.month < b.month);

  static bool _isAfterMonth(DateTime a, DateTime b) =>
      a.year > b.year || (a.year == b.year && a.month > b.month);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// Window resolution, overlap, and match-quality classification.
abstract final class MoveInTimingEngine {
  static TimingMatchEvaluation evaluate({
    required Map<String, dynamic>? seekerSession,
    required Map<String, dynamic> listing,
    DateTime? reference,
  }) {
    final ref = _dateOnly(reference ?? DateTime.now());
    final seekerWindow = SeekerMoveInWindow.fromSession(seekerSession);
    final landlordStart = RentalDateFormat.parseIsoDate(
      ProfileData.text(listing['available_from']),
    );
    final landlordFlex = LandlordAvailabilityFlexibility.fromListing(listing);

    if (seekerWindow == null && landlordStart == null) {
      return const TimingMatchEvaluation(
        quality: TimingMatchQuality.none,
        seekerWindow: null,
        landlordWindow: null,
      );
    }

    if (seekerWindow == SeekerMoveInWindow.flexible ||
        landlordFlex == LandlordAvailabilityFlexibility.flexible) {
      return TimingMatchEvaluation(
        quality: TimingMatchQuality.flexible,
        seekerWindow: seekerWindow,
        landlordWindow: landlordStart == null
            ? null
            : landlordRange(landlordStart, landlordFlex),
      );
    }

    if (seekerWindow == null || landlordStart == null) {
      return TimingMatchEvaluation(
        quality: TimingMatchQuality.flexible,
        seekerWindow: seekerWindow,
        landlordWindow: landlordStart == null
            ? null
            : landlordRange(landlordStart, landlordFlex),
      );
    }

    final seekerRange = seekerRangeFor(seekerWindow, reference: ref);
    final landlordRangeResolved = landlordRange(landlordStart, landlordFlex);
    final overlap = seekerRange.overlapDaysWith(landlordRangeResolved) ?? 0;
    final gap = seekerRange.gapDaysBefore(landlordRangeResolved);
    final reverseGap = landlordRangeResolved.gapDaysBefore(seekerRange);

    final quality = _classify(
      overlapDays: overlap,
      gapDays: gap > 0 ? gap : reverseGap,
      seekerWindow: seekerWindow,
      landlordFlex: landlordFlex,
    );

    return TimingMatchEvaluation(
      quality: quality,
      seekerWindow: seekerWindow,
      landlordWindow: landlordRangeResolved,
      overlapDays: overlap,
      gapDays: gap > 0 ? gap : reverseGap,
    );
  }

  static MoveInDateRange seekerRangeFor(
    SeekerMoveInWindow window, {
    required DateTime reference,
  }) {
    final today = _dateOnly(reference);
    return switch (window) {
      SeekerMoveInWindow.thisMonth => MoveInDateRange(
          start: DateTime(today.year, today.month, 1),
          end: DateTime(today.year, today.month + 1, 0),
        ),
      SeekerMoveInWindow.nextMonth => MoveInDateRange(
          start: DateTime(today.year, today.month + 1, 1),
          end: DateTime(today.year, today.month + 2, 0),
        ),
      SeekerMoveInWindow.within3Months => MoveInDateRange(
          start: today,
          end: today.add(const Duration(days: 90)),
        ),
      SeekerMoveInWindow.flexible => MoveInDateRange(
          start: today,
          isOpenEnded: true,
        ),
    };
  }

  static MoveInDateRange landlordRange(
    DateTime availableFrom,
    LandlordAvailabilityFlexibility flexibility,
  ) {
    final start = _dateOnly(availableFrom);
    return switch (flexibility) {
      LandlordAvailabilityFlexibility.fixed =>
        MoveInDateRange(start: start, end: start),
      LandlordAvailabilityFlexibility.plus15Days => MoveInDateRange(
          start: start,
          end: start.add(const Duration(days: 15)),
        ),
      LandlordAvailabilityFlexibility.plus1Month => MoveInDateRange(
          start: start,
          end: DateTime(start.year, start.month + 1, start.day),
        ),
      LandlordAvailabilityFlexibility.flexible => MoveInDateRange(
          start: start,
          isOpenEnded: true,
        ),
    };
  }

  static TimingMatchQuality _classify({
    required int overlapDays,
    required int gapDays,
    required SeekerMoveInWindow seekerWindow,
    required LandlordAvailabilityFlexibility landlordFlex,
  }) {
    if (overlapDays >= 14) return TimingMatchQuality.strong;
    if (overlapDays >= 7) return TimingMatchQuality.good;
    if (overlapDays > 0) return TimingMatchQuality.good;
    if (gapDays <= 14) return TimingMatchQuality.good;
    if (gapDays <= 30) return TimingMatchQuality.flexible;
    if (seekerWindow == SeekerMoveInWindow.flexible ||
        landlordFlex == LandlordAvailabilityFlexibility.flexible) {
      return TimingMatchQuality.flexible;
    }
    return TimingMatchQuality.weak;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String landlordWindowLabel(
    DateTime availableFrom,
    LandlordAvailabilityFlexibility flexibility,
  ) {
    final startLabel = RentalDateFormat.formatRentalAvailabilityDateTime(
      availableFrom,
    );
    return switch (flexibility) {
      LandlordAvailabilityFlexibility.fixed => startLabel,
      LandlordAvailabilityFlexibility.plus15Days =>
        '$startLabel → ${RentalDateFormat.formatRentalAvailabilityDateTime(availableFrom.add(const Duration(days: 15)))}',
      LandlordAvailabilityFlexibility.plus1Month =>
        '$startLabel → ${RentalDateFormat.formatRentalAvailabilityDateTime(DateTime(availableFrom.year, availableFrom.month + 1, availableFrom.day))}',
      LandlordAvailabilityFlexibility.flexible => 'From $startLabel onward',
    };
  }
}
