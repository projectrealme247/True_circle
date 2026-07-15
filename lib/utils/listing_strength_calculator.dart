import 'listing_data.dart';
import 'listing_property_highlights.dart';

/// Gamified listing completeness score for detail + preview surfaces.
class ListingStrengthSnapshot {
  const ListingStrengthSnapshot({
    required this.scorePercent,
    required this.isDescriptionEdited,
    required this.isPremiumDraft,
  });

  final int scorePercent;
  final bool isDescriptionEdited;
  final bool isPremiumDraft;

  String get statusTitle =>
      isPremiumDraft ? 'Listing Status: Premium Draft 🚀' : 'Listing Status: Live';

  String get statusSubtitle {
    if (!isDescriptionEdited) {
      return 'Using optimized auto-draft copy. Add a personal note about your '
          'ideal flatmate to max out your discoverability!';
    }
    return 'Strong listing — your personal description is helping seekers '
        'connect with your space.';
  }
}

abstract final class ListingStrengthCalculator {
  static ListingStrengthSnapshot fromListing(Map<String, dynamic> item) {
    var score = 0;

    if (ListingData.title(item).trim().length >= 8) score += 15;
    if (ListingData.description(item).trim().length >= 40) score += 20;
    if (ListingData.imageDataUris(item).length >= 3) score += 25;
    if (ListingData.listingPriceAmount(item) != null) score += 15;
    if (ListingData.location(item).trim().isNotEmpty) score += 10;
    if (ListingData.text(item['ber_rating']).isNotEmpty) score += 5;
    if (ListingPropertyHighlights.activeHighlights(item).isNotEmpty) score += 10;

    final isDescriptionEdited = _isDescriptionEdited(item);
    if (isDescriptionEdited) score += 10;

    final normalized = score.clamp(0, 100);
    return ListingStrengthSnapshot(
      scorePercent: normalized,
      isDescriptionEdited: isDescriptionEdited,
      isPremiumDraft: normalized < 100 || !isDescriptionEdited,
    );
  }

  static bool _isDescriptionEdited(Map<String, dynamic> item) {
    if (item['description_is_edited'] == true) return true;
    if (item['description_is_edited'] == false) return false;
    if (item['description_auto_drafted'] == true) return false;
    return ListingData.description(item).trim().isNotEmpty;
  }
}
