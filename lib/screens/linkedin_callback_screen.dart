import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../services/linkedin_oauth_service.dart';

/// Handles LinkedIn OAuth redirect: /auth/linkedin/callback?code=...&state=...
class LinkedInCallbackScreen extends StatefulWidget {
  const LinkedInCallbackScreen({super.key, required this.uri});

  final Uri uri;

  @override
  State<LinkedInCallbackScreen> createState() => _LinkedInCallbackScreenState();
}

class _LinkedInCallbackScreenState extends State<LinkedInCallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleCallback());
  }

  Future<void> _handleCallback() async {
    final error = widget.uri.queryParameters['error'];
    final code = widget.uri.queryParameters['code'];
    final state = widget.uri.queryParameters['state'];

    if (error != null && error.isNotEmpty) {
      _finishWithError('LinkedIn sign-in was cancelled or denied.');
      return;
    }

    if (code == null || state == null) {
      _finishWithError('Missing LinkedIn authorization response.');
      return;
    }

    try {
      await LinkedInOAuthService.completeAuthorization(code: code, state: state);
      if (!mounted) return;
      context.go('/verify/social?linkedin=connected');
    } on LinkedInOAuthException catch (e) {
      _finishWithError(e.message);
    } catch (e) {
      _finishWithError('Could not complete LinkedIn sign-in.');
    }
  }

  void _finishWithError(String message) {
    if (!mounted) return;
    context.go('/verify/social?linkedin_error=${Uri.encodeComponent(message)}');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: 16),
            Text(
              'Connecting your LinkedIn profile…',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
