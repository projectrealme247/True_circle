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
      final roomType = _sharedRoomTitleLabel(input.roomArchitecture);
      return 'Bright $roomType Room in $type | $location';
    }

    final beds = input.bedrooms.clamp(1, 12);
    return 'Bright & Modern $beds-Bed $type | $location';
  }

  static String _buildDescription(ListingSmartCopyInput input) {
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
    final rent = input.monthlyRent > 0 ? input.monthlyRent : 0;

    buffer.writeln('## The Space');
    if (input.isSharedLiving) {
      buffer.writeln(
        'Offering a premium private room in a beautifully maintained '
        '$beds-bed, $baths-bath $type. The home comes completely $furnish '
        'and is optimized for modern living.',
      );
    } else {
      buffer.writeln(
        'A beautiful $furnish $beds-bedroom, $baths-bathroom $type ideally '
        'situated in the heart of $locationLabel. Perfect for professionals or '
        'families seeking a comfortable, modern home of their own.',
      );
    }
    buffer.writeln();

    buffer.writeln('## The Location & Commute');
    buffer.writeln(
      'Getting around is incredibly easy. You are just a convenient '
      '**$busTime walk** from $busStop, and a **$shopTime walk** away from '
      'your nearest $shop for day-to-day essentials, making daily routines '
      'entirely effortless.',
    );

    if (input.isSharedLiving) {
      buffer.writeln();
      buffer.writeln('## House Guidelines & Vibe');
      if (rent > 0) {
        buffer.writeln(
          'This is a welcoming, community-vouched household looking for a '
          'respectful housemate. Rent is €$rent/month, with shared utilities '
          'cleanly managed within the home setup.',
        );
      } else {
        buffer.writeln(
          'This is a welcoming, community-vouched household looking for a '
          'respectful housemate, with shared utilities cleanly managed within '
          'the home setup.',
        );
      }
    }

    return buffer.toString().trimRight();
  }

  static String _sharedRoomTitleLabel(SharedRoomArchitecture? architecture) {
    return switch (architecture) {
      SharedRoomArchitecture.privateEnsuite => 'Ensuite',
      SharedRoomArchitecture.sharedBed => 'Shared',
      SharedRoomArchitecture.privateSharedBath || null => 'Double',
    };
  }

  static String _nonEmpty(String value, {required String fallback}) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
