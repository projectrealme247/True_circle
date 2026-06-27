import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth_screen.dart';
import '../services/auth_service.dart';
import '../services/open_banking_provider.dart';
import '../services/open_banking_redirect.dart';
import '../services/trust_service.dart';
import '../utils/open_banking_liquidity_validator.dart';
import '../utils/profile_data.dart';

class OpenBankingException implements Exception {
  OpenBankingException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OpenBankingVerifyResult {
  const OpenBankingVerifyResult({
    required this.trustTier,
    required this.verificationTrack,
    required this.verifiedAt,
    required this.verificationSeal,
    this.institution,
  });

  final String trustTier;
  final String verificationTrack;
  final String verifiedAt;
  final String verificationSeal;
  final IrishOpenBankInstitution? institution;
}

/// Option B — secure AIS mapping controller (TrueLayer / GoCardless wrapper style).
abstract final class OpenBankingController {
  static const _functionName = 'open-banking-verify';
  static const _stateKey = 'truecircle_open_banking_oauth_state';
  static const _institutionKey = 'truecircle_open_banking_institution';

  static const _mockFromEnv = bool.fromEnvironment(
    'OPEN_BANKING_MOCK',
    defaultValue: false,
  );

  static bool get usesMock =>
      _mockFromEnv || (kDebugMode && OpenBankingProvider.redirectUri.isEmpty);

  static bool get isConfigured =>
      usesMock || OpenBankingProvider.redirectUri.isNotEmpty;

  /// Starts institution-specific OAuth / deep-link redirect (AIB, BOI, Revolut).
  static Future<void> beginInstitutionLink(
    IrishOpenBankInstitution institution,
  ) async {
    if (!AuthService.isAuthenticated) {
      throw OpenBankingException(
        'Sign in first, then connect your Irish bank account.',
      );
    }

    final fullName = ProfileData.text(
      AuthScreen.currentUserSession?['full_name'],
    );
    if (fullName.isEmpty) {
      throw OpenBankingException(
        'Add your full name in Profile before linking your bank.',
      );
    }

    if (usesMock) {
      final state = _randomState();
      await _persistHandshake(state: state, institution: institution);
      final callback = Uri.parse(
        '${_mockCallbackBase()}?code=mock-ais-code&state=$state',
      );
      openOpenBankingConnection(callback.toString());
      return;
    }

    if (OpenBankingProvider.redirectUri.isEmpty) {
      throw OpenBankingException(
        'Open Banking is not configured. Set OPEN_BANKING_REDIRECT_URI in env.dev.json '
        'or OPEN_BANKING_MOCK=true for local testing.',
      );
    }

    try {
      final response = await AuthService.client.functions.invoke(
        _functionName,
        body: {
          'action': 'authorize',
          'institution': institution.providerId,
          'redirect_uri': OpenBankingProvider.redirectUri,
        },
      );

      final data = _responseMap(response);
      final authUrl = data['auth_url']?.toString();
      final state = data['state']?.toString();
      if (authUrl == null || authUrl.isEmpty || state == null || state.isEmpty) {
        throw OpenBankingException(_errorFromResponse(data, response.status));
      }

      await _persistHandshake(state: state, institution: institution);
      openOpenBankingConnection(authUrl);
    } on OpenBankingException {
      rethrow;
    } on FunctionException catch (e) {
      throw OpenBankingException(_messageFromFunctionException(e));
    } catch (e) {
      debugPrint('TrueCircle open banking authorize failed: $e');
      throw OpenBankingException(
        'Could not open your bank connection. Try again shortly.',
      );
    }
  }

