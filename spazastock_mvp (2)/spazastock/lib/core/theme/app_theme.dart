// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SpazaColors {
  // Brand
  static const Color primary = Color(0xFF1A6B3C);        // Deep Botswana green
  static const Color primaryLight = Color(0xFF2E8B57);
  static const Color primaryDark = Color(0xFF0D4A28);
  static const Color accent = Color(0xFFFF8C00);         // Orange Money orange
  static const Color accentLight = Color(0xFFFFAA40);

  // Semantic
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57F17);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF0277BD);

  // Neutral
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEFF4F1);
  static const Color onBackground = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);

  // Dark mode
  static const Color darkBackground = Color(0xFF0F1A14);
  static const Color darkSurface = Color(0xFF1A2820);
  static const Color darkSurfaceVariant = Color(0xFF243326);
  static const Color darkOnBackground = Color(0xFFF0F4F1);

  // Status
  static const Color lowStock = Color(0xFFF57F17);
  static const Color outOfStock = Color(0xFFC62828);
  static const Color inStock = Color(0xFF2E7D32);
  static const Color expiring = Color(0xFFE65100);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: SpazaColors.primary,
          brightness: Brightness.light,
          surface: SpazaColors.surface,
          background: SpazaColors.background,
          primary: SpazaColors.primary,
          secondary: SpazaColors.accent,
          error: SpazaColors.error,
        ),
        scaffoldBackgroundColor: SpazaColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: SpazaColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        textTheme: _buildTextTheme(Brightness.light),
        cardTheme: CardTheme(
          color: SpazaColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: SpazaColors.divider, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: SpazaColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: SpazaColors.primary,
            side: const BorderSide(color: SpazaColors.primary, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: SpazaColors.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: SpazaColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: SpazaColors.error, width: 1.5),
          ),
          labelStyle: const TextStyle(color: SpazaColors.textSecondary),
          hintStyle: const TextStyle(color: SpazaColors.textSecondary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: SpazaColors.surface,
          selectedItemColor: SpazaColors.primary,
          unselectedItemColor: SpazaColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        dividerTheme: const DividerThemeData(
          color: SpazaColors.divider,
          thickness: 1,
          space: 0,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: SpazaColors.primary,
          brightness: Brightness.dark,
          surface: SpazaColors.darkSurface,
          background: SpazaColors.darkBackground,
          primary: SpazaColors.primaryLight,
          secondary: SpazaColors.accentLight,
        ),
        scaffoldBackgroundColor: SpazaColors.darkBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: SpazaColors.darkSurface,
          foregroundColor: SpazaColors.darkOnBackground,
          elevation: 0,
        ),
        textTheme: _buildTextTheme(Brightness.dark),
      );

  static TextTheme _buildTextTheme(Brightness brightness) {
    final color = brightness == Brightness.light
        ? SpazaColors.onBackground
        : SpazaColors.darkOnBackground;
    return TextTheme(
      displayLarge: TextStyle(fontFamily: 'Poppins', fontSize: 32, fontWeight: FontWeight.w700, color: color),
      displayMedium: TextStyle(fontFamily: 'Poppins', fontSize: 28, fontWeight: FontWeight.w700, color: color),
      headlineLarge: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w600, color: color),
      headlineMedium: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w600, color: color),
      headlineSmall: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: color),
      titleLarge: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: color),
      titleMedium: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500, color: color),
      bodyLarge: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w400, color: color),
      bodyMedium: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w400, color: color),
      bodySmall: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w400, color: SpazaColors.textSecondary),
      labelLarge: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500, color: color),
    );
  }
}
