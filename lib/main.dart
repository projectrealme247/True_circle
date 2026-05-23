import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'router/app_router.dart';
import 'theme/app_scroll_behavior.dart';
import 'theme/app_typography.dart';
import 'theme/home_marketplace_theme.dart';

const _kSupabaseUrl = 'https://wyygechmyrevaidmmyyo.supabase.co';
const _kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind5eWdlY2hteXJldmFpZG1teXlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg5MzMyMjksImV4cCI6MjA5NDUwOTIyOX0.uPocM3WTeR2EDJzJJzWta9ahImsJ3C4FqRK-5PSYKA8';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  await Supabase.initialize(
    url: _kSupabaseUrl,
    anonKey: _kSupabaseAnonKey,
  );

  runApp(const CircleKeyApp());
}

class CircleKeyApp extends StatelessWidget {
  const CircleKeyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light().textTheme;
    final textTheme = AppTypography.interTextTheme(base).apply(
      bodyColor: HomeMarketplaceTheme.textPrimary,
      displayColor: HomeMarketplaceTheme.textPrimary,
    );

    return MaterialApp.router(
      title: 'CircleKey',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: appRouter,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: HomeMarketplaceTheme.canvas,
        primaryColor: HomeMarketplaceTheme.primary,
        fontFamily: GoogleFonts.inter().fontFamily,
        colorScheme: const ColorScheme.light(
          primary: HomeMarketplaceTheme.primary,
          secondary: HomeMarketplaceTheme.primary,
          surface: HomeMarketplaceTheme.surface,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: HomeMarketplaceTheme.surface,
          foregroundColor: HomeMarketplaceTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: AppTypography.appBarBrand(),
        ),
        cardTheme: CardThemeData(
          color: HomeMarketplaceTheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: HomeMarketplaceTheme.border),
          ),
        ),
        textTheme: textTheme,
      ),
    );
  }
}
