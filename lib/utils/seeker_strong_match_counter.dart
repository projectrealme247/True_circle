import 'listing_match_engine.dart';

/// Counts seeker-facing strong matches (≥50%) for mode-switch badges.
abstract final class SeekerStrongMatchCounter {
  static const strongMatchThreshold = 50;

  static int count(Iterable<ScoredListing> listings) {
    return listings
        .where((scored) => scored.match.percentage >= strongMatchThreshold)
        .length;
  }
}
