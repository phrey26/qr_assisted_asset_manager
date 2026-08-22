import 'package:flutter/material.dart';

/// Central color + text style tokens so every screen stays visually
/// consistent with the original wireframes (dark UI, soft rounded cards,
/// pill-shaped status badges).
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0E0E13);
  static const Color surface = Color(0xFF1A1A22);
  static const Color surfaceAlt = Color(0xFF17171F);
  static const Color border = Color(0xFF2A2A35);
  static const Color divider = Color(0xFF24242E);

  static const Color textPrimary = Color(0xFFF2F2F5);
  static const Color textSecondary = Color(0xFF9A9AAE);
  static const Color textMuted = Color(0xFF6E6E80);

  static const Color accent = Color(0xFF7C5CFC); // primary purple
  static const Color accentSoft = Color(0xFF241F3D);

  // Status colors (background / foreground pairs)
  static const Color green = Color(0xFF4ADE80);
  static const Color greenBg = Color(0xFF16261D);
  static const Color blue = Color(0xFF60A5FA);
  static const Color blueBg = Color(0xFF162233);
  static const Color orange = Color(0xFFFBBF24);
  static const Color orangeBg = Color(0xFF2E2717);
  static const Color red = Color(0xFFF87171);
  static const Color redBg = Color(0xFF2E1919);

  static const List<Color> avatarPalette = [
    Color(0xFF3FBF8F),
    Color(0xFF7C5CFC),
    Color(0xFFE07856),
  ];
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.background,
        primary: AppColors.accent,
        secondary: AppColors.accent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      dividerColor: AppColors.divider,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}