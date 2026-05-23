import 'dart:convert';
import 'dart:typed_data';

/// Base64 data-URI helpers for listing photos/video in localStorage.
abstract final class ListingMedia {
  static const maxImages = 5;
  static const maxBytesPerImage = 1500000;
  static const maxBytesPerVideo = 8000000;

  static String? mimeFromDataUri(String dataUri) {
    final match = RegExp(r'^data:([^;]+);base64,').firstMatch(dataUri.trim());
    return match?.group(1);
  }

  static Uint8List? decodeDataUri(String? dataUri) {
    if (dataUri == null || dataUri.isEmpty) return null;
    final trimmed = dataUri.trim();
    final comma = trimmed.indexOf(',');
    final payload = comma >= 0 ? trimmed.substring(comma + 1) : trimmed;
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  static String encodeBytes(Uint8List bytes, {required String mime}) {
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  static String? guessImageMime(String? extension) {
    final ext = (extension ?? '').toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'image/jpeg',
    };
  }

  static String? guessVideoMime(String? extension) {
    final ext = (extension ?? '').toLowerCase();
    return switch (ext) {
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      'mp4' => 'video/mp4',
      _ => 'video/mp4',
    };
  }
}
