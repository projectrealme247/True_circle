import '../models/listing_creation_form_models.dart';

/// Inputs collected from listing wizard steps 1–2 for smart copy on step 3.
class ListingSmartCopyInput {
  const ListingSmartCopyInput({
    required this.isSharedLiving,
    required this.areaName,
    required this.postalDistrict,
    required this.propertyType,
    required this.isFurnished,
    required this.bedrooms,
    required this.bathrooms,
    required this.monthlyRent,
    required this.closestTransit,
    required this.transitWalkTime,
    required this.closestShop,
    required this.shopWalkTime,
    this.roomArchitecture,
    this.roomKind,
    this.bathroomType,
    this.householdProfile,
    this.roomProfile,
    this.petsPolicyLabel,
    this.smokingPolicyLabel,
    this.parkingLabels = const [],
    this.languages = const [],
    this.houseRules = const [],
    this.requiredOccupantLabel,
    this.occupantTypeLabel,
    this.currentOccupantLabel,
    this.existingTitle = '',
    this.existingDescription = '',
  });

  final bool isSharedLiving;
  final String areaName;
  final String postalDistrict;
  final String propertyType;
  final bool isFurnished;
  final int bedrooms;
  final int bathrooms;
  final int monthlyRent;
  final String closestTransit;
  final String transitWalkTime;
  final String closestShop;
  final String shopWalkTime;
  final SharedRoomArchitecture? roomArchitecture;
  final SharedRoomKind? roomKind;
  final SharedBathroomType? bathroomType;
  final FlatmateCohort? householdProfile;
  final FlatmateCohort? roomProfile;
  final String? petsPolicyLabel;
  final String? smokingPolicyLabel;
  final List<String> parkingLabels;
  final List<String> languages;
  final List<String> houseRules;
  final String? requiredOccupantLabel;
  final String? occupantTypeLabel;
  final String? currentOccupantLabel;
  final String existingTitle;
  final String existingDescription;
}

class ListingSmartCopyResult {
  const ListingSmartCopyResult({
    this.title,
    this.description,
  });

  final String? title;
  final String? description;
}

/// Track-aware title + structured description templates for listing step 3.
abstract final class ListingSmartCopyGenerator {
  static ListingSmartCopyResult generate(ListingSmartCopyInput input) {
    return ListingSmartCopyResult(
      title: input.existingTitle.trim().isEmpty ? _buildTitle(input) : null,
      description: input.existingDescription.trim().isEmpty
          ? _buildDescription(input)
          : null,
    );
  }

  static String _buildTitle(ListingSmartCopyInput input) {
    final areaName = _nonEmpty(input.areaName, fallback: 'Dublin');
    final postalDistrict =
        _nonEmpty(input.postalDistrict, fallback: 'Dublin');
    final location = '$areaName, $postalDistrict';
    final type = _nonEmpty(input.propertyType, fallback: 'Property');

    if (input.isSharedLiving) {
      final roomType = _sharedRoomTitleLabel(
        input.roomKind,
        input.roomArchitecture,
      );
      return 'Bright $roomType Room in $type | $location';
    }

    final beds = input.bedrooms.clamp(1, 12);
    return 'Bright & Modern $beds-Bed $type | $location';
  }

  static String _buildDescription(ListingSmartCopyInput input) {
    if (input.isSharedLiving) {
      return _buildSharedDescription(input);
    }
    return _buildEntirePlaceDescription(input);
  }

  static String _buildEntirePlaceDescription(ListingSmartCopyInput input) {
    final buffer = StringBuffer();
    final areaName = _nonEmpty(input.areaName, fallback: 'Dublin');
    final postalDistrict =
        _nonEmpty(input.postalDistrict, fallback: 'Dublin');
    final locationLabel = postalDistrict == areaName
        ? areaName
        : '$areaName, $postalDistrict';
    final type = _nonEmpty(input.propertyType, fallback: 'property');
    final furnish = input.isFurnished ? 'furnished' : 'unfurnished';
    final beds = input.bedrooms.clamp(1, 12);
    final baths = input.bathrooms.clamp(1, 12);
    final busStop = _nonEmpty(input.closestTransit, fallback: 'local transit');
    final busTime = _nonEmpty(input.transitWalkTime, fallback: '5 min');
    final shop = _nonEmpty(input.closestShop, fallback: 'local shop');
    final shopTime = _nonEmpty(input.shopWalkTime, fallback: '5 min');

    buffer.writeln('## The Space');
    buffer.writeln(
      'A beautiful $furnish $beds-bedroom, $baths-bathroom $type ideally '
      'situated in the heart of $locationLabel. Perfect for professionals or '
      'families seeking a comfortable, modern home of their own.',
    );
    buffer.writeln();
    buffer.writeln('## The Location & Commute');
    buffer.writeln(
      'Getting around is incredibly easy. You are just a convenient '
      '**$busTime walk** from $busStop, and a **$shopTime walk** away from '
      'your nearest $shop for day-to-day essentials, making daily routines '
      'entirely effortless.',
    );
    return buffer.toString().trimRight();
  }

