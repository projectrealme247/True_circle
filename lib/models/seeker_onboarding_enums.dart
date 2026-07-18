/// Core seeker persona captured on onboarding screen 1.
enum SeekerPersona {
  student('student', 'Students', '🎓 Student'),
  professional('professional', 'Working Professionals', '💼 Working Professional (Single / Couple)'),
  relocating('relocating', 'Working Professionals', '💼 Working Professional (Single / Couple)'),
  family('family', 'Family', '👨‍👩‍👧‍👦 Family');

  const SeekerPersona(this.storageToken, this.occupantType, this.chipLabel);

  final String storageToken;
  final String occupantType;
  final String chipLabel;

  bool get requiresGuarantorQuestion => this == SeekerPersona.student;

  static SeekerPersona? fromSession(Map<String, dynamic>? session) {
    if (session == null) return null;
    final raw = session['seeker_persona']?.toString() ?? '';
    final fromToken = switch (raw) {
      'student' => student,
      'professional' => professional,
      'relocating' => relocating,
      'family' => family,
      _ => null,
    };
    if (fromToken != null) return fromToken;

    final occupant = session['occupant_type']?.toString() ?? '';
    return switch (occupant.toLowerCase()) {
      'student' || 'students' => student,
      'professional' || 'relocating' => professional,
      'family' => family,
      'working professionals' => () {
        if (session['pre_arrival_seeker'] == true ||
            session['seeker_relocating'] == true) {
          return relocating;
        }
        return professional;
      }(),
      _ => null,
    };
  }
}

/// Dublin presence context collected on seeker onboarding screen 2.
enum DublinLocationContext {
  alreadyInDublin('already_in_dublin'),
  arrivingSoon('arriving_soon'),
  relocating('relocating');

  const DublinLocationContext(this.storageToken);
  final String storageToken;

  static DublinLocationContext? fromSession(Map<String, dynamic>? session) {
    if (session == null) return null;
    final raw = session['dublin_location_context']?.toString() ?? '';
    if (raw == relocating.storageToken) return relocating;
    if (raw == arrivingSoon.storageToken) return arrivingSoon;
    if (raw == alreadyInDublin.storageToken) return alreadyInDublin;
    // Legacy: pre-arrival flag without an explicit relocating token.
    if (session['pre_arrival_seeker'] == true) return arrivingSoon;
    final city = session['detected_city']?.toString().toLowerCase() ?? '';
    if (city.contains('dublin')) return alreadyInDublin;
    return null;
  }
}

/// Irish guarantor pivot on seeker onboarding screen 3.
enum GuarantorStatus {
  yes('yes'),
  no('no'),
  notSureYet('not_sure_yet');

  const GuarantorStatus(this.storageToken);
  final String storageToken;

  static GuarantorStatus? fromSession(Map<String, dynamic>? session) {
    if (session == null) return null;
    final raw = session['guarantor_status']?.toString() ?? '';
    return switch (raw) {
      'yes' => yes,
      'no' => no,
      'not_sure_yet' => notSureYet,
      _ => session['has_guarantor'] == true ? yes : null,
    };
  }
}

/// Family Destination IA — what primarily drives weekday location.
///
/// UI structure only; no recommendation logic yet.
enum FamilyLocationDriver {
  workplace,
  schoolArea,
  both,
  customLocation,
}

/// Discrete commute-time options for seeker destination screen.
abstract final class SeekerCommuteTimeOptions {
  static const values = [30, 60, 90, 120];

  /// Default for fresh onboarding sessions (slider index 1).
  static const defaultMinutes = 60;

  static int snap(num raw) {
    var nearest = defaultMinutes;
    var delta = (raw - nearest).abs();
    for (final option in values) {
      final d = (raw - option).abs();
      if (d < delta || (d == delta && option == defaultMinutes)) {
        nearest = option;
        delta = d;
      }
    }
    return nearest;
  }

  static int indexOf(int minutes) {
    final idx = values.indexOf(minutes);
    return idx >= 0 ? idx : values.indexOf(snap(minutes));
  }
}

/// Move-in timing buckets for seekers (month windows — never exact dates).
enum MoveInBucket {
  thisMonth('this_month', 'This Month'),
  nextMonth('next_month', 'Next Month'),
  within3Months('within_3_months', 'Within 3 Months'),
  flexible('flexible', 'Flexible');

  const MoveInBucket(this.storageToken, this.label);
  final String storageToken;
  final String label;

  static MoveInBucket? fromSession(Map<String, dynamic>? session) {
    if (session == null) return null;
    final raw = session['move_in_window']?.toString() ?? '';
    return switch (raw) {
      'this_month' || 'immediately' => thisMonth,
      'next_month' => nextMonth,
      'within_3_months' || 'within_1_3_months' => within3Months,
      'flexible' => flexible,
      _ => null,
    };
  }
}
