import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/listing_media.dart';
import 'auth_service.dart';

/// Uploads listing photos to Supabase Storage and returns public HTTPS URLs.
abstract final class ListingImageStorageService {
  static const bucket = 'listing-images';

  static Future<List<String>> uploadListingImages({
    required String listingId,
    required dynamic images,
  }) async {
    final userId = AuthService.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw ListingImageUploadException('Sign in to publish a listing.');
    }

    final sources = _stringList(images);
    if (sources.isEmpty) return const [];

    final urls = <String>[];
    var storedIndex = 0;

    for (final source in sources.take(ListingMedia.maxImages)) {
      final trimmed = source.trim();
      if (trimmed.isEmpty) continue;

      if (ListingMedia.isHttpUrl(trimmed)) {
        urls.add(trimmed);
        continue;
      }
      if (!ListingMedia.isDataUri(trimmed)) continue;

      final mime = ListingMedia.mimeFromDataUri(trimmed) ?? 'image/jpeg';
      if (mime.toLowerCase() == 'image/heic') {
        debugPrint(
          'ListingImageStorageService skipped HEIC photo for $listingId',
        );
        continue;
      }

      final bytes = ListingMedia.decodeDataUri(trimmed);
      if (bytes == null || bytes.isEmpty) continue;
      if (bytes.length > ListingMedia.maxBytesPerImage) {
        throw ListingImageUploadException(
          'A listing photo is too large (max 10 MB).',
        );
      }

      final ext = ListingMedia.extensionFromMime(mime);
      final path = '$userId/$listingId/$storedIndex.$ext';
      try {
        await AuthService.client.storage.from(bucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: mime,
                upsert: true,
              ),
            );
      } on StorageException catch (e) {
        debugPrint('ListingImageStorageService upload failed: ${e.message}');
        throw ListingImageUploadException(
          'Could not upload listing photos. Try again shortly.',
          cause: e,
        );
      }

      urls.add(
        AuthService.client.storage.from(bucket).getPublicUrl(path),
      );
      storedIndex++;
    }

    return urls;
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item != null) item.toString(),
    ];
  }
}

class ListingImageUploadException implements Exception {
  ListingImageUploadException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
