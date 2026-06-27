import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth_screen.dart';
import '../utils/profile_data.dart';
import 'auth_service.dart';
import 'trust_service.dart';

/// Thrown when corporate document verification fails with a user-facing message.
class CorporateDocumentVerifyException implements Exception {
  CorporateDocumentVerifyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Result of a successful zero-retention corporate verification pass.
class CorporateVerifyResult {
  const CorporateVerifyResult({
    required this.trustTier,
    required this.verificationTrack,
    required this.verifiedAt,
    required this.verificationSeal,
  });

  final String trustTier;
  final String verificationTrack;
  final String verifiedAt;
  final String verificationSeal;
}

/// Option A — streams document bytes to Dublin edge runtime; never persists raw files.
abstract final class CorporateDocumentVerifyService {
  static const _functionName = 'corporate-document-verify';
  static const _useMock = bool.fromEnvironment(
    'CORPORATE_VERIFY_MOCK',
    defaultValue: false,
  );

  static bool get usesMockBackend => _useMock;

  /// Streams [fileBytes] to the isolated serverless runtime, then zeroes the local buffer.
  static Future<CorporateVerifyResult> verifyCorporateDocument({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    if (fileBytes.isEmpty) {
      throw CorporateDocumentVerifyException(
        'The selected file appears empty. Choose another document.',
      );
    }

    final session = AuthScreen.currentUserSession;
    final fullName = ProfileData.text(session?['full_name']);
    if (fullName.isEmpty) {
      throw CorporateDocumentVerifyException(
        'Add your full name in Profile before uploading a corporate document.',
      );
    }

    if (!AuthService.isAuthenticated) {
      throw CorporateDocumentVerifyException(
        'Sign in first, then upload your employment contract or offer letter.',
      );
    }

    try {
      final encoded = base64Encode(fileBytes);
      final response = await AuthService.client.functions.invoke(
        _functionName,
        body: {
          'file_base64': encoded,
          'file_name': fileName,
          'full_name': fullName,
        },
      );

      final data = _responseMap(response);
      if (data['verified'] == true) {
        final result = CorporateVerifyResult(
          trustTier: data['trust_tier']?.toString() ?? 'Grand',
          verificationTrack:
              data['verification_track']?.toString() ?? 'Corporate Track',
          verifiedAt: data['verified_at']?.toString() ??
              DateTime.now().toIso8601String().substring(0, 10),
          verificationSeal: data['corporate_verification_seal']?.toString() ?? '',
        );

        await TrustService.upgradeCorporateDocument(
          verificationSeal: result.verificationSeal,
          verifiedAt: result.verifiedAt,
          verificationTrack: result.verificationTrack,
        );
        authSessionNotifier.refresh();

        return result;
      }

      throw CorporateDocumentVerifyException(
        _errorFromResponse(data, response.status),
      );
    } on CorporateDocumentVerifyException {
      rethrow;
    } on FunctionException catch (e) {
      throw CorporateDocumentVerifyException(_messageFromFunctionException(e));
    } catch (e) {
      debugPrint('TrueCircle corporate verify failed: $e');
      throw CorporateDocumentVerifyException(
        'We could not process this document right now. Try again shortly.',
      );
    } finally {
      _zeroize(fileBytes);
    }
  }

  /// Convenience for `dart:io` [File] on native targets — reads once, verifies, purges.
  static Future<CorporateVerifyResult> verifyCorporateDocumentFile(
    dynamic file, {
    required String fileName,
  }) async {
    final bytes = await _readFileBytes(file);
    return verifyCorporateDocument(fileBytes: bytes, fileName: fileName);
  }

  static Future<Uint8List> _readFileBytes(dynamic file) async {
    if (file is Uint8List) return file;
    // ignore: avoid_dynamic_calls
    final dynamic raw = await file.readAsBytes();
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    throw CorporateDocumentVerifyException('Could not read the selected file.');
  }

  static void _zeroize(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

  static Map<String, dynamic> _responseMap(FunctionResponse response) {
    final raw = response.data;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }

  static String _errorFromResponse(Map<String, dynamic> data, int status) {
    final error = data['error']?.toString().trim();
    if (error != null && error.isNotEmpty) return error;
    if (status == 401) return 'Sign in required.';
    if (status == 422) {
      return 'This document could not be verified. Check the details and try again.';
    }
    if (status == 404) {
      return 'Verification service not deployed. Run: supabase functions deploy corporate-document-verify';
    }
    return 'Verification could not be completed. Try again.';
  }

  static String _messageFromFunctionException(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      final error = details['error']?.toString().trim();
      if (error != null && error.isNotEmpty) return error;
    }
    if (e.status == 401) return 'Sign in required.';
    if (e.status == 404) {
      return 'Verification service not deployed. Run: supabase functions deploy corporate-document-verify';
    }
    return e.reasonPhrase?.isNotEmpty == true
        ? e.reasonPhrase!
        : 'Verification service error (${e.status}).';
  }
}
