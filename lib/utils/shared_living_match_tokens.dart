import 'listing_data.dart';
import 'profile_data.dart';

/// Canonical Shared Living matching tokens + normalization.
///
/// Does not rewrite stored payloads — matching-layer only.
abstract final class SharedLivingMatchTokens {
  SharedLivingMatchTokens._();

  // Bathroom
  static const privateEnsuite = 'private_ensuite';
  static const sharedBathroom = 'shared_bathroom';
  static const noPreference = 'no_preference';

  // Room
  static const privateRoom = 'private_room';
  static const sharedRoom = 'shared_room';

  // Gender / required occupant
  static const male = 'male';
  static const female = 'female';

  /// Normalize landlord `bathroom_type` or seeker `bathroom_preference`.
  static String normalizeBathroom(String? raw) {
    final token = raw?.trim().toLowerCase() ?? '';
    return switch (token) {
      'private_ensuite' ||
      'private_bathroom' ||
      'ensuite' =>
        privateEnsuite,
      'shared_bathroom' ||
      'shared_bath' ||
      'private_shared_bath' ||
      'private_bath' =>
        sharedBathroom,
      'no_preference' || '' => noPreference,
      _ => noPreference,
    };
  }

  /// Normalize landlord `room_type_matching` or seeker Shared `preferred_layout`.
  ///
  /// Returns empty when [raw] is an Independent Places layout (Studio, 1 Bed, …).
  static String normalizeRoom(String? raw) {
    final token = raw?.trim().toLowerCase() ?? '';
    return switch (token) {
      'private' || 'private_room' => privateRoom,
      'shared' ||
      'shared_room' ||
      'shared_bed' ||
      'bed_shared' =>
        sharedRoom,
      _ => '',
    };
  }

  /// Normalize gender / required-occupant style tokens to canonical values.
  static String normalizeGender(String? raw) {
    final token = raw?.trim().toLowerCase() ?? '';
    if (token.isEmpty) return noPreference;

    // Shared group_composition + required_occupant + short forms.
    if (token == 'male' || token == 'm' || token == 'male_only') {
      return male;
    }
    if (token == 'female' || token == 'f' || token == 'female_only') {
      return female;
    }
    if (token == 'mixed' ||
        token == 'prefer_not' ||
        token == 'no_preference') {
      return noPreference;
    }

    // gender_preference / bachelorPreference display strings.
    if (token == 'boys only' || token.contains('boys only')) {
      return male;
    }
    if (token == 'girls only' || token.contains('girls only')) {
      return female;
    }
    if (token == 'boys and girls' ||
        token.contains('boys & girls') ||
        token.contains('boys and girls')) {
      return noPreference;
    }

    if (token.contains('girl') && !token.contains('boy')) return female;
    if (token.contains('boy') && !token.contains('girl')) return male;

    return noPreference;
  }

  // ── Listing extractors ───────────────────────────────────────────────────

  static Map<String, dynamic>? primarySharedRoom(Map<String, dynamic> listing) {
    final rooms =
        listing['shared_rooms'] ?? listing['metadata']?['shared_rooms'];
    if (rooms is! List || rooms.isEmpty) return null;
    final first = rooms.first;
    if (first is Map) return Map<String, dynamic>.from(first);
    return null;
  }

  static String bathroomFromListing(Map<String, dynamic> listing) {
    final room = primarySharedRoom(listing);
    final raw = ProfileData.text(
      listing['bathroom_type'] ??
          listing['metadata']?['bathroom_type'] ??
          room?['bathroom_type'],
    );
    return normalizeBathroom(raw);
  }

  static String roomFromListing(Map<String, dynamic> listing) {
    final direct = ProfileData.text(
      listing['room_type_matching'] ??
          listing['metadata']?['room_type_matching'],
    );
    final fromDirect = normalizeRoom(direct);
    if (fromDirect.isNotEmpty) return fromDirect;

    final room = primarySharedRoom(listing);
    final fromRoom = normalizeRoom(ProfileData.text(room?['room_type']));
    if (fromRoom.isNotEmpty) return fromRoom;

    final kind = ProfileData.text(
      listing['share_room_kind'] ?? listing['room_type'],
    ).toLowerCase();
    if (kind.contains('shared') || kind.contains('bed')) return sharedRoom;
    if (kind.isNotEmpty) return privateRoom;
    return '';
  }

