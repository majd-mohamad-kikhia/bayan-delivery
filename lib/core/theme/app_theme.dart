import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  // ── Brand ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF3D5AFE);
  static const Color coral = Color(0xFFFF6B6B);

  // ── Main content ───────────────────────────────────────────────────────
  static const Color background = Color(0xFFF1F5F9);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // ── Sidebar ────────────────────────────────────────────────────────────
  static const Color sidebarBg = Color(0xFF0F172A);
  static const Color sidebarItem = Color(0xFF1E293B);
  static const Color sidebarText = Color(0xFF94A3B8);
  static const Color sidebarTextActive = Colors.white;

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      error: coral,
      onError: Colors.white,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      cardTheme: const CardThemeData(color: surface, elevation: 0, margin: EdgeInsets.zero),
      textTheme: const TextTheme(
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textMuted),
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}
