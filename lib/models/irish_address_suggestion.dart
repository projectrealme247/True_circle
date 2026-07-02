/// A verified Irish address option from forward geocoding.
class IrishAddressSuggestion {
  const IrishAddressSuggestion({
    required this.displayLabel,
    required this.area,
    required this.county,
    required this.latitude,
    required this.longitude,
    this.streetLine = '',
    this.eircode,
  });

  final String displayLabel;
  final String streetLine;
  final String area;
  final String county;
  final String? eircode;
  final double latitude;
  final double longitude;

  /// Broad label shown when exact address is hidden publicly.
  String get publicLocationLabel => '$area, $county';
}
