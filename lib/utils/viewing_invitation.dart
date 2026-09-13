/// Viewing invitation details stored on the application row map.
class ViewingInvitation {
  const ViewingInvitation({
    required this.dateLabel,
    required this.timeLabel,
    required this.location,
  });

  static const dateKey = 'viewing_date';
  static const timeKey = 'viewing_time';
  static const locationKey = 'viewing_location';

  final String dateLabel;
  final String timeLabel;
  final String location;

  Map<String, dynamic> toRowFields() => {
        dateKey: dateLabel,
        timeKey: timeLabel,
        locationKey: location,
      };

  static ViewingInvitation? fromRow(Map<String, dynamic>? row) {
    if (row == null) return null;
    final date = row[dateKey]?.toString().trim() ?? '';
    final time = row[timeKey]?.toString().trim() ?? '';
    final location = row[locationKey]?.toString().trim() ?? '';
    if (date.isEmpty || time.isEmpty || location.isEmpty) return null;
    return ViewingInvitation(
      dateLabel: date,
      timeLabel: time,
      location: location,
    );
  }

  static String formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String formatTimeOfDay(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Timeline event when a host sends a viewing invitation.
  static const sentTimelineBody = '📨 Host sent a viewing invitation';

  /// Timeline event when a seeker accepts a viewing invitation.
  static const acceptedTimelineBody = '✅ Viewing invitation accepted';

  /// Timeline event when a host updates invitation details.
  static const updatedTimelineBody = 'Viewing updated.';

  /// Timeline event when a host cancels a viewing.
  static const cancelledTimelineBody = 'Viewing cancelled.';

  static Map<String, dynamic> clearRowFields() => {
        dateKey: '',
        timeKey: '',
        locationKey: '',
      };

  static DateTime? tryParseDateLabel(String label) {
    final parts = label.trim().split(RegExp(r'\s+'));
    if (parts.length != 3) return null;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final day = int.tryParse(parts[0]);
    final monthIndex = months.indexWhere((m) => m == parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || monthIndex < 0 || year == null) return null;
    return DateTime(year, monthIndex + 1, day);
  }

  /// Returns `(hour, minute)` for labels like `18:00`.
  static (int hour, int minute)? tryParseTimeParts(String label) {
    final parts = label.trim().split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour, minute);
  }

  /// Host invitation system/timeline messages (current + legacy detailed body).
  static bool isInvitationMessage(String body) {
    final trimmed = body.trim();
    if (trimmed == sentTimelineBody) return true;
    return trimmed.startsWith('Viewing Invitation') &&
        trimmed.contains('Host invited you to a viewing.');
  }

  /// Seeker acceptance system/timeline messages (current + legacy body).
  static bool isAcceptedMessage(String body) {
    final trimmed = body.trim();
    return trimmed == acceptedTimelineBody ||
        trimmed == "I've accepted the viewing invitation.";
  }

  static bool isViewingTimelineMessage(String body) {
    final trimmed = body.trim();
    return isInvitationMessage(trimmed) ||
        isAcceptedMessage(trimmed) ||
        trimmed == updatedTimelineBody ||
        trimmed == cancelledTimelineBody;
  }

  /// Display text for conversation timeline (hides legacy detailed duplicate).
  static String timelineDisplayBody(String body) {
    if (isInvitationMessage(body)) return sentTimelineBody;
    if (isAcceptedMessage(body)) return acceptedTimelineBody;
    final trimmed = body.trim();
    if (trimmed == updatedTimelineBody || trimmed == cancelledTimelineBody) {
      return trimmed;
    }
    return body;
  }
}
