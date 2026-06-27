import 'viewer_profile.dart';

/// Standardized Irish trust-tier explanations (profile + listing cards).
abstract final class TrustTierTooltips {
  static const justLanded =
      'A trust badge for a new user who is casually browsing or recently joined. '
      'It tells the community you are active and starting to build your local circle.';

  static const grand =
      "A trust badge for a verified user. In Ireland, 'Grand' means you're sorted! "
      'It shows your identity, LinkedIn, and basic paperwork have been successfully checked.';

  static const sound =
      "A trust badge for a fully vouched user. In Ireland, 'Sound' means you're incredibly reliable. "
      'It shows you are community-verified and highly safe to live with.';

  static String? forBadgeLabel(String badgeLabel) {
    return switch (badgeLabel) {
      '✈️ Just Landed' || 'Just Landed' => justLanded,
      '👍 Grand' || 'Grand' => grand,
      '🤝 Sound' || 'Sound' => sound,
      _ => null,
    };
  }

  static String? forTrustStage(TrustStage stage) {
    return switch (stage) {
      TrustStage.idVerified => sound,
      TrustStage.socialVerified => grand,
      TrustStage.casual || TrustStage.anonymous => justLanded,
    };
  }
}