  static String _buildSharedDescription(ListingSmartCopyInput input) {
    final buffer = StringBuffer();
    final areaName = _nonEmpty(input.areaName, fallback: 'Dublin');
    final postalDistrict =
        _nonEmpty(input.postalDistrict, fallback: 'Dublin');
    final locationLabel = postalDistrict == areaName
        ? areaName
        : '$areaName, $postalDistrict';
    final type = _nonEmpty(input.propertyType, fallback: 'home');
    final roomKind = input.roomKind ??
        (input.roomArchitecture == SharedRoomArchitecture.sharedBed
            ? SharedRoomKind.sharedRoom
            : SharedRoomKind.privateRoom);
    final bathroom = input.bathroomType ??
        (input.roomArchitecture == SharedRoomArchitecture.privateEnsuite
            ? SharedBathroomType.privateEnsuite
            : SharedBathroomType.sharedBathroom);
    final profile = input.roomProfile ?? input.householdProfile;
    final rent = input.monthlyRent > 0 ? input.monthlyRent : 0;
    final busStop = _nonEmpty(input.closestTransit, fallback: 'local transit');
    final busTime = _nonEmpty(input.transitWalkTime, fallback: '5 min');
    final shop = _nonEmpty(input.closestShop, fallback: 'local shop');
    final shopTime = _nonEmpty(input.shopWalkTime, fallback: '5 min');

    buffer.writeln('The Room');
    buffer.writeln(
      'Offering a ${roomKind.label.toLowerCase()} with '
      '${bathroom.label.toLowerCase()} in a shared $type in $locationLabel.',
    );
    if (rent > 0) {
      buffer.writeln('Monthly rent is €$rent.');
    }
    buffer.writeln();

    buffer.writeln('Household');
    if (profile != null) {
      buffer.writeln('Household profile: ${profile.label}.');
    }
    if (input.languages.isNotEmpty) {
      buffer.writeln('Languages spoken: ${input.languages.join(', ')}.');
    }
    if (input.smokingPolicyLabel != null &&
        input.smokingPolicyLabel!.isNotEmpty) {
      buffer.writeln('Smoking: ${input.smokingPolicyLabel}.');
    }
    if (input.petsPolicyLabel != null && input.petsPolicyLabel!.isNotEmpty) {
      buffer.writeln('Pets: ${input.petsPolicyLabel}.');
    }
    if (input.parkingLabels.isNotEmpty) {
      buffer.writeln('Parking: ${input.parkingLabels.join(', ')}.');
    } else {
      buffer.writeln('Parking: not available.');
    }
    buffer.writeln();

    if (roomKind == SharedRoomKind.sharedRoom ||
        input.requiredOccupantLabel != null ||
        input.occupantTypeLabel != null) {
      buffer.writeln('Occupancy');
      if (input.currentOccupantLabel != null) {
        buffer.writeln('Current occupant: ${input.currentOccupantLabel}.');
      }
      if (input.requiredOccupantLabel != null) {
        buffer.writeln('Suitable for: ${input.requiredOccupantLabel}.');
      }
      if (input.occupantTypeLabel != null) {
        buffer.writeln('Occupant type: ${input.occupantTypeLabel}.');
      }
      buffer.writeln();
    }

    if (input.houseRules.isNotEmpty) {
      buffer.writeln('House Rules');
      for (final rule in input.houseRules) {
        buffer.writeln('- $rule');
      }
      buffer.writeln();
    }

    buffer.writeln('Location');
    buffer.writeln(
      'About a $busTime walk from $busStop and a $shopTime walk from $shop.',
    );

    return buffer.toString().trimRight();
  }

  /// Strips common markdown markers for plain-text listing preview.
  static String stripMarkdown(String raw) {
    var text = raw;
    text = text.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
    text = text.replaceAll(RegExp(r'\*(.+?)\*'), r'$1');
    text = text.replaceAll(RegExp(r'`([^`]*)`'), r'$1');
    return text.trim();
  }

  static String _sharedRoomTitleLabel(
    SharedRoomKind? kind,
    SharedRoomArchitecture? architecture,
  ) {
    if (kind == SharedRoomKind.sharedRoom ||
        architecture == SharedRoomArchitecture.sharedBed) {
      return 'Shared';
    }
    if (architecture == SharedRoomArchitecture.privateEnsuite) {
      return 'Ensuite';
    }
    return 'Private';
  }

  static String _nonEmpty(String value, {required String fallback}) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
