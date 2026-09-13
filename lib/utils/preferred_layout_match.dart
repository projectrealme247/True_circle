import 'listing_data.dart';
import 'profile_data.dart';

/// Entire-place bed requirement derived from seeker `preferred_layout`.
enum PreferredBedRequirement {
  studio,
  oneOrLarger,
  twoOrLarger,
  threeOrLarger,
  fourOrLarger,
  unknown,
}

/// Result of comparing seeker [preferred_layout] to a listing's beds/room type.
class PreferredLayoutMatchResult {
  const PreferredLayoutMatchResult({
    required this.matches,
    required this.seekerLabel,
    required this.listingLabel,
    required this.requirement,
  });

  final bool matches;
  final String seekerLabel;
  final String listingLabel;
  final PreferredBedRequirement requirement;

  String get statusLabel {
    if (seekerLabel.isEmpty) return 'Not specified';
    if (listingLabel.isEmpty) return 'Listing beds unknown';
    return matches ? 'Fits $seekerLabel' : 'Does not fit $seekerLabel';
  }
}

/// Property requirement matching — uses stored `preferred_layout`, never persona.
abstract final class PreferredLayoutMatch {
  PreferredLayoutMatch._();

  static const studioLabels = {'studio'};
  static const shareRoomLayouts = {
    'single / private room',
    'ensuite room',
    'twin / shared room',
    'single room',
    'double room',
  };

  static PreferredBedRequirement requirementFromLayout(String? preferredLayout) {
    final raw = preferredLayout?.trim() ?? '';
    if (raw.isEmpty) return PreferredBedRequirement.unknown;
    final lower = raw.toLowerCase();
    if (studioLabels.any(lower.contains)) return PreferredBedRequirement.studio;
    if (lower.contains('4+') || lower.startsWith('4')) {
      return PreferredBedRequirement.fourOrLarger;
    }
    if (lower.contains('3')) return PreferredBedRequirement.threeOrLarger;
    if (lower.contains('2')) return PreferredBedRequirement.twoOrLarger;
    if (lower.contains('1')) return PreferredBedRequirement.oneOrLarger;
    return PreferredBedRequirement.unknown;
  }

  /// Parsed bed count for entire-place listings. Studio → 0.
  static int? listingBedCount(Map<String, dynamic> listing) {
    final bedrooms = ListingData.bedrooms(listing).toLowerCase();
    final bhk = ListingData.bhk(listing).toLowerCase();
    final title = ListingData.title(listing).toLowerCase();
    if (bedrooms.contains('studio') ||
        bhk.contains('studio') ||
        title.contains('studio')) {
      return 0;
    }
    return ListingData.bedCount(listing);
  }

  static String listingBedLabel(Map<String, dynamic> listing) {
    final count = listingBedCount(listing);
    if (count == null) {
      final raw = ListingData.bedrooms(listing);
      if (raw.isNotEmpty) return raw;
      return ListingData.bhk(listing);
    }
    if (count == 0) return 'Studio';
    if (count >= 4) return '4+ Bed';
    return '$count Bed';
  }

  static bool _matchesBeds(PreferredBedRequirement requirement, int listingBeds) {
    return switch (requirement) {
      PreferredBedRequirement.studio => listingBeds == 0,
      PreferredBedRequirement.oneOrLarger => listingBeds >= 1,
      PreferredBedRequirement.twoOrLarger => listingBeds >= 2,
      PreferredBedRequirement.threeOrLarger => listingBeds >= 3,
      PreferredBedRequirement.fourOrLarger => listingBeds >= 4,
      PreferredBedRequirement.unknown => false,
    };
  }

  static bool _isShareRoomLayout(String preferredLayout) {
    final lower = preferredLayout.trim().toLowerCase();
    return shareRoomLayouts.contains(lower);
  }

  static PreferredLayoutMatchResult evaluate({
    required String? preferredLayout,
    required Map<String, dynamic> listing,
  }) {
    final seekerLabel = ProfileData.text(preferredLayout);
    final listingLabel = listingBedLabel(listing);

    if (seekerLabel.isEmpty) {
      return PreferredLayoutMatchResult(
        matches: false,
        seekerLabel: '',
        listingLabel: listingLabel,
        requirement: PreferredBedRequirement.unknown,
      );
    }

    if (_isShareRoomLayout(seekerLabel)) {
      final roomType = ListingData.roomType(listing).trim().toLowerCase();
      final matches = roomType.isNotEmpty &&
          (roomType.contains(seekerLabel.toLowerCase().split(' ').first) ||
              seekerLabel.toLowerCase().contains(roomType));
      return PreferredLayoutMatchResult(
        matches: matches,
        seekerLabel: seekerLabel,
        listingLabel: roomType.isEmpty ? listingLabel : ListingData.roomType(listing),
        requirement: PreferredBedRequirement.unknown,
      );
    }

    final requirement = requirementFromLayout(seekerLabel);
    final beds = listingBedCount(listing);
    if (beds == null || requirement == PreferredBedRequirement.unknown) {
      return PreferredLayoutMatchResult(
        matches: false,
        seekerLabel: seekerLabel,
        listingLabel: listingLabel,
        requirement: requirement,
      );
    }

    return PreferredLayoutMatchResult(
      matches: _matchesBeds(requirement, beds),
      seekerLabel: seekerLabel,
      listingLabel: listingLabel,
      requirement: requirement,
    );
  }

  static PreferredLayoutMatchResult fromSession({
    required Map<String, dynamic>? seekerSession,
    required Map<String, dynamic> listing,
  }) {
    return evaluate(
      preferredLayout: ProfileData.text(seekerSession?['preferred_layout']),
      listing: listing,
    );
  }
}
