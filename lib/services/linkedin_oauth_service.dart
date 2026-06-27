import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'linkedin_oauth_redirect.dart';

/// LinkedIn OpenID Connect profile returned after OAuth.
class LinkedInProfile {
  const LinkedInProfile({
    required this.sub,
    required this.name,
    this.email = '',
    this.picture = '',
    this.emailVerified = false,
  });

  final String sub;
  final String name;
  final String email;
  final String picture;
  final bool emailVerified;

  Map<String, dynamic> toJson() => {
        'sub': sub,
        'name': name,
        'email': email,
        'picture': picture,
        'email_verified': emailVerified,
      };

  factory LinkedInProfile.fromJson(Map<String, dynamic> json) {
    return LinkedInProfile(
      sub: json['sub']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      picture: json['picture']?.toString() ?? '',
      emailVerified: json['email_verified'] == true,
    );
  }
}

class LinkedInOAuthException implements Exception {
  LinkedInOAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// LinkedIn OAuth via Supabase Edge Function (web redirect flow).
abstract final class LinkedInOAuthService {
  static const _functionName = 'linkedin-oauth';
  static const _stateKey = 'circlekey_linkedin_oauth_state';
  static const _pendingProfileKey = 'circlekey_linkedin_pending_profile';

  static const _clientId = String.fromEnvironment('LINKEDIN_CLIENT_ID');
  static const _redirectUri = String.fromEnvironment('LINKEDIN_REDIRECT_URI');
  static const _mockFromEnv =
      bool.fromEnvironment('LINKEDIN_MOCK', defaultValue: false);

  /// Mock when explicitly enabled, or in debug builds without LinkedIn app keys.
  static bool get usesMock =>
      _mockFromEnv || (kDebugMode && _clientId.isEmpty);

  static bool get isConfigured =>
      usesMock || (_clientId.isNotEmpty && _redirectUri.isNotEmpty);

  /// Starts LinkedIn OAuth (web redirect). Mock mode stores a fake profile instead.
  static Future<void> beginAuthorization() async {
    if (usesMock) {
      await _savePendingProfile(
        const LinkedInProfile(
          sub: 'mock-linkedin-sub',
          name: 'LinkedIn Test User',
          email: 'linkedin.test@example.com',
          emailVerified: true,
        ),
      );
      return;
    }

    if (_clientId.isEmpty || _redirectUri.isEmpty) {
      throw LinkedInOAuthException(
        'LinkedIn is not configured. Add LINKEDIN_CLIENT_ID and '
        'LINKEDIN_REDIRECT_URI to env.dev.json, or set LINKEDIN_MOCK=true.',
      );
    }

    if (!AuthService.isAuthenticated) {
      throw LinkedInOAuthException('Sign in first, then connect LinkedIn.');
    }

    if (!kIsWeb) {
      throw LinkedInOAuthException(
        'LinkedIn OAuth is supported on web builds. Use LINKEDIN_MOCK for other platforms.',
      );
    }

    final state = _randomState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, state);

    final uri = Uri.https('www.linkedin.com', '/oauth/v2/authorization', {
      'response_type': 'code',
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'state': state,
      'scope': 'openid profile email',
    });

    redirectToUrl(uri.toString());
  }

  /// Exchanges OAuth callback [code] for a LinkedIn profile via Edge Function.
  static Future<LinkedInProfile> completeAuthorization({
    required String code,
    required String state,
  }) async {
    if (usesMock) {
      return await loadPendingProfile() ??
          const LinkedInProfile(sub: 'mock', name: 'Mock User');
    }

    final prefs = await SharedPreferences.getInstance();
    final expectedState = prefs.getString(_stateKey);
    if (expectedState == null || expectedState != state) {
      throw LinkedInOAuthException('Invalid OAuth state. Try connecting again.');
    }
    await prefs.remove(_stateKey);

    if (!AuthService.isAuthenticated) {
      throw LinkedInOAuthException('Sign in required.');
    }

    try {
      final response = await AuthService.client.functions.invoke(
        _functionName,
        body: {
          'code': code,
          'redirect_uri': _redirectUri,
        },
      );

      final data = _responseMap(response);
      if (data['ok'] == true && data['profile'] is Map) {
        final profileMap = Map<String, dynamic>.from(data['profile'] as Map);
        final profile = LinkedInProfile.fromJson(profileMap);
        await _savePendingProfile(profile);
        return profile;
      }

      throw LinkedInOAuthException(
        _errorFromResponse(data, response.status),
      );
    } on LinkedInOAuthException {
      rethrow;
    } on FunctionException catch (e) {
      throw LinkedInOAuthException(_messageFromFunctionException(e));
    } catch (e) {
      debugPrint('TrueCircle LinkedIn OAuth failed: $e');
      throw LinkedInOAuthException('Could not connect LinkedIn. Try again.');
    }
  }

  static Future<void> _savePendingProfile(LinkedInProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingProfileKey, jsonEncode(profile.toJson()));
  }

  /// Profile waiting to be confirmed with company/title on social verify screen.
  static Future<LinkedInProfile?> loadPendingProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingProfileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return LinkedInProfile.fromJson(json);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clearPendingProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingProfileKey);
  }

  static String _randomState() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
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
    return 'LinkedIn connection failed.';
  }

  static String _messageFromFunctionException(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      final error = details['error']?.toString().trim();
      if (error != null && error.isNotEmpty) return error;
    }
    if (e.status == 404) {
      return 'LinkedIn service not deployed. Run: supabase functions deploy linkedin-oauth';
    }
    return e.reasonPhrase?.isNotEmpty == true
        ? e.reasonPhrase!
        : 'LinkedIn service error (${e.status}).';
  }
}
