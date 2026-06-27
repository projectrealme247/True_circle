/// Formats verified transit seconds into landlord-facing commute micro-copy.
abstract final class TransitDurationFormatter {
  static String? commuteChipLabel(int? verifiedTransitDurationSeconds) {
    if (verifiedTransitDurationSeconds == null ||
        verifiedTransitDurationSeconds <= 0) {
      return null;
    }

    final minutes = (verifiedTransitDurationSeconds / 60).round().clamp(1, 999);
    return '~$minutes min commute to their destination';
  }
}
