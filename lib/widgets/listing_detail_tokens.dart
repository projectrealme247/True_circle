import 'package:flutter/material.dart';

/// Design tokens for listing detail — TrueCircle coral + slate neutrals.
abstract final class ListingDetailTokens {
  static const desktopBreakpoint = 960.0;
  static const maxContentWidth = 1180.0;
  static const canvas = Color(0xFFFAFAFA);
  static const surface = Color(0xFFFFFFFF);
  static const charcoal = Color(0xFF222222);
  static const border = Color(0xFFEBEBEB);
  static const muted = Color(0xFF717171);

  static const heroTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.4,
    color: Color(0xFF0F172A),
    height: 1.15,
  );

  static const sectionLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Color(0xFF64748B),
    letterSpacing: 1.2,
    height: 1.25,
  );

  /// Highlight pills, feature matrix cells, transit metadata lines.
  static const highlightMeta = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Color(0xFF1E293B),
    height: 1.35,
  );

  static const price = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: Colors.black87,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static const body = TextStyle(
    fontSize: 15,
    color: Colors.black87,
    height: 1.6,
  );

  static const deposit = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: muted,
    height: 1.35,
  );

  static const locationSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: muted,
    letterSpacing: 0.1,
    height: 1.3,
  );
}
