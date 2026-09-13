import '../config/market/market_config.dart';
import 'listing_data.dart';

/// Property-facing labels for the seeker application workspace.
class SeekerPropertyContext {
  const SeekerPropertyContext({
    this.locationLabel = '',
    this.rentLabel = '',
    this.propertyKindLabel = '',
  });

  final String locationLabel;
  final String rentLabel;
  final String propertyKindLabel;

  factory SeekerPropertyContext.fromListing(Map<String, dynamic>? listing) {
    if (listing == null || listing.isEmpty) {
      return const SeekerPropertyContext();
    }
    return SeekerPropertyContext(
      locationLabel: formatLocation(listing),
      rentLabel: formatRent(listing),
      propertyKindLabel: resolveKindLabel(listing) ?? '',
    );
  }

  static String formatLocation(Map<String, dynamic> listing) {
    final loc = ListingData.location(listing).trim();
    if (loc.isNotEmpty) return loc;
    final area = ListingData.cardAreaName(listing);
    if (area.isNotEmpty) return '$area, Dublin';
    return '';
  }

  static String formatRent(Map<String, dynamic> listing) {
    final label = ListingData.priceDisplayLabel(listing);
    if (label.isEmpty || label == 'Rent not set') return '';

    final raw = ListingData.price(listing);
    final amount = ListingData.listingPriceAmount(listing);
    final symbol = MarketConfig.current.currencySymbol;
    final periodMatch = RegExp(r'/(\w+)$').firstMatch(raw);
    final period = periodMatch != null ? '/${periodMatch.group(1)!}' : '/month';

    if (amount != null) {
      return '$symbol${_formatAmount(amount)}$period';
    }

    final trimmed = raw.trim();
    if (trimmed.startsWith(symbol) || trimmed.startsWith('₹')) return trimmed;
    return '$symbol$trimmed';
  }

  static String? resolveKindLabel(Map<String, dynamic> listing) {
    if (ListingData.isRoomShare(listing)) {
      return '🛏️ Room in Shared Home';
    }
    if (ListingData.isIndependentRental(listing)) {
      return '🏠 Entire Place';
    }
    return null;
  }

  static String _formatAmount(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      if (i > 0 && fromEnd % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
