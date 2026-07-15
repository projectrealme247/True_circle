/// A Dublin-area destination resolved via preset hub, Nominatim, or GPS.
class DublinDestinationSuggestion {
  const DublinDestinationSuggestion({
    required this.displayLabel,
    required this.latitude,
    required this.longitude,
    this.source = 'nominatim',
  });

  final String displayLabel;
  final double latitude;
  final double longitude;
  final String source;
}
