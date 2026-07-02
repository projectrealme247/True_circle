import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_env.dart';
import 'config/market/market_config.dart';
import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'services/marketplace_context_notifier.dart';
import 'core/theme/app_theme.dart';
import 'theme/app_scroll_behavior.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(const _AppBootstrap());
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  Widget? _app;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await _initializeApp();
      if (!mounted) return;
      setState(() => _app = const TrueCircleApp());
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'main',
          context: ErrorDescription('while initializing TrueCircle'),
        ),
      );
      if (!mounted) return;
      setState(() => _startupError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_startupError != null) {
      return MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SelectableText(
                    'TrueCircle could not start:\n\n$_startupError',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final app = _app;
    if (app == null) {
      return MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return app;
  }
}

Future<void> _initializeApp() async {
  if (AppEnv.supabaseUrl.isEmpty || AppEnv.supabaseAnonKey.isEmpty) {
    throw StateError(
      'Missing Supabase config.\n\n'
      'After flutter clean, plain "flutter run" will not work — env vars '
      'must be passed at compile time.\n\n'
      'Use:\n'
      '  .\\scripts\\run_dublin.ps1\n\n'
      'Or:\n'
      '  flutter run -d chrome --dart-define-from-file=env.dev.json\n\n'
      'Ensure env.dev.json exists (copy from env.dev.json.example).',
    );
  }

  final supabaseUrl = _normalizeSupabaseUrl(AppEnv.supabaseUrl);
  _validateSupabaseUrl(supabaseUrl);

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: AppEnv.supabaseAnonKey,
  );

  await AuthService.bootstrap();
  await marketplaceContextNotifier.refresh();
  unawaited(AuthService.debugProbeAuthReachable());

  assert(() {
    debugPrint('TrueCircle market: ${MarketConfig.current.id.name}');
    return true;
  }());
}

String _normalizeSupabaseUrl(String raw) {
  var url = raw.trim();
  for (final suffix in ['/rest/v1', '/auth/v1']) {
    if (url.toLowerCase().endsWith(suffix)) {
      url = url.substring(0, url.length - suffix.length);
    }
  }
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}

void _validateSupabaseUrl(String url) {
  if (!url.startsWith('https://') || !url.contains('.supabase.co')) {
    throw StateError(
      'SUPABASE_URL must look like https://YOUR_PROJECT.supabase.co '
      '(Project Settings → API → Project URL). Got: $url',
    );
  }
  final lower = url.toLowerCase();
  if (lower.contains('your_project') ||
      lower.contains('your-project') ||
      lower.contains('your_project_ref')) {
    throw StateError(
      'SUPABASE_URL is still a placeholder. Edit env.dev.json with your real '
      'Project URL (Supabase → Settings → API), then stop and re-run:\n'
      '  flutter run -d chrome --dart-define-from-file=env.dev.json',
    );
  }
  if (url.contains('/auth/') || url.contains('/rest/')) {
    throw StateError(
      'SUPABASE_URL must be the project root only — remove /auth/v1 or /rest/v1.',
    );
  }
}

class TrueCircleApp extends StatelessWidget {
  const TrueCircleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: MarketConfig.current.appTitle,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: appRouter,
      theme: AppTheme.light,
    );
  }
}