  /// Completes handshake — server read-once AIS evaluation, local trust mutation.
  static Future<OpenBankingVerifyResult> completeCallback({
    required String code,
    required String state,
  }) async {
    final expectedState = await _readState();
    final institution = await _readInstitution();
    if (expectedState == null || expectedState != state) {
      throw OpenBankingException(
        'Bank connection session expired. Start again from your profile.',
      );
    }

    final fullName = ProfileData.text(
      AuthScreen.currentUserSession?['full_name'],
    );
    if (fullName.isEmpty) {
      throw OpenBankingException(
        'Add your full name in Profile before completing bank verification.',
      );
    }

    try {
      final OpenBankingVerifyResult result;

      if (usesMock && code == 'mock-ais-code') {
        final snapshot = OpenBankingAisSnapshot(
          accountHolderName: fullName,
          currentBalanceEur: 3500,
          recurringSalaryDetected: true,
          monthlySalaryEur: 3200,
          institution: institution,
        );
        result = evaluateAisSnapshot(
          snapshot: snapshot,
          profileFullName: fullName,
          userBudgetMinEur: _parseBudgetMin(),
        );
      } else {
        final response = await AuthService.client.functions.invoke(
          _functionName,
          body: {
            'action': 'complete',
            'code': code,
            'state': state,
            'full_name': fullName,
            'institution': institution?.providerId,
            'budget_min': _parseBudgetMin(),
          },
        );

        final data = _responseMap(response);
        if (data['verified'] != true) {
          throw OpenBankingException(_errorFromResponse(data, response.status));
        }

        result = OpenBankingVerifyResult(
          trustTier: data['trust_tier']?.toString() ?? 'Grand',
          verificationTrack:
              data['verification_track']?.toString() ?? 'Open Banking Track',
          verifiedAt: data['verified_at']?.toString() ??
              DateTime.now().toIso8601String().substring(0, 10),
          verificationSeal:
              data['open_banking_verification_seal']?.toString() ?? '',
          institution: IrishOpenBankInstitution.fromProviderId(
            data['institution']?.toString() ?? institution?.providerId,
          ),
        );
      }

      await TrustService.upgradeOpenBanking(
        verificationSeal: result.verificationSeal,
        verifiedAt: result.verifiedAt,
        verificationTrack: result.verificationTrack,
        institutionLabel: result.institution?.shortLabel,
      );
      authSessionNotifier.refresh();
      await clearPendingHandshake();

      return result;
    } on OpenBankingException {
      rethrow;
    } on FunctionException catch (e) {
      throw OpenBankingException(_messageFromFunctionException(e));
    } catch (e) {
      debugPrint('TrueCircle open banking complete failed: $e');
      throw OpenBankingException(
        'We could not verify your bank link right now. Try again shortly.',
      );
    } finally {
      await clearPendingHandshake();
    }
  }

  /// Client-side read-once mapping for mock/tests — never persists AIS payload.
  static OpenBankingVerifyResult evaluateAisSnapshot({
    required OpenBankingAisSnapshot snapshot,
    required String profileFullName,
    int? userBudgetMinEur,
  }) {
    if (!ProfileData.identityAnchorMatches(profileFullName, snapshot.accountHolderName)) {
      throw OpenBankingException(
        'The account holder name from your bank does not match your profile full name. '
        'Update your profile or link the account registered in your name.',
      );
    }

    final liquidityOk = OpenBankingLiquidityValidator.meetsPlatformCapability(
      currentBalanceEur: snapshot.currentBalanceEur,
      recurringSalaryDetected: snapshot.recurringSalaryDetected,
      monthlySalaryEur: snapshot.monthlySalaryEur,
      userBudgetMinEur: userBudgetMinEur,
    );

    if (!liquidityOk) {
      throw OpenBankingException(
        OpenBankingLiquidityValidator.failureMessage(
          userBudgetMinEur: userBudgetMinEur,
        ),
      );
    }

    return OpenBankingVerifyResult(
      trustTier: 'Grand',
      verificationTrack: 'Open Banking Track',
      verifiedAt: DateTime.now().toIso8601String().substring(0, 10),
      verificationSeal: 'local-mock-seal',
      institution: snapshot.institution,
    );
  }

  static Future<void> clearPendingHandshake() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey);
    await prefs.remove(_institutionKey);
  }

  static Future<void> _persistHandshake({
    required String state,
    required IrishOpenBankInstitution institution,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, state);
    await prefs.setString(_institutionKey, institution.providerId);
  }

  static Future<String?> _readState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_stateKey);
  }

  static Future<IrishOpenBankInstitution?> _readInstitution() async {
    final prefs = await SharedPreferences.getInstance();
    return IrishOpenBankInstitution.fromProviderId(prefs.getString(_institutionKey));
  }

  static int? _parseBudgetMin() {
    final raw = AuthScreen.currentUserSession?['budget_min'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  static String _mockCallbackBase() {
    final redirect = OpenBankingProvider.redirectUri;
    if (redirect.isNotEmpty) return redirect;
    return 'http://localhost:8080/auth/open-banking/callback';
  }

  static String _randomState() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
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
      return 'Your bank link could not be verified. Check your account and try again.';
    }
    if (status == 404) {
      return 'Open Banking service not deployed. Run: supabase functions deploy open-banking-verify';
    }
    return 'Bank verification could not be completed. Try again.';
  }

  static String _messageFromFunctionException(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      final error = details['error']?.toString().trim();
      if (error != null && error.isNotEmpty) return error;
    }
    if (e.status == 401) return 'Sign in required.';
    if (e.status == 404) {
      return 'Open Banking service not deployed. Run: supabase functions deploy open-banking-verify';
    }
    return e.reasonPhrase?.isNotEmpty == true
        ? e.reasonPhrase!
        : 'Open Banking service error (${e.status}).';
  }
}
