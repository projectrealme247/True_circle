/// Lifestyle alignment projection for shared-living applicant queues.
class SharedLivingMatchMetrics {
  const SharedLivingMatchMetrics({
    required this.spokenLanguages,
    required this.listingLanguages,
    required this.languageOverlap,
    required this.kitchenCultureAligned,
    required this.seekerFoodPreference,
    required this.listingKitchenCulture,
    required this.lifestyleAlignmentScore,
  });

  final List<String> spokenLanguages;
  final List<String> listingLanguages;
  final List<String> languageOverlap;
  final bool kitchenCultureAligned;
  final String seekerFoodPreference;
  final String? listingKitchenCulture;
  final int lifestyleAlignmentScore;

  Map<String, dynamic> toMap() => {
        'spoken_languages': spokenLanguages,
        'listing_languages': listingLanguages,
        'language_overlap': languageOverlap,
        'kitchen_culture_aligned': kitchenCultureAligned,
        'seeker_food_preference': seekerFoodPreference,
        if (listingKitchenCulture != null)
          'listing_kitchen_culture': listingKitchenCulture,
        'lifestyle_alignment_score': lifestyleAlignmentScore,
      };
}
