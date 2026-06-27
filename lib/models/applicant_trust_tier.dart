import '../utils/profile_data.dart';

/// Irish light-trust badge tokens surfaced to listing hosts.
enum ApplicantTrustTier {
  justLanded('Just Landed'),
  grand('Grand'),
  sound('Sound');

  const ApplicantTrustTier(this.displayToken);

  /// Canonical storage value in `user_trust_profiles.trust_tier`.
  final String displayToken;

  int get sortPriority => switch (this) {
        ApplicantTrustTier.sound => 3,
        ApplicantTrustTier.grand => 2,
        ApplicantTrustTier.justLanded => 1,
      };

  static ApplicantTrustTier fromTrustProfile({
    String? trustTier,
    int? trustStage,
  }) {
    final tierRaw = ProfileData.text(trustTier).toLowerCase();
    if (tierRaw.contains('sound')) return ApplicantTrustTier.sound;
    if (tierRaw.contains('grand')) return ApplicantTrustTier.grand;

    if (trustStage != null) {
      if (trustStage >= 3) return ApplicantTrustTier.sound;
      if (trustStage >= 2) return ApplicantTrustTier.grand;
    }

    return ApplicantTrustTier.justLanded;
  }

  static ApplicantTrustTier fromSession(Map<String, dynamic> session) {
    return fromTrustProfile(
      trustTier: ProfileData.text(session['trust_tier']),
      trustStage: session['trust_stage'] is int
          ? session['trust_stage'] as int
          : int.tryParse(ProfileData.text(session['trust_stage'])),
    );
  }
}
