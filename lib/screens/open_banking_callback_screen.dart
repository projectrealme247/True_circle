import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/open_banking_controller.dart';
import '../services/open_banking_provider.dart';

/// Handles PSD2 redirect: /auth/open-banking/callback?code=...&state=...
class OpenBankingCallbackScreen extends StatefulWidget {
  const OpenBankingCallbackScreen({super.key, required this.uri});

  final Uri uri;

  @override
  State<OpenBankingCallbackScreen> createState() =>
      _OpenBankingCallbackScreenState();
}

class _OpenBankingCallbackScreenState extends State<OpenBankingCallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleCallback());
  }

  Future<void> _handleCallback() async {
    final parsed = OpenBankingProvider.parseCallback(widget.uri);
    final error = parsed['error'] ?? '';
    final code = parsed['code'] ?? '';
    final state = parsed['state'] ?? '';

    if (error.isNotEmpty) {
      _finishWithError('Bank connection was cancelled or denied.');
      return;
    }

    if (code.isEmpty || state.isEmpty) {
      _finishWithError('Missing bank authorization response.');
      return;
    }

    try {
      await OpenBankingController.completeCallback(code: code, state: state);
      if (!mounted) return;
      context.go('/verify/open-banking?verified=1');
    } on OpenBankingException catch (e) {
      _finishWithError(e.message);
    } catch (_) {
      _finishWithError('Could not complete bank verification.');
    }
  }

  void _finishWithError(String message) {
    if (!mounted) return;
    context.go(
      '/verify/open-banking?error=${Uri.encodeComponent(message)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFFF5A5F)),
            SizedBox(height: 16),
            Text(
              'Verifying your bank link…',
              style: TextStyle(fontSize: 15, color: Color(0xFF606770)),
            ),
          ],
        ),
      ),
    );
  }
}
