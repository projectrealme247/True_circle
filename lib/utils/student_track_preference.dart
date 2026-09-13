/// Landlord preference for which student verification paths are accepted.
enum StudentTrackPreference {
  onCampusOnly,
  preArrivalAllowed,
  allStudents;

  static const StudentTrackPreference defaultValue = StudentTrackPreference.allStudents;

  /// Supabase `student_track_preference` enum value.
  String get dbValue => switch (this) {
        StudentTrackPreference.onCampusOnly => 'track_a',
        StudentTrackPreference.preArrivalAllowed => 'track_b',
        StudentTrackPreference.allStudents => 'both',
      };

  /// User-facing label — never expose "Track A" / "Track B" in UI.
  String get uiLabel => switch (this) {
        StudentTrackPreference.onCampusOnly => 'On-Campus / Enrolled Only',
        StudentTrackPreference.preArrivalAllowed => 'Accept Pre-Arrival Students',
        StudentTrackPreference.allStudents => 'Accept All Students',
      };

  /// Short helper line shown beneath [uiLabel] in landlord forms.
  String get uiDescription => switch (this) {
        StudentTrackPreference.allStudents =>
          'Open to enrolled and pre-arrival students with verified credentials.',
        StudentTrackPreference.onCampusOnly =>
          'Restricts matches to users with verified active university emails.',
        StudentTrackPreference.preArrivalAllowed =>
          'Allows international students relocating to Dublin who do not yet have a university email.',
      };

  /// Preferred display order for landlord preference pickers.
  static const List<StudentTrackPreference> formOptions = [
    StudentTrackPreference.allStudents,
    StudentTrackPreference.onCampusOnly,
    StudentTrackPreference.preArrivalAllowed,
  ];

  static StudentTrackPreference fromDbValue(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    return switch (raw) {
      'track_a' => StudentTrackPreference.onCampusOnly,
      'track_b' => StudentTrackPreference.preArrivalAllowed,
      'both' => StudentTrackPreference.allStudents,
      _ => StudentTrackPreference.defaultValue,
    };
  }

  static StudentTrackPreference fromMap(Map<String, dynamic> map) =>
      fromDbValue(map['tenant_track_preference']);

  Map<String, dynamic> toMap() => {'tenant_track_preference': dbValue};
}
