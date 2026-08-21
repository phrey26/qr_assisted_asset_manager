import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF242423);

  static const surface = Color(0xFF2E2E2C);

  static const input = Color(0xFF242423);

  static const border = Color(0xFF474745);

  static const primary = Color(0xFF7666FF);

  static const textPrimary = Color(0xFFF2F2F0);

  static const textSecondary = Color(0xFFAAA9A4);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,

      scaffoldBackgroundColor:
          AppColors.background,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),

      useMaterial3: true,

      inputDecorationTheme:
          InputDecorationTheme(
        filled: true,

        fillColor: AppColors.input,

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),

        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: AppColors.border,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: AppColors.border,
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: AppColors.primary,
          ),
        ),
      ),

      elevatedButtonTheme:
          ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              AppColors.surface,
          foregroundColor:
              AppColors.textPrimary,

          side: const BorderSide(
            color: AppColors.border,
          ),

          minimumSize:
              const Size(0, 48),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(9),
          ),
        ),
      ),

      outlinedButtonTheme:
          OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor:
              AppColors.textPrimary,

          side: const BorderSide(
            color: AppColors.border,
          ),

          minimumSize:
              const Size(0, 48),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(9),
          ),
        ),
      ),

      navigationBarTheme:
          NavigationBarThemeData(
        backgroundColor:
            const Color(0xFF20201F),

        indicatorColor:
            AppColors.primary
                .withOpacity(.18),

        labelTextStyle:
            WidgetStateProperty.all(
          const TextStyle(
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}