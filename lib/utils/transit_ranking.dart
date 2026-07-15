/// Shared walk-time-first ranking for transit lines (display + extraction).
abstract final class TransitRanking {
  /// Lower = preferred tie-break when walk time and distance are equal.
  static int typeTieBreakRank(String line) {
    final lower = line.toLowerCase();
    if (lower.contains('dart')) return 0;
    if (lower.contains('rail') && !lower.contains('tram')) return 1;
    if (lower.contains('luas')) return 2;
    if (lower.contains('bus')) return 3;
    return 4;
  }

  /// Returns true when [candidateLine] should replace [currentLine] as primary.
  static bool shouldPreferPrimary({
    required int candidateWalkMin,
    required double candidateDistanceM,
    required String candidateLine,
    required int? currentWalkMin,
    required double? currentDistanceM,
    required String? currentLine,
  }) {
    if (currentLine == null || currentLine.trim().isEmpty) return true;

    final bestWalk = currentWalkMin ?? _walkMinFromMeters(currentDistanceM ?? 0);
    if (candidateWalkMin != bestWalk) {
      return candidateWalkMin < bestWalk;
    }

    final bestDist = currentDistanceM ?? double.infinity;
    if (candidateDistanceM != bestDist) {
      return candidateDistanceM < bestDist;
    }

    return typeTieBreakRank(candidateLine) <
        typeTieBreakRank(currentLine);
  }

  /// Sorts transit rows: walk minutes, distance metres, then type tie-break.
  static int compare({
    required int walkMinA,
    required int walkMinB,
    required double distanceMetersA,
    required double distanceMetersB,
    required String lineA,
    required String lineB,
  }) {
    final byWalk = walkMinA.compareTo(walkMinB);
    if (byWalk != 0) return byWalk;

    final byDistance = distanceMetersA.compareTo(distanceMetersB);
    if (byDistance != 0) return byDistance;

    return typeTieBreakRank(lineA).compareTo(typeTieBreakRank(lineB));
  }

  static int _walkMinFromMeters(double meters) =>
      (meters / 80).ceil().clamp(1, 30);
}
