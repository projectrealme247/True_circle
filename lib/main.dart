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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  if (AppEnv.supabaseUrl.isEmpty || AppEnv.supabaseAnonKey.isEmpty) {
    throw StateError(
      'Missing Supabase config.\n\n'
      'After flutter clean, plain "flutter run" will not work â€” env vars '
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

  runApp(const TrueCircleApp());
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
      '(Project Settings â†’ API â†’ Project URL). Got: $url',
    );
  }
  final lower = url.toLowerCase();
  if (lower.contains('your_project') ||
      lower.contains('your-project') ||
      lower.contains('your_project_ref')) {
    throw StateError(
      'SUPABASE_URL is still a placeholder. Edit env.dev.json with your real '
      'Project URL (Supabase â†’ Settings â†’ API), then stop and re-run:\n'
      '  flutter run -d chrome --dart-define-from-file=env.dev.json',
    );
  }
  if (url.contains('/auth/') || url.contains('/rest/')) {
    throw StateError(
      'SUPABASE_URL must be the project root only â€” remove /auth/v1 or /rest/v1.',
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
