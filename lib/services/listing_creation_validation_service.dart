import '../models/listing_creation_draft.dart';
import '../models/listing_creation_field_keys.dart';
import 'eircode_geocoding_service.dart';

/// Field-level validation for Phase C listing creation drafts.
abstract final class ListingCreationValidationService {
  static const _minTitleLength = 3;
  static const _minDescriptionLength = 10;

  /// Returns a map of field key → user-facing error. Empty when valid.
  static Map<String, String> validate(ListingCreationDraft draft) {
    final errors = <String, String>{};

    if (draft.title.trim().length < _minTitleLength) {
      errors['title'] = 'Enter a title (at least $_minTitleLength characters).';
    }

    final priceText = draft.price.trim();
    if (priceText.isEmpty) {
      errors['price'] = 'Enter a price (e.g. €2,100/month).';
    } else if (!RegExp(r'^\d').hasMatch(priceText)) {
      errors['price'] = 'Price should start with a number.';
    }

    final description = draft.description.trim();
    if (description.isNotEmpty && description.length < _minDescriptionLength) {
      errors['description'] =
          'If you add a description, use at least $_minDescriptionLength characters.';
    }

    final eircode = draft.eircode.trim();
    if (eircode.isEmpty) {
      errors[ListingCreationFieldKeys.eircode] =
          'Eircode is required for every listing.';
    } else if (!EircodeGeocodingService.isValidFormat(eircode)) {
      errors[ListingCreationFieldKeys.eircode] =
          'Enter a valid Irish Eircode (e.g. D02 X285).';
    }

    if (draft.category.isIndependent) {
      _validateIndependent(draft, errors);
    } else {
      _validateShared(draft, errors);
    }

    if (!draft.listingAuthorizationConfirmed) {
      errors[ListingCreationFieldKeys.listingAuthorizationConfirmed] =
          'Confirm you are authorised to advertise this listing before publishing.';
    }

    return errors;
  }

  static void _validateIndependent(
    ListingCreationDraft draft,
    Map<String, String> errors,
  ) {
    final beds = draft.bedsCount;
    if (beds == null || beds < 1) {
      errors[ListingCreationFieldKeys.bedsCount] =
          'Enter the number of bedrooms (at least 1).';
    }

    if (draft.parkingAvailable == null) {
      errors[ListingCreationFieldKeys.parkingAvailable] =
          'Indicate whether parking is available.';
    }
  }

  static void _validateShared(
    ListingCreationDraft draft,
    Map<String, String> errors,
  ) {
    if (draft.roomType == null) {
      errors[ListingCreationFieldKeys.roomType] =
          'Select Ensuite or Shared room type.';
    }

    if (draft.householdDynamic == null) {
      errors[ListingCreationFieldKeys.householdDynamic] =
          'Describe the household dynamic.';
    }

    if (draft.kitchenCulture == null) {
      errors[ListingCreationFieldKeys.kitchenCulture] =
          'Select the kitchen culture for this home.';
    }

    final langs = draft.languagesSpoken
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (langs.isEmpty) {
      errors[ListingCreationFieldKeys.languagesSpoken] =
          'Add at least one language spoken in the home.';
    }
  }

  /// Blocks remote publish when the local payload is missing required fields.
  static Map<String, String> validateRemotePublishPayload(
    Map<String, dynamic> local,
  ) {
    final errors = <String, String>{};
    final title = (local['title'] ?? '').toString().trim();
    if (title.length < _minTitleLength) {
      errors['title'] = 'Enter a title (at least $_minTitleLength characters).';
    }

    final priceText = (local['price'] ?? '').toString().trim();
    if (priceText.isEmpty) {
      errors['price'] = 'Enter a price (e.g. €2,100/month).';
    } else if (!RegExp(r'^\d').hasMatch(priceText)) {
      errors['price'] = 'Price should start with a number.';
    }

    final location = (local['location'] ?? '').toString().trim();
    if (location.isEmpty) {
      errors['location'] = 'Add a location before publishing.';
    }

    if (local[ListingCreationFieldKeys.listingAuthorizationConfirmed] != true) {
      errors[ListingCreationFieldKeys.listingAuthorizationConfirmed] =
          'Confirm you are authorised to advertise this listing before publishing.';
    }

    return errors;
  }

  /// Strips deprecated kitchen utility keys from arbitrary maps.
  static Map<String, dynamic> stripForbiddenKeys(Map<String, dynamic> raw) {
    return Map<String, dynamic>.from(raw)
      ..removeWhere(
        (key, _) => ListingCreationFieldKeys.forbiddenKeys.contains(key),
      );
  }

  /// Trims, deduplicates (case-insensitive), and title-cases language labels.
  static List<String> sanitizeLanguages(List<String> raw) {
    final seen = <String>{};
    final out = <String>[];

    for (final item in raw) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;

      final key = trimmed.toLowerCase();
      if (seen.contains(key)) continue;

      seen.add(key);
      out.add(_titleCaseLanguage(trimmed));
    }

    return out;
  }

  static String _titleCaseLanguage(String value) {
    if (value.isEmpty) return value;
    if (value.length == 1) return value.toUpperCase();
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }
}
