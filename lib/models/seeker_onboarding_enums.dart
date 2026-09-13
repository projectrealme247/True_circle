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

/// Guarantor pivot on seeker onboarding screen 3.
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

/// Shared stay-duration values for seekers (tenure_preference) and
/// Independent Place listings (agreement_type). Single source of truth.
///
/// Independent Place (seeker + listing) only offers [temporary] and [longTerm].
/// [flexible] is legacy: still parsed for Shared Living listings; IP seekers
/// migrate `flexible` → [longTerm] via [fromSession] / [migrateIndependentPlace].
enum TenurePreference {
  temporary('temporary', 'Temporary'),
  longTerm('long_term', 'Long-Term'),
  /// Legacy — Shared Living listing UI only. Not offered for Independent Place.
  flexible('flexible', 'Flexible');

  const TenurePreference(this.storageToken, this.label);
  final String storageToken;
  final String label;

  static const sessionKey = 'tenure_preference';
  static const listingKey = 'agreement_type';

  /// Independent Place seeker + listing — Temporary / Long-Term only.
  static const independentPlaceValues = <TenurePreference>[
    temporary,
    longTerm,
  ];

  /// Alias for listing create/edit (same IP set).
  static const independentPlaceListingValues = independentPlaceValues;

  static TenurePreference? fromStorage(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'temporary' => temporary,
      'long_term' || 'long term' => longTerm,
      'flexible' => flexible,
      _ => null,
    };
  }

  /// Independent Place migration: legacy `flexible` → [longTerm].
  static TenurePreference? migrateIndependentPlace(TenurePreference? value) {
    if (value == flexible) return longTerm;
    return value;
  }

  /// Session hydrate for IP seekers — migrates legacy flexible → long_term.
  static TenurePreference? fromSession(Map<String, dynamic>? session) {
    if (session == null) return null;
    return migrateIndependentPlace(fromStorage(session[sessionKey]?.toString()));
  }

  /// Rewrites [sessionKey] in-place when legacy flexible is present (IP profiles).
  static void migrateIndependentPlaceSession(Map<String, dynamic> session) {
    final raw = session[sessionKey]?.toString();
    if (fromStorage(raw) == flexible) {
      session[sessionKey] = longTerm.storageToken;
    }
  }

  static TenurePreference? fromListing(Map<String, dynamic>? listing) {
    if (listing == null) return null;
    return fromStorage(listing[listingKey]?.toString());
  }
}

/// Independent Place only — furnishing preference (soft signal).
enum FurnishingPreference {
  furnished('furnished', 'Furnished'),
  partFurnished('part_furnished', 'Part Furnished'),
  noPreference('no_preference', 'No Preference');

  const FurnishingPreference(this.storageToken, this.label);
  final String storageToken;
  final String label;

  static const sessionKey = 'furnishing_preference';

  static FurnishingPreference? fromSession(Map<String, dynamic>? session) {
    if (session == null) return null;
    final raw = session[sessionKey]?.toString() ?? '';
    return switch (raw) {
      'furnished' => furnished,
      'part_furnished' => partFurnished,
      'no_preference' => noPreference,
      _ => null,
    };
  }
}

/// Independent Place only — house vs apartment preference (soft signal).
enum PropertyTypePreference {
  house('house', 'House'),
  apartment('apartment', 'Apartment'),
  noPreference('no_preference', 'No Preference');

  const PropertyTypePreference(this.storageToken, this.label);
  final String storageToken;
  final String label;

  static const sessionKey = 'property_type_preference';

  static PropertyTypePreference? fromSession(Map<String, dynamic>? session) {
    if (session == null) return null;
    final raw = session[sessionKey]?.toString() ?? '';
    return switch (raw) {
      'house' => house,
      'apartment' => apartment,
      'no_preference' => noPreference,
      _ => null,
    };
  }
}

/// Seeker soft preference — bathroom arrangement (IP + Shared Living).
enum BathroomPreference {
  privateBathroom('private_bathroom', 'Private Bathroom (Ensuite)'),
  sharedBathroom('shared_bathroom', 'Shared Bathroom'),
  noPreference('no_preference', 'No Preference');

  const BathroomPreference(this.storageToken, this.label);
  final String storageToken;
  final String label;

  static const sessionKey = 'bathroom_preference';

  /// Chip labels with emoji (IP EqualChoiceRow / Shared choice chips).
  String get chipLabel => switch (this) {
        privateBathroom => '🛁 Private Bathroom (Ensuite)',
        sharedBathroom => '🚿 Shared Bathroom',
        noPreference => '◎ No Preference',
      };

  static BathroomPreference? fromSession(Map<String, dynamic>? session) {
    if (session == null) return null;
    final raw = session[sessionKey]?.toString() ?? '';
    return switch (raw) {
      'private_bathroom' || 'private_ensuite' || 'ensuite' => privateBathroom,
      'shared_bathroom' => sharedBathroom,
      'no_preference' => noPreference,
      _ => null,
    };
  }
}