  static String genderFromListing(Map<String, dynamic> listing) {
    final room = primarySharedRoom(listing);
    final required = ProfileData.text(
      listing['required_occupant'] ??
          listing['metadata']?['required_occupant'] ??
          room?['required_occupant'],
    );
    if (required.isNotEmpty) return normalizeGender(required);

    final bachelor = ListingData.bachelorPreference(listing);
    if (bachelor.isNotEmpty) return normalizeGender(bachelor);

    final legacy = ProfileData.text(listing['target_tenant_preference']);
    if (legacy.isNotEmpty) return normalizeGender(legacy);

    return noPreference;
  }

  // ── Seeker extractors ────────────────────────────────────────────────────

  static String bathroomFromSeeker(Map<String, dynamic>? session) {
    if (session == null) return noPreference;
    return normalizeBathroom(session['bathroom_preference']?.toString());
  }

  /// Shared Living room preference from [preferred_layout] only.
  static String roomFromSeeker(Map<String, dynamic>? session) {
    if (session == null) return '';
    return normalizeRoom(session['preferred_layout']?.toString());
  }

  /// Prefer [groupComposition], then [genderPreference], then raw [gender].
  static String genderFromSeeker({
    String? groupComposition,
    String? genderPreference,
    String? gender,
  }) {
    final fromGroup = ProfileData.text(groupComposition);
    if (fromGroup.isNotEmpty) return normalizeGender(fromGroup);

    final fromPref = ProfileData.text(genderPreference);
    if (fromPref.isNotEmpty) return normalizeGender(fromPref);

    final fromGender = ProfileData.text(gender);
    if (fromGender.isNotEmpty) return normalizeGender(fromGender);

    return noPreference;
  }

  static String genderFromSeekerSession(Map<String, dynamic>? session) {
    if (session == null) return noPreference;
    return genderFromSeeker(
      groupComposition: session['group_composition']?.toString(),
      genderPreference: session['gender_preference']?.toString(),
      gender: session['gender']?.toString(),
    );
  }

  // ── Compatibility ────────────────────────────────────────────────────────

  static bool bathroomCompatible({
    required String listingCanonical,
    required String seekerCanonical,
  }) {
    if (seekerCanonical == noPreference || seekerCanonical.isEmpty) {
      return true;
    }
    if (listingCanonical == noPreference || listingCanonical.isEmpty) {
      return true;
    }
    return listingCanonical == seekerCanonical;
  }

  static bool roomCompatible({
    required String listingCanonical,
    required String seekerCanonical,
  }) {
    if (seekerCanonical.isEmpty) return true;
    if (listingCanonical.isEmpty) return true;
    return listingCanonical == seekerCanonical;
  }

  /// Hard/soft gender gate on canonical tokens.
  ///
  /// `no_preference` on either side is compatible.
  static bool genderCompatible({
    required String listingCanonical,
    required String seekerCanonical,
  }) {
    if (listingCanonical == noPreference || listingCanonical.isEmpty) {
      return true;
    }
    if (seekerCanonical == noPreference || seekerCanonical.isEmpty) {
      return true;
    }
    return listingCanonical == seekerCanonical;
  }

  static bool bathroomCompatibleFor({
    required Map<String, dynamic> listing,
    Map<String, dynamic>? seekerSession,
  }) {
    return bathroomCompatible(
      listingCanonical: bathroomFromListing(listing),
      seekerCanonical: bathroomFromSeeker(seekerSession),
    );
  }

  static bool roomCompatibleFor({
    required Map<String, dynamic> listing,
    Map<String, dynamic>? seekerSession,
  }) {
    return roomCompatible(
      listingCanonical: roomFromListing(listing),
      seekerCanonical: roomFromSeeker(seekerSession),
    );
  }

  static bool genderCompatibleFor({
    required Map<String, dynamic> listing,
    Map<String, dynamic>? seekerSession,
    String? genderPreferenceFallback,
  }) {
    final seeker = seekerSession != null
        ? genderFromSeekerSession(seekerSession)
        : genderFromSeeker(genderPreference: genderPreferenceFallback);
    return genderCompatible(
      listingCanonical: genderFromListing(listing),
      seekerCanonical: seeker,
    );
  }
}
