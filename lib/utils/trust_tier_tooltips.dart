/// Seeker-facing verification tooltip helpers (legacy tier copy removed).
abstract final class TrustTierTooltips {
  static const verifiedUser = 'This profile has completed verification.';

  static String? forBadgeLabel(String badgeLabel) {
    final normalized = badgeLabel.trim().toLowerCase();
    if (normalized.contains('verified user')) return verifiedUser;
    return null;
  }
}
