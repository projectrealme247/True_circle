import '../models/applicant_field_keys.dart';
import 'profile_data.dart';

/// Extracts seeker introduction text from application payload maps.
abstract final class ApplicationPitchText {
  ApplicationPitchText._();

  static const maxPersonalNoteLength = 250;

  static String fromPayload(Object? payload) {
    if (payload is! Map) return '';
    final map = Map<String, dynamic>.from(payload);
    for (final key in const [
      ApplicantFieldKeys.personalIntroduction,
      ApplicantFieldKeys.pitchNarrative,
      ApplicantFieldKeys.bio,
      ApplicantFieldKeys.aboutMe,
    ]) {
      final value = ProfileData.text(map[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String fromApplicationRow(Map<String, dynamic>? row) {
    if (row == null) return '';
    return fromPayload(row['payload']);
  }

  static String displayOrFallback({
    required String pitch,
    required String fallback,
  }) {
    if (pitch.trim().isEmpty) return fallback;
    return '"$pitch"';
  }
}
